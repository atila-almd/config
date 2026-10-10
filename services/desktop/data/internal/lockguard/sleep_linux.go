package lockguard

import (
	"context"
	"errors"
	"time"

	"github.com/godbus/dbus/v5"
)

// WatchSleep subscribes before reading the initial snapshot. Response sequence
// numbers prevent queued older signals from overwriting that newer snapshot.
func WatchSleep(system *dbus.Conn, guard *Guard) (<-chan error, error) {
	signals := make(chan *dbus.Signal, 16)
	system.Signal(signals)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := system.AddMatchSignalContext(ctx, dbus.WithMatchSender("org.freedesktop.login1"),
		dbus.WithMatchObjectPath("/org/freedesktop/login1"), dbus.WithMatchInterface("org.freedesktop.login1.Manager"),
		dbus.WithMatchMember("PrepareForSleep")); err != nil {
		system.RemoveSignal(signals)
		return nil, err
	}
	if err := system.AddMatchSignalContext(ctx, dbus.WithMatchSender("org.freedesktop.DBus"),
		dbus.WithMatchInterface("org.freedesktop.DBus"), dbus.WithMatchMember("NameOwnerChanged"),
		dbus.WithMatchArg(0, "org.freedesktop.login1")); err != nil {
		system.RemoveSignal(signals)
		return nil, err
	}
	preparing, sequence, err := SleepSnapshot(system)
	if err != nil {
		system.RemoveSignal(signals)
		return nil, err
	}
	guard.SleepState(preparing)
	done := make(chan error, 1)
	go func() {
		defer system.RemoveSignal(signals)
		for {
			select {
			case <-system.Context().Done():
				done <- errors.New("system bus connection ended")
				return
			case signal, ok := <-signals:
				if !ok {
					done <- errors.New("logind sleep subscription ended")
					return
				}
				if signal.Sequence <= sequence {
					continue
				}
				if signal.Name == "org.freedesktop.DBus.NameOwnerChanged" {
					done <- errors.New("logind restarted; inhibitor must be reacquired")
					return
				}
				if signal.Name != "org.freedesktop.login1.Manager.PrepareForSleep" {
					continue
				}
				if len(signal.Body) != 1 {
					done <- errors.New("invalid logind sleep notification")
					return
				}
				preparing, ok := signal.Body[0].(bool)
				if !ok {
					done <- errors.New("invalid logind sleep notification")
					return
				}
				guard.SleepState(preparing)
			}
		}
	}()
	return done, nil
}
