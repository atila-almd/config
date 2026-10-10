package lockguard

import (
	"bytes"
	"errors"
	"io"
	"net"
	"reflect"
	"strings"
	"testing"
	"time"
)

func compositorScenario(t *testing.T, announce bool, events []uint16) ([]bool, error) {
	t.Helper()
	client, server := net.Pipe()
	defer client.Close()
	defer server.Close()
	_ = client.SetDeadline(time.Now().Add(time.Second))
	_ = server.SetDeadline(time.Now().Add(time.Second))
	serverDone := make(chan error, 1)
	go func() {
		defer server.Close()
		for _, want := range []struct {
			object  uint32
			opcode  uint16
			payload []byte
		}{
			{1, 1, wireWords(2)}, {1, 0, wireWords(3)},
		} {
			object, opcode, payload, err := readMessage(server)
			if err != nil {
				serverDone <- err
				return
			}
			if object != want.object || opcode != want.opcode || !bytes.Equal(payload, want.payload) {
				serverDone <- errors.New("invalid registry handshake")
				return
			}
		}
		if announce {
			global := append(wireWords(42), wireString(lockInterface)...)
			global = append(global, wireWords(1)...)
			if err := sendMessage(server, 2, 0, global); err != nil {
				serverDone <- err
				return
			}
		}
		if err := sendMessage(server, 3, 0, wireWords(123)); err != nil {
			serverDone <- err
			return
		}
		if !announce {
			serverDone <- nil
			return
		}
		for _, want := range []struct {
			object uint32
			opcode uint16
		}{{2, 0}, {4, 1}, {1, 0}} {
			object, opcode, _, err := readMessage(server)
			if err != nil {
				serverDone <- err
				return
			}
			if object != want.object || opcode != want.opcode {
				serverDone <- errors.New("invalid bind/subscribe handshake")
				return
			}
		}
		// An already-locked compositor emits locked before the subscription sync.
		for i, event := range events {
			if err := sendMessage(server, 5, event, nil); err != nil {
				serverDone <- err
				return
			}
			if i == 0 {
				if err := sendMessage(server, 6, 0, wireWords(456)); err != nil {
					serverDone <- err
					return
				}
			}
		}
		if len(events) == 0 {
			if err := sendMessage(server, 6, 0, wireWords(456)); err != nil {
				serverDone <- err
				return
			}
		}
		serverDone <- nil
	}()
	var states []bool
	err := Observe(client, func(secure bool) error { states = append(states, secure); return nil })
	client.Close()
	if serverErr := <-serverDone; serverErr != nil {
		t.Fatal(serverErr)
	}
	return states, err
}

func TestCompositorNotificationHandshake(t *testing.T) {
	for _, scenario := range []struct {
		name   string
		events []uint16
		want   []bool
	}{
		{"initially-unlocked", nil, []bool{false}},
		{"already-locked", []uint16{0}, []bool{true}},
		{"lock-unlock-relock", []uint16{0, 1, 0}, []bool{true, false, true}},
	} {
		t.Run(scenario.name, func(t *testing.T) {
			states, err := compositorScenario(t, true, scenario.events)
			if !errors.Is(err, io.EOF) || !reflect.DeepEqual(states, scenario.want) {
				t.Fatalf("states=%v err=%v", states, err)
			}
		})
	}
}

func TestMissingProtocolNeverClaimsSecure(t *testing.T) {
	states, err := compositorScenario(t, false, nil)
	if err == nil || !strings.Contains(err.Error(), "unavailable") || len(states) != 0 {
		t.Fatalf("states=%v err=%v", states, err)
	}
}

func TestMalformedWireMessages(t *testing.T) {
	for _, input := range [][]byte{wireWords(1, 4<<16), wireWords(1, 9<<16), append(wireWords(1, 12<<16), 0)} {
		if _, _, _, err := readMessage(bytes.NewReader(input)); err == nil {
			t.Fatal("accepted malformed framing")
		}
	}
	for _, input := range [][]byte{nil, wireWords(42, 0, 1), wireWords(42, 0xffffffff, 1)} {
		if _, _, _, err := parseGlobal(input); err == nil {
			t.Fatal("accepted malformed registry string")
		}
	}
}

func TestInvalidNotificationsCannotInventSecureState(t *testing.T) {
	for _, events := range [][]uint16{{1}, {2}, {0, 0}} {
		var input, output bytes.Buffer
		global := append(wireWords(42), wireString(lockInterface)...)
		global = append(global, wireWords(1)...)
		if err := sendMessage(&input, 2, 0, global); err != nil {
			t.Fatal(err)
		}
		if err := sendMessage(&input, 3, 0, wireWords(1)); err != nil {
			t.Fatal(err)
		}
		for _, event := range events {
			if err := sendMessage(&input, 5, event, nil); err != nil {
				t.Fatal(err)
			}
		}
		secureEvents := 0
		err := Observe(struct {
			io.Reader
			io.Writer
		}{&input, &output}, func(secure bool) error {
			if secure {
				secureEvents++
			}
			return nil
		})
		if err == nil || errors.Is(err, io.EOF) {
			t.Fatalf("accepted invalid notification sequence %v", events)
		}
		want := 0
		if events[0] == 0 {
			want = 1
		}
		if secureEvents != want {
			t.Fatalf("invented secure state: events=%v secure=%d", events, secureEvents)
		}
	}
}
