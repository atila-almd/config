package lockguard

import (
	"context"
	"errors"
	"reflect"
	"testing"
	"time"
)

type fakeInhibitor struct {
	held           bool
	failHold       bool
	failRelease    bool
	sleeping       bool
	failSleepQuery bool
	inherited      bool
	events         []string
}

func (f *fakeInhibitor) Inherited() bool { return f.inherited }

func TestRestartKeepsAcknowledgedUnlockBlockThroughInitialLockedEvent(t *testing.T) {
	f := &fakeInhibitor{inherited: true, held: true}
	g, err := New(f)
	if err != nil {
		t.Fatal(err)
	}
	if err := g.CompositorState(true); err != nil {
		t.Fatal(err)
	}
	if !f.held {
		t.Fatal("restart released an inhibitor already acknowledged to a surviving frontend")
	}
	if err := g.PrepareUnlock(); err != nil {
		t.Fatal(err)
	}
	if err := g.CompositorState(false); err != nil {
		t.Fatal(err)
	}
	if !f.held {
		t.Fatal("actual unlock lost block")
	}
	if err := g.CompositorState(true); err != nil {
		t.Fatal(err)
	}
	if f.held {
		t.Fatal("fresh lock did not restore normal release behavior")
	}
}

func (f *fakeInhibitor) PreparingForSleep() (bool, error) {
	if !f.held {
		return false, errors.New("queried before holding block")
	}
	if f.failSleepQuery {
		return false, errors.New("logind unavailable")
	}
	return f.sleeping, nil
}

func (f *fakeInhibitor) Hold() error {
	if f.failHold {
		return errors.New("store acknowledgment failed")
	}
	f.held = true
	f.events = append(f.events, "hold")
	return nil
}
func (f *fakeInhibitor) Release() error {
	if f.failRelease {
		return errors.New("store removal failed")
	}
	f.held = false
	f.events = append(f.events, "release")
	return nil
}

func TestBlockUntilCompositorSecureAndReacquireBeforeUnlock(t *testing.T) {
	f := &fakeInhibitor{}
	g, err := New(f)
	if err != nil {
		t.Fatal(err)
	}
	if !f.held {
		t.Fatal("startup did not hold block")
	}
	if err := g.PrepareUnlock(); err == nil {
		t.Fatal("unknown compositor permitted unlock")
	}
	if err := g.CompositorState(true); err != nil {
		t.Fatal(err)
	}
	if f.held {
		t.Fatal("secure compositor did not release block")
	}
	if err := g.PrepareUnlock(); err != nil {
		t.Fatal(err)
	}
	if !f.held {
		t.Fatal("unlock returned before inhibitor acquired")
	}
	if err := g.CompositorState(false); err != nil {
		t.Fatal(err)
	}
	if !f.held {
		t.Fatal("unlock dropped block")
	}
	if !reflect.DeepEqual(f.events, []string{"hold", "release", "hold", "hold"}) {
		t.Fatal(f.events)
	}
}

func TestFailuresKeepLockAndDoNotAuthorizeSuspend(t *testing.T) {
	if _, err := New(&fakeInhibitor{failHold: true}); err == nil {
		t.Fatal("started without retained inhibitor")
	}
	f := &fakeInhibitor{}
	g, _ := New(f)
	f.failRelease = true
	if err := g.CompositorState(true); err == nil {
		t.Fatal("ignored removal failure")
	}
	if g.secure || !f.held {
		t.Fatal("failed secure transition changed authorization")
	}
	f.failRelease = false
	if err := g.CompositorState(true); err != nil {
		t.Fatal(err)
	}
	f.failHold = true
	if err := g.PrepareUnlock(); err == nil {
		t.Fatal("unlock authorized without retained inhibitor")
	}
	if !g.secure || g.preparingUnlock {
		t.Fatal("failed unlock changed state")
	}
}

func TestSuspendWaitsForSecureAndRejectsUnknownOrPreparingUnlock(t *testing.T) {
	for _, phase := range []string{"unknown", "preparing-unlock", "disconnected"} {
		t.Run(phase, func(t *testing.T) {
			f := &fakeInhibitor{}
			g, _ := New(f)
			if phase != "unknown" {
				if err := g.CompositorState(true); err != nil {
					t.Fatal(err)
				}
			}
			if phase == "preparing-unlock" {
				if err := g.PrepareUnlock(); err != nil {
					t.Fatal(err)
				}
			}
			if phase == "disconnected" {
				if err := g.CompositorState(false); err != nil {
					t.Fatal(err)
				}
			}
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Millisecond)
			defer cancel()
			calls := 0
			err := g.Suspend(ctx, func(context.Context) error { calls++; return nil })
			if !errors.Is(err, context.DeadlineExceeded) || calls != 0 || !f.held {
				t.Fatalf("unsafe suspend: err=%v calls=%d held=%v", err, calls, f.held)
			}
		})
	}
	f := &fakeInhibitor{}
	g, _ := New(f)
	result := make(chan error, 1)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	go func() {
		result <- g.Suspend(ctx, func(context.Context) error {
			if f.held {
				return errors.New("block still held")
			}
			return nil
		})
	}()
	if err := g.CompositorState(true); err != nil {
		t.Fatal(err)
	}
	if err := <-result; err != nil {
		t.Fatal(err)
	}
}

func TestUnlockWaitsThroughAsynchronousSleepAfterMethodReturns(t *testing.T) {
	f := &fakeInhibitor{}
	g, _ := New(f)
	if err := g.CompositorState(true); err != nil {
		t.Fatal(err)
	}
	entered, finish := make(chan struct{}), make(chan struct{})
	suspended := make(chan error, 1)
	go func() {
		suspended <- g.Suspend(context.Background(), func(context.Context) error { close(entered); <-finish; return nil })
	}()
	<-entered
	if err := g.PrepareUnlock(); err == nil {
		t.Fatal("unlock interleaved with logind suspend")
	}
	close(finish)
	if err := <-suspended; err != nil {
		t.Fatal(err)
	}
	if err := g.PrepareUnlock(); err == nil {
		t.Fatal("method return incorrectly ended pending sleep")
	}
	g.SleepState(true)
	if err := g.PrepareUnlock(); err == nil {
		t.Fatal("unlock permitted while delay inhibitors pending")
	}
	g.SleepState(false)
	if err := g.PrepareUnlock(); err != nil {
		t.Fatal(err)
	}
	if !f.held {
		t.Fatal("unlock did not reacquire after suspend")
	}
}

func TestExternalSleepDetectedBeforeQueuedSignal(t *testing.T) {
	f := &fakeInhibitor{}
	g, _ := New(f)
	if err := g.CompositorState(true); err != nil {
		t.Fatal(err)
	}
	// Logind has accepted an external request, but its signal has not been
	// dispatched to this process. The post-inhibit property query must catch it.
	f.sleeping = true
	if err := g.PrepareUnlock(); err == nil {
		t.Fatal("queued external sleep signal permitted unlock")
	}
	if !f.held {
		t.Fatal("external sleep refusal did not retain block")
	}
	f.sleeping = false
	f.failSleepQuery = true
	if err := g.PrepareUnlock(); err == nil {
		t.Fatal("unknown authoritative sleep state permitted unlock")
	}
	f.failSleepQuery = false
	if err := g.PrepareUnlock(); err != nil {
		t.Fatal(err)
	}
}

func TestRejectedSleepAllowsRetryButTimeoutStaysLatched(t *testing.T) {
	for _, timedOut := range []bool{false, true} {
		f := &fakeInhibitor{}
		g, _ := New(f)
		if err := g.CompositorState(true); err != nil {
			t.Fatal(err)
		}
		ctx, cancel := context.WithCancel(context.Background())
		err := g.Suspend(ctx, func(context.Context) error {
			if timedOut {
				cancel()
				return context.Canceled
			}
			return errors.New("logind refused suspend")
		})
		cancel()
		if err == nil {
			t.Fatal("expected suspend failure")
		}
		unlockErr := g.PrepareUnlock()
		if timedOut && unlockErr == nil {
			t.Fatal("unknown suspend result allowed unlock")
		}
		if !timedOut && unlockErr != nil {
			t.Fatal(unlockErr)
		}
	}
}

func TestRepeatedSuspendDoesNotQueueAnotherSleepOnResume(t *testing.T) {
	f := &fakeInhibitor{}
	g, _ := New(f)
	if err := g.CompositorState(true); err != nil {
		t.Fatal(err)
	}
	calls := 0
	request := func(context.Context) error { calls++; return nil }
	if err := g.Suspend(context.Background(), request); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if err := g.Suspend(ctx, request); err == nil || errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("second request was queued instead of refused: %v", err)
	}
	g.SleepState(false)
	if calls != 1 {
		t.Fatalf("queued another suspend: %d", calls)
	}
}
