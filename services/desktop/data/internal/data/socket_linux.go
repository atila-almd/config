package data

import (
	"errors"
	"net"
	"os"
	"path/filepath"
	"syscall"

	"golang.org/x/sys/unix"
)

// Listen refuses links/foreign paths and holds an exclusive lock for the socket's
// lifetime. A second process cannot unlink the running service's endpoint.
func Listen(runtimeDir string) (*net.UnixListener, func(), error) {
	if !filepath.IsAbs(runtimeDir) {
		return nil, nil, errors.New("XDG_RUNTIME_DIR must be absolute")
	}
	if err := privateDirectory(runtimeDir, false); err != nil {
		return nil, nil, err
	}
	directory := filepath.Join(runtimeDir, "blendos-workstation")
	if err := privateDirectory(directory, true); err != nil {
		return nil, nil, err
	}
	lockPath := filepath.Join(directory, "data.lock")
	fd, err := unix.Open(lockPath, unix.O_CREAT|unix.O_RDWR|unix.O_CLOEXEC|unix.O_NOFOLLOW, 0600)
	if err != nil {
		return nil, nil, err
	}
	lock := os.NewFile(uintptr(fd), lockPath)
	info, err := lock.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Mode().Perm() != 0600 {
		lock.Close()
		return nil, nil, errors.New("socket lock must be a private regular file")
	}
	if err := unix.Flock(fd, unix.LOCK_EX|unix.LOCK_NB); err != nil {
		lock.Close()
		return nil, nil, errors.New("workstation data service is already running")
	}
	path := filepath.Join(directory, "data.sock")
	if info, err := os.Lstat(path); err == nil {
		if info.Mode()&os.ModeSocket == 0 {
			lock.Close()
			return nil, nil, errors.New("socket path is occupied by a non-socket")
		}
		if err := os.Remove(path); err != nil {
			lock.Close()
			return nil, nil, err
		}
	} else if !os.IsNotExist(err) {
		lock.Close()
		return nil, nil, err
	}
	listener, err := net.ListenUnix("unix", &net.UnixAddr{Name: path, Net: "unix"})
	if err != nil {
		lock.Close()
		return nil, nil, err
	}
	if err := os.Chmod(path, 0600); err != nil {
		listener.Close()
		lock.Close()
		return nil, nil, err
	}
	return listener, func() { listener.Close(); lock.Close() }, nil
}

func privateDirectory(path string, create bool) error {
	if create {
		if err := os.Mkdir(path, 0700); err != nil && !os.IsExist(err) {
			return err
		}
	}
	info, err := os.Lstat(path)
	if err != nil {
		return err
	}
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok || !info.IsDir() || info.Mode().Perm() != 0700 || stat.Uid != uint32(os.Geteuid()) {
		return errors.New("runtime directory must be a private directory owned by this user")
	}
	return nil
}

func sameUser(conn net.Conn) error {
	unixConn, ok := conn.(*net.UnixConn)
	if !ok {
		return errors.New("Unix connection required")
	}
	raw, err := unixConn.SyscallConn()
	if err != nil {
		return err
	}
	var credentials *unix.Ucred
	var credErr error
	if err := raw.Control(func(fd uintptr) {
		credentials, credErr = unix.GetsockoptUcred(int(fd), unix.SOL_SOCKET, unix.SO_PEERCRED)
	}); err != nil {
		return err
	}
	if credErr != nil {
		return credErr
	}
	if credentials.Uid != uint32(os.Geteuid()) {
		return errors.New("foreign peer")
	}
	return nil
}
