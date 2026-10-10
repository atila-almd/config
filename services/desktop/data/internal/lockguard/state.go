// Package lockguard coordinates sleep with compositor-confirmed session locks.
package lockguard

import (
	"context"
	"errors"
	"sync"
)

// Inhibitor keeps a logind block descriptor, including its systemd-owned copy.
// Hold returns only after that copy has been acknowledged by the service manager.
type Inhibitor interface {
	Hold() error
	Release() error
	PreparingForSleep() (bool, error)
	Inherited() bool
}

type Guard struct {
	mu              sync.Mutex
	inhibitor       Inhibitor
	secure          bool
	preparingUnlock bool
	sleepPending    bool
	sleepObserved   bool
	changed         chan struct{}
}

func New(inhibitor Inhibitor) (*Guard, error) {
	if err := inhibitor.Hold(); err != nil {
		return nil, err
	}
	// An inherited block may have been acknowledged to a PAM frontend just
	// before the old guard crashed. Keep it through the initial locked event;
	// the frontend may still unlock using that acknowledgment.
	return &Guard{inhibitor: inhibitor, preparingUnlock: inhibitor.Inherited(), changed: make(chan struct{})}, nil
}

func (g *Guard) signal() { close(g.changed); g.changed = make(chan struct{}) }

// CompositorState is called only by the independent native Wayland subscriber.
// A lost connection is represented as false, never by a cached locked value.
func (g *Guard) CompositorState(secure bool) error {
	g.mu.Lock()
	defer g.mu.Unlock()
	if secure {
		if !g.preparingUnlock {
			if err := g.inhibitor.Release(); err != nil {
				return err
			}
		}
		g.secure = true
	} else {
		g.secure = false
		g.preparingUnlock = false
		if err := g.inhibitor.Hold(); err != nil {
			g.signal()
			return err
		}
	}
	g.signal()
	return nil
}

// PrepareUnlock is deliberately not an authentication or unlock endpoint.
// The PAM frontend calls it after authentication and must keep the lock if it fails.
func (g *Guard) PrepareUnlock() error {
	g.mu.Lock()
	defer g.mu.Unlock()
	if !g.secure {
		return errors.New("compositor lock has not been confirmed")
	}
	if err := g.inhibitor.Hold(); err != nil {
		return err
	}
	g.preparingUnlock = true
	g.signal()
	// A block acquired after logind accepted sleep does not cancel that sleep.
	// Query after holding the block: new ordinary requests are now inhibited,
	// and an earlier external request is visible even if its signal is queued.
	sleeping, err := g.inhibitor.PreparingForSleep()
	if err != nil {
		return err
	}
	if sleeping || g.sleepPending {
		return errors.New("sleep is pending; unlock is deferred until resume")
	}
	return nil
}

// SleepState comes from logind, including an initial authoritative snapshot.
// Suspend replies acknowledge scheduling, not that the sleep/resume is over.
func (g *Guard) SleepState(preparing bool) {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.sleepPending = preparing
	g.sleepObserved = preparing
	g.signal()
}

// Suspend waits for secure state and serializes the logind request against an
// authenticated unlock. A timeout leaves the lock and inhibitor state intact.
func (g *Guard) Suspend(ctx context.Context, request func(context.Context) error) error {
	for {
		g.mu.Lock()
		if g.sleepPending {
			g.mu.Unlock()
			return errors.New("sleep is already pending")
		}
		if g.secure && !g.preparingUnlock {
			if err := ctx.Err(); err != nil {
				g.mu.Unlock()
				return err
			}
			g.sleepPending = true
			g.sleepObserved = false
			g.signal()
			g.mu.Unlock()
			err := request(ctx)
			g.mu.Lock()
			// A definite rejection allows retry. A timeout has an unknown result
			// and stays latched until logind reports the sleep cycle ended.
			if err != nil && ctx.Err() == nil && !g.sleepObserved {
				g.sleepPending = false
				g.signal()
			}
			g.mu.Unlock()
			return err
		}
		changed := g.changed
		g.mu.Unlock()
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-changed:
		}
	}
}
