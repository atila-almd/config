package data

import (
	"context"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"
)

func TestDesktopStateWatchesAtomicSettingsAndRecording(t *testing.T) {
	root := t.TempDir()
	shell := filepath.Join(root, "shell")
	recording := filepath.Join(root, "recording")
	changes := watchFixture(t, filepath.Join(root, "projects"), filepath.Join(root, "agents"), WatchRoot{Path: shell, Topic: Appearance}, WatchRoot{Path: recording, Topic: Recording})
	if _, err := os.Stat(shell); !os.IsNotExist(err) {
		t.Fatal("watch created settings state")
	}
	for _, entry := range []struct {
		path  string
		topic Topic
	}{{shell, Appearance}, {recording, Recording}} {
		if err := os.Mkdir(entry.path, 0700); err != nil {
			t.Fatal(err)
		}
		awaitChange(t, changes, entry.topic)
		temp := filepath.Join(entry.path, ".next")
		if err := os.WriteFile(temp, []byte(`{"schema_version":1}`), 0600); err != nil {
			t.Fatal(err)
		}
		if err := os.Rename(temp, filepath.Join(entry.path, "current")); err != nil {
			t.Fatal(err)
		}
		awaitChange(t, changes, entry.topic)
	}
}

type lazyControlsSource struct {
	entered   chan struct{}
	cancelled chan struct{}
	calls     atomic.Int32
}

func (s *lazyControlsSource) Load(ctx context.Context, topic Topic, refresh Refresh, metrics bool) (any, bool, error) {
	s.calls.Add(1)
	s.entered <- struct{}{}
	<-ctx.Done()
	s.cancelled <- struct{}{}
	return nil, false, ctx.Err()
}
func TestControlsLastUnsubscribeCancelsSharedReadWithoutScheduler(t *testing.T) {
	source := &lazyControlsSource{entered: make(chan struct{}, 4), cancelled: make(chan struct{}, 4)}
	var schedulers atomic.Int32
	server := &Server{Source: source, newTicker: func(time.Duration) ticker { schedulers.Add(1); return &fakeTicker{ch: make(chan time.Time)} }}
	changes := make(chan Change)
	path := startServer(t, server, changes)
	client := connectClient(t, path)
	client.request(t, "subscribe", []Topic{Network}, false)
	client.next(t, "result")
	select {
	case <-source.entered:
	case <-time.After(time.Second):
		t.Fatal("first open did not request facts")
	}
	client.request(t, "unsubscribe", []Topic{Network}, false)
	client.next(t, "result")
	select {
	case <-source.cancelled:
	case <-time.After(time.Second):
		t.Fatal("hidden controls retained backend read")
	}
	changes <- Change{Network, Lifecycle}
	client.request(t, "subscribe", []Topic{Network}, false)
	client.next(t, "result")
	select {
	case <-source.entered:
	case <-time.After(time.Second):
		t.Fatal("reopen did not refresh")
	}
	if source.calls.Load() != 2 || schedulers.Load() != 0 {
		t.Fatalf("calls=%d schedulers=%d", source.calls.Load(), schedulers.Load())
	}
}
