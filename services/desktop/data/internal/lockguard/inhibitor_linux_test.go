package lockguard

import (
	"net"
	"path/filepath"
	"testing"
	"time"

	"golang.org/x/sys/unix"
)

func TestSystemdBarrierWaitsForPassedDescriptorClosure(t *testing.T) {
	path := filepath.Join(t.TempDir(), "notify.sock")
	server, err := net.ListenUnixgram("unixgram", &net.UnixAddr{Name: path, Net: "unixgram"})
	if err != nil {
		t.Fatal(err)
	}
	defer server.Close()
	t.Setenv("NOTIFY_SOCKET", path)
	result := make(chan error, 1)
	go func() { result <- notifyBarrier() }()
	buf, oob := make([]byte, 256), make([]byte, 256)
	if err := server.SetReadDeadline(time.Now().Add(time.Second)); err != nil {
		t.Fatal(err)
	}
	n, oobn, _, _, err := server.ReadMsgUnix(buf, oob)
	if err != nil {
		select {
		case notifyErr := <-result:
			t.Fatalf("receive=%v notify=%v", err, notifyErr)
		default:
		}
		t.Fatal(err)
	}
	if string(buf[:n]) != "BARRIER=1" {
		t.Fatalf("wrong notification: %q", buf[:n])
	}
	control, err := unix.ParseSocketControlMessage(oob[:oobn])
	if err != nil || len(control) != 1 {
		t.Fatalf("missing descriptor: %v", err)
	}
	fds, err := unix.ParseUnixRights(&control[0])
	if err != nil || len(fds) != 1 {
		t.Fatalf("wrong descriptor count: %v", err)
	}
	defer func() {
		if fds[0] >= 0 {
			unix.Close(fds[0])
		}
	}()
	select {
	case err := <-result:
		t.Fatalf("returned before manager acknowledgment: %v", err)
	case <-time.After(5 * time.Millisecond):
	}
	if err := unix.Close(fds[0]); err != nil {
		t.Fatal(err)
	}
	fds[0] = -1
	if err := <-result; err != nil {
		t.Fatal(err)
	}
}

func TestNotifyRequiresManagerSocket(t *testing.T) {
	for _, value := range []string{"", "relative.sock"} {
		t.Setenv("NOTIFY_SOCKET", value)
		if err := notify("READY=1"); err == nil {
			t.Fatal("accepted missing or relative manager socket")
		}
	}
}
