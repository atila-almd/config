package lockguard

import (
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
)

const lockInterface = "hyprland_lock_notifier_v1"

// Wayland uses the native byte order. This small client subscribes only to the
// lock notification protocol; it never creates a surface or requests a lock.
func wireWords(values ...uint32) []byte {
	b := make([]byte, 4*len(values))
	for i, v := range values {
		binary.NativeEndian.PutUint32(b[i*4:], v)
	}
	return b
}

func wireString(value string) []byte {
	b := make([]byte, 4+(len(value)+1+3)&^3)
	binary.NativeEndian.PutUint32(b, uint32(len(value)+1))
	copy(b[4:], value)
	return b
}

func sendMessage(w io.Writer, object uint32, opcode uint16, payload []byte) error {
	message := append(wireWords(object, uint32(len(payload)+8)<<16|uint32(opcode)), payload...)
	for len(message) > 0 {
		n, err := w.Write(message)
		if err != nil {
			return err
		}
		if n == 0 {
			return io.ErrShortWrite
		}
		message = message[n:]
	}
	return nil
}

func readMessage(r io.Reader) (uint32, uint16, []byte, error) {
	header := make([]byte, 8)
	if _, err := io.ReadFull(r, header); err != nil {
		return 0, 0, nil, err
	}
	word := binary.NativeEndian.Uint32(header[4:])
	size := int(word >> 16)
	if size < 8 || size%4 != 0 {
		return 0, 0, nil, errors.New("invalid Wayland message length")
	}
	payload := make([]byte, size-8)
	_, err := io.ReadFull(r, payload)
	return binary.NativeEndian.Uint32(header), uint16(word), payload, err
}

func parseGlobal(payload []byte) (uint32, string, uint32, error) {
	if len(payload) < 12 {
		return 0, "", 0, errors.New("short Wayland global")
	}
	n := int(binary.NativeEndian.Uint32(payload[4:]))
	end := 8 + (n+3)&^3
	if n < 1 || end+4 != len(payload) || payload[8+n-1] != 0 {
		return 0, "", 0, errors.New("invalid Wayland interface string")
	}
	return binary.NativeEndian.Uint32(payload), string(payload[8 : 8+n-1]), binary.NativeEndian.Uint32(payload[end:]), nil
}

// Observe establishes a roundtrip after subscribing. Only a compositor locked
// event permits true; an initially unlocked compositor sends no initial event.
func Observe(conn io.ReadWriter, state func(bool) error) error {
	if err := sendMessage(conn, 1, 1, wireWords(2)); err != nil {
		return err
	} // get_registry
	if err := sendMessage(conn, 1, 0, wireWords(3)); err != nil {
		return err
	} // sync
	var global uint32
	bound, locked := false, false
	for {
		object, opcode, payload, err := readMessage(conn)
		if err != nil {
			return err
		}
		switch object {
		case 1:
			if opcode == 0 {
				return errors.New("compositor reported a Wayland protocol error")
			}
		case 2:
			if opcode == 0 {
				name, iface, version, err := parseGlobal(payload)
				if err != nil {
					return err
				}
				if iface == lockInterface && version >= 1 {
					global = name
				}
			} else if opcode == 1 && len(payload) == 4 && binary.NativeEndian.Uint32(payload) == global && bound {
				return errors.New("compositor removed the lock notifier")
			}
		case 3:
			if global == 0 {
				return errors.New("Hyprland lock notification protocol is unavailable")
			}
			payload := append(wireWords(global), wireString(lockInterface)...)
			payload = append(payload, wireWords(1, 4)...)
			if err := sendMessage(conn, 2, 0, payload); err != nil {
				return err
			} // registry.bind
			if err := sendMessage(conn, 4, 1, wireWords(5)); err != nil {
				return err
			} // get_lock_notification
			if err := sendMessage(conn, 1, 0, wireWords(6)); err != nil {
				return err
			}
			bound = true
		case 5:
			if !bound || len(payload) != 0 || opcode > 1 {
				return errors.New("invalid lock notification")
			}
			next := opcode == 0
			if next == locked {
				return errors.New("repeated or out-of-order lock notification")
			}
			locked = next
			if err := state(locked); err != nil {
				return err
			}
		case 6:
			if !locked {
				if err := state(false); err != nil {
					return err
				}
			}
		}
	}
}

func ConnectWayland() (*net.UnixConn, error) {
	display := os.Getenv("WAYLAND_DISPLAY")
	if display == "" {
		return nil, errors.New("WAYLAND_DISPLAY is unset")
	}
	if !filepath.IsAbs(display) {
		runtime := os.Getenv("XDG_RUNTIME_DIR")
		if runtime == "" {
			return nil, errors.New("XDG_RUNTIME_DIR is unset")
		}
		display = filepath.Join(runtime, display)
	}
	conn, err := net.DialUnix("unix", nil, &net.UnixAddr{Name: display, Net: "unix"})
	if err != nil {
		return nil, fmt.Errorf("connect compositor: %w", err)
	}
	return conn, nil
}
