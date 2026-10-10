package lockguard

import (
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/godbus/dbus/v5"
	"golang.org/x/sys/unix"
)

const serviceName = "workstation-lock-guard.service"
const descriptorName = "sleep-block"

// StoredInhibitor has one process-owned descriptor and one systemd-owned copy.
// FileDescriptorStorePreserve=restart and unlimited automatic restarts keep the
// latter across crashes. Deliberate session shutdown releases the manager copy.
type StoredInhibitor struct {
	System    *dbus.Conn
	Session   *dbus.Conn
	fd        int
	unit      dbus.ObjectPath
	inherited bool
}

func NewStoredInhibitor(system, session *dbus.Conn) (*StoredInhibitor, error) {
	if os.Getenv("NOTIFY_SOCKET") == "" || os.Getenv("FDSTORE") != "1" {
		return nil, errors.New("lock guard requires its systemd notification socket and one-slot descriptor store")
	}
	k := &StoredInhibitor{System: system, Session: session, fd: -1}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	err := session.Object("org.freedesktop.systemd1", "/org/freedesktop/systemd1").CallWithContext(ctx,
		"org.freedesktop.systemd1.Manager.GetUnit", 0, serviceName).Store(&k.unit)
	if err != nil {
		return nil, err
	}
	// systemd delivers the surviving inhibitor on restart, starting at fd 3.
	if os.Getenv("LISTEN_PID") == strconv.Itoa(os.Getpid()) && os.Getenv("LISTEN_FDS") == "1" {
		if os.Getenv("LISTEN_FDNAMES") != descriptorName {
			return nil, errors.New("unexpected stored descriptor")
		}
		k.fd = 3
		k.inherited = true
		unix.CloseOnExec(k.fd)
	}
	return k, nil
}

func (k *StoredInhibitor) Inherited() bool { return k.inherited }

func (k *StoredInhibitor) count() (uint32, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var value dbus.Variant
	err := k.Session.Object("org.freedesktop.systemd1", k.unit).CallWithContext(ctx,
		"org.freedesktop.DBus.Properties.Get", 0, "org.freedesktop.systemd1.Service", "NFileDescriptorStore").Store(&value)
	if err != nil {
		return 0, err
	}
	n, ok := value.Value().(uint32)
	if !ok {
		return 0, errors.New("invalid descriptor store count")
	}
	return n, nil
}

func (k *StoredInhibitor) PreparingForSleep() (bool, error) {
	preparing, _, err := SleepSnapshot(k.System)
	return preparing, err
}

func SleepSnapshot(system *dbus.Conn) (bool, dbus.Sequence, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	var value dbus.Variant
	call := system.Object("org.freedesktop.login1", "/org/freedesktop/login1").CallWithContext(ctx,
		"org.freedesktop.DBus.Properties.Get", 0, "org.freedesktop.login1.Manager", "PreparingForSleep")
	if err := call.Store(&value); err != nil {
		return false, call.ResponseSequence, err
	}
	preparing, ok := value.Value().(bool)
	if !ok {
		return false, call.ResponseSequence, errors.New("invalid logind sleep state")
	}
	return preparing, call.ResponseSequence, nil
}

func (k *StoredInhibitor) Hold() error {
	if k.fd >= 0 {
		count, err := k.count()
		if err != nil {
			return err
		}
		if count == 1 {
			return nil
		}
	} else {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		var fd dbus.UnixFD
		err := k.System.Object("org.freedesktop.login1", "/org/freedesktop/login1").CallWithContext(ctx,
			"org.freedesktop.login1.Manager.Inhibit", 0, "sleep", "workstation-lock-guard",
			"Waiting for a compositor-confirmed secure lock", "block").Store(&fd)
		if err != nil {
			return fmt.Errorf("acquire sleep block: %w", err)
		}
		k.fd = int(fd)
		unix.CloseOnExec(k.fd)
	}
	if err := notify("FDSTORE=1\nFDNAME="+descriptorName, k.fd); err != nil {
		return err
	}
	if err := notifyBarrier(); err != nil {
		return err
	}
	count, err := k.count()
	if err != nil {
		return err
	}
	if count != 1 {
		return errors.New("systemd did not retain the sleep inhibitor")
	}
	return nil
}

func (k *StoredInhibitor) Release() error {
	if k.fd < 0 {
		return nil
	}
	if err := notify("FDSTOREREMOVE=1\nFDNAME=" + descriptorName); err != nil {
		return err
	}
	if err := notifyBarrier(); err != nil {
		return err
	}
	count, err := k.count()
	if err != nil {
		return err
	}
	if count != 0 {
		return errors.New("systemd did not release the retained inhibitor")
	}
	fd := k.fd
	k.fd = -1
	return unix.Close(fd)
}

func notify(message string, fds ...int) error {
	address := os.Getenv("NOTIFY_SOCKET")
	if address == "" || !(strings.HasPrefix(address, "/") || strings.HasPrefix(address, "@")) {
		return errors.New("invalid systemd notification socket")
	}
	conn, err := net.DialUnix("unixgram", nil, &net.UnixAddr{Name: address, Net: "unixgram"})
	if err != nil {
		return err
	}
	defer conn.Close()
	if err := conn.SetWriteDeadline(time.Now().Add(5 * time.Second)); err != nil {
		return err
	}
	var rights []byte
	if len(fds) != 0 {
		rights = unix.UnixRights(fds...)
	}
	// WriteMsgUnix uses sendto semantics for unixgram and rejects a connected
	// socket; sendmsg on its connected descriptor retains the ancillary rights.
	raw, err := conn.SyscallConn()
	if err != nil {
		return err
	}
	var sendErr error
	err = raw.Write(func(fd uintptr) bool {
		_, sendErr = unix.SendmsgN(int(fd), []byte(message), rights, nil, 0)
		return sendErr != unix.EAGAIN && sendErr != unix.EWOULDBLOCK
	})
	if err != nil {
		return err
	}
	return sendErr
}

func notifyBarrier() error {
	fds := make([]int, 2)
	if err := unix.Pipe2(fds, unix.O_CLOEXEC); err != nil {
		return err
	}
	defer unix.Close(fds[0])
	if err := notify("BARRIER=1", fds[1]); err != nil {
		unix.Close(fds[1])
		return err
	}
	unix.Close(fds[1])
	for {
		poll := []unix.PollFd{{Fd: int32(fds[0]), Events: unix.POLLIN}}
		n, err := unix.Poll(poll, 5000)
		if err == unix.EINTR {
			continue
		}
		if err != nil {
			return err
		}
		if n > 0 && poll[0].Revents&unix.POLLHUP != 0 {
			return nil
		}
		return errors.New("systemd notification barrier timed out")
	}
}

func Ready() error { return notify("READY=1") }
