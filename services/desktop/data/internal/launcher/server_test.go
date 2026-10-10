package launcher

import (
	"bufio"
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"path/filepath"
	"testing"
)

func TestNormalizeProvidersRejectsUnknownAndDeduplicates(t *testing.T) {
	providers, err := normalizeProviders([]string{"desktopapplications", "files", "desktopapplications"})
	if err != nil {
		t.Fatalf("normalize providers: %v", err)
	}
	if got, want := len(providers), 2; got != want {
		t.Fatalf("provider count = %d, want %d", got, want)
	}
	if _, err := normalizeProviders([]string{"shell"}); err == nil {
		t.Fatal("unknown provider was accepted")
	}
}

func TestElephantFrameRoundTrip(t *testing.T) {
	var buffer bytes.Buffer
	payload := []byte(`{"query":"a;b"}`)
	buffer.WriteByte(0)
	var length [4]byte
	binary.BigEndian.PutUint32(length[:], uint32(len(payload)))
	buffer.Write(length[:])
	buffer.Write(payload)
	reader := bufio.NewReader(&buffer)
	kind, got, err := readFrame(reader)
	if err != nil {
		t.Fatalf("read frame: %v", err)
	}
	if kind != 0 || string(got) != string(payload) {
		t.Fatalf("frame = (%d, %q)", kind, got)
	}
}

func TestConvertItemUsesProviderQualifiedReference(t *testing.T) {
	c := &client{refs: make(map[string]entryRef)}
	item := c.convertItem(elephantItem{
		Identifier: "example.desktop",
		Text:       "Example",
		Provider:   "desktopapplications",
	})
	if item.ID != "example.desktop" || item.Kind != "desktopapplications" || !item.Available {
		t.Fatalf("unexpected item: %+v", item)
	}
	if _, ok := c.refs["desktopapplications\x00example.desktop"]; !ok {
		t.Fatal("provider-qualified activation reference was not retained")
	}
}

func TestDesktopIdentifierRejectsExecutableText(t *testing.T) {
	valid := []string{"org.example.App.desktop", "org.example.App.desktop:NewInstance"}
	for _, value := range valid {
		if !desktopID.MatchString(value) {
			t.Fatalf("valid desktop ID rejected: %q", value)
		}
	}
	for _, value := range []string{"sh -c evil", "../../bad.desktop", "App.desktop:bad action", ""} {
		if desktopID.MatchString(value) {
			t.Fatalf("unsafe desktop ID accepted: %q", value)
		}
	}
}

func TestQueryTranslatesElephantJSONFrames(t *testing.T) {
	socketPath := filepath.Join(t.TempDir(), "elephant.sock")
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		t.Skipf("unix sockets unavailable: %v", err)
	}
	defer listener.Close()
	serverDone := make(chan error, 1)
	go func() {
		conn, acceptErr := listener.Accept()
		if acceptErr != nil {
			serverDone <- acceptErr
			return
		}
		defer conn.Close()
		var requestHeader [6]byte
		if _, err := io.ReadFull(conn, requestHeader[:]); err != nil {
			serverDone <- err
			return
		}
		length := binary.BigEndian.Uint32(requestHeader[2:])
		request := make([]byte, length)
		if _, err := io.ReadFull(conn, request); err != nil {
			serverDone <- err
			return
		}
		if requestHeader[0] != 0 || requestHeader[1] != 1 || !bytes.Contains(request, []byte(`"desktopapplications"`)) {
			serverDone <- errors.New("unexpected Elephant query frame")
			return
		}
		item := []byte(`{"item":{"identifier":"org.example.App.desktop","text":"Example","subtext":"Utility","icon":"example","provider":"desktopapplications","actions":["start"]}}`)
		if err := writeResponseFrame(conn, 0, item); err != nil {
			serverDone <- err
			return
		}
		serverDone <- writeResponseFrame(conn, 255, nil)
	}()

	c := &client{server: Server{ElephantSocket: socketPath}, refs: make(map[string]entryRef)}
	items, err := c.query(context.Background(), []string{"desktopapplications"}, "example", 10, false)
	if err != nil {
		t.Fatalf("query: %v", err)
	}
	if len(items) != 1 || items[0].ID != "org.example.App.desktop" || items[0].Label != "Example" {
		t.Fatalf("unexpected translated rows: %+v", items)
	}
	if err := <-serverDone; err != nil {
		t.Fatalf("fake Elephant server: %v", err)
	}
}

func writeResponseFrame(w io.Writer, kind byte, payload []byte) error {
	var header [5]byte
	header[0] = kind
	binary.BigEndian.PutUint32(header[1:], uint32(len(payload)))
	if _, err := w.Write(header[:]); err != nil {
		return err
	}
	_, err := w.Write(payload)
	return err
}
