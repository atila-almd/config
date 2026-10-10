package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/godbus/dbus/v5"
	"workstation.local/data/internal/lockguard"
)

const busName = "org.blendos.WorkstationLockGuard"
const objectPath dbus.ObjectPath = "/org/blendos/WorkstationLockGuard"

type endpoint struct {
	guard   *lockguard.Guard
	system  *dbus.Conn
	session *dbus.Conn
}

func (e *endpoint) PrepareUnlock() *dbus.Error {
	if err := e.guard.PrepareUnlock(); err != nil {
		return dbus.MakeFailedError(err)
	}
	return nil
}

func (e *endpoint) Suspend() *dbus.Error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	var job dbus.ObjectPath
	if err := e.session.Object("org.freedesktop.systemd1", "/org/freedesktop/systemd1").CallWithContext(ctx,
		"org.freedesktop.systemd1.Manager.StartUnit", 0, "workstation-lock.service", "replace").Store(&job); err != nil {
		return dbus.MakeFailedError(err)
	}
	err := e.guard.Suspend(ctx, func(ctx context.Context) error {
		return e.system.Object("org.freedesktop.login1", "/org/freedesktop/login1").CallWithContext(ctx,
			"org.freedesktop.login1.Manager.Suspend", 0, false).Err
	})
	if err != nil {
		return dbus.MakeFailedError(err)
	}
	return nil
}

func run() error {
	if len(os.Args) != 2 {
		return errors.New("usage: workstation-lock-guard {serve|prepare-unlock|suspend}")
	}
	session, err := dbus.ConnectSessionBus()
	if err != nil {
		return err
	}
	defer session.Close()
	if os.Args[1] != "serve" {
		method := map[string]string{"prepare-unlock": "PrepareUnlock", "suspend": "Suspend"}[os.Args[1]]
		if method == "" {
			return errors.New("unknown lock guard command")
		}
		ctx, cancel := context.WithTimeout(context.Background(), 35*time.Second)
		defer cancel()
		return session.Object(busName, objectPath).CallWithContext(ctx, busName+"."+method, 0).Err
	}
	system, err := dbus.ConnectSystemBus()
	if err != nil {
		return err
	}
	defer system.Close()
	keeper, err := lockguard.NewStoredInhibitor(system, session)
	if err != nil {
		return err
	}
	guard, err := lockguard.New(keeper)
	if err != nil {
		return err
	}
	sleepErrors, err := lockguard.WatchSleep(system, guard)
	if err != nil {
		return err
	}
	// Never close the inhibitor on process shutdown: the manager's copy is
	// intentionally retained across crashes and permanent startup failures.
	compositor, err := lockguard.ConnectWayland()
	if err != nil {
		return err
	}
	defer compositor.Close()
	if err := session.Export(&endpoint{guard: guard, system: system, session: session}, objectPath, busName); err != nil {
		return err
	}
	reply, err := session.RequestName(busName, dbus.NameFlagDoNotQueue)
	if err != nil {
		return err
	}
	if reply != dbus.RequestNameReplyPrimaryOwner {
		return errors.New("another lock guard owns the session endpoint")
	}
	compositorErrors := make(chan error, 1)
	go func() {
		ready := false
		compositorErrors <- lockguard.Observe(compositor, func(secure bool) error {
			if err := guard.CompositorState(secure); err != nil {
				return err
			}
			if !ready {
				if err := lockguard.Ready(); err != nil {
					return err
				}
				ready = true
			}
			return nil
		})
	}()
	select {
	case err = <-compositorErrors:
	case err = <-sleepErrors:
		compositor.Close()
		<-compositorErrors
	case <-session.Context().Done():
		err = errors.New("session bus connection ended")
		compositor.Close()
		<-compositorErrors
	}
	// A stale secure bit must never survive compositor EOF or a protocol error.
	if holdErr := guard.CompositorState(false); holdErr != nil {
		return fmt.Errorf("compositor connection ended (%v); retaining block failed: %w", err, holdErr)
	}
	return err
}

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}
