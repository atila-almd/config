package data

import (
	"bufio"
	"context"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

type fakeSource struct {
	metrics atomic.Int32
	blocked <-chan struct{}
}

type delayedMetrics struct {
	entered chan struct{}
	release chan struct{}
}

func (s *delayedMetrics) Load(ctx context.Context, topic Topic, refresh Refresh, metrics bool) (any, bool, error) {
	if refresh == Metrics {
		s.entered <- struct{}{}
		select {
		case <-s.release:
		case <-ctx.Done():
			return nil, false, ctx.Err()
		}
	}
	return RunData{Items: []Run{}}, true, nil
}

func TestPendingMetricTickDoesNotDiscardCompletedSample(t *testing.T) {
	source := &delayedMetrics{make(chan struct{}, 2), make(chan struct{})}
	changes := make(chan Change)
	path := startServer(t, &Server{Source: source, Interval: time.Hour}, changes)
	c := connectClient(t, path)
	c.request(t, "subscribe", []Topic{AgentRuns}, true)
	c.next(t, "snapshot")
	changes <- Change{AgentRuns, Metrics}
	select {
	case <-source.entered:
	case <-time.After(time.Second):
		t.Fatal("metric load did not start")
	}
	// This invalidation is received while the first sample is blocked.
	changes <- Change{AgentRuns, Metrics}
	source.release <- struct{}{}
	// The next load remains blocked, but the first sample must be published.
	c.next(t, "snapshot")
	select {
	case <-source.entered:
	case <-time.After(time.Second):
		t.Fatal("pending sample did not start")
	}
}

func (s *fakeSource) Load(ctx context.Context, topic Topic, refresh Refresh, wantsMetrics bool) (any, bool, error) {
	if topic == Projects {
		if s.blocked != nil {
			select {
			case <-s.blocked:
			case <-ctx.Done():
				return nil, false, ctx.Err()
			}
		}
		return ProjectData{Items: []Project{}}, false, nil
	}
	if refresh == Metrics {
		s.metrics.Add(1)
	}
	return RunData{Items: []Run{}}, true, nil
}

type fakeTicker struct {
	ch      chan time.Time
	stopped atomic.Int32
}

func (t *fakeTicker) Channel() <-chan time.Time { return t.ch }
func (t *fakeTicker) Stop()                     { t.stopped.Add(1) }

type testClient struct {
	net.Conn
	scanner *bufio.Scanner
}

func connectClient(t *testing.T, path string) *testClient {
	t.Helper()
	conn, err := net.Dial("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.Close() })
	s := bufio.NewScanner(conn)
	s.Buffer(make([]byte, 4096), MaxSnapshotBytes)
	return &testClient{conn, s}
}
func (c *testClient) request(t *testing.T, op string, topics []Topic, metrics bool) {
	t.Helper()
	if err := json.NewEncoder(c.Conn).Encode(Request{Version, "test", op, topics, metrics}); err != nil {
		t.Fatal(err)
	}
}
func (c *testClient) next(t *testing.T, kind string) map[string]any {
	t.Helper()
	c.SetReadDeadline(time.Now().Add(3 * time.Second))
	for c.scanner.Scan() {
		var value map[string]any
		if err := json.Unmarshal(c.scanner.Bytes(), &value); err != nil {
			t.Fatal(err)
		}
		if value["type"] == kind {
			return value
		}
	}
	t.Fatalf("connection ended waiting for %s: %v", kind, c.scanner.Err())
	return nil
}

func startServer(t *testing.T, s *Server, changes <-chan Change) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "data.sock")
	l, err := net.Listen("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(t.Context())
	done := make(chan error, 1)
	go func() { done <- s.Serve(ctx, l, changes) }()
	t.Cleanup(func() {
		cancel()
		select {
		case err := <-done:
			if err != nil {
				t.Error(err)
			}
		case <-time.After(3 * time.Second):
			t.Error("server did not shut down")
		}
	})
	return path
}

func TestSharedSchedulerAndLastObserverCleanup(t *testing.T) {
	source := &fakeSource{}
	tick := &fakeTicker{ch: make(chan time.Time, 1)}
	started := make(chan struct{}, 4)
	server := &Server{Source: source, newTicker: func(time.Duration) ticker { started <- struct{}{}; return tick }}
	path := startServer(t, server, nil)
	one, two := connectClient(t, path), connectClient(t, path)
	one.request(t, "subscribe", []Topic{AgentRuns}, true)
	one.next(t, "snapshot")
	select {
	case <-started:
	case <-time.After(time.Second):
		t.Fatal("no scheduler")
	}
	two.request(t, "subscribe", []Topic{AgentRuns}, true)
	two.next(t, "snapshot")
	select {
	case <-started:
		t.Fatal("second consumer created another scheduler")
	default:
	}
	// Drain the subscription refresh broadcast before injecting the only tick.
	one.next(t, "snapshot")
	tick.ch <- time.Now()
	one.next(t, "snapshot")
	two.next(t, "snapshot")
	if source.metrics.Load() != 1 {
		t.Fatalf("metric refreshes=%d", source.metrics.Load())
	}
	one.request(t, "unsubscribe", []Topic{AgentRuns}, false)
	one.next(t, "result")
	if tick.stopped.Load() != 0 {
		t.Fatal("remaining observer lost sampling")
	}
	two.request(t, "unsubscribe", []Topic{AgentRuns}, false)
	two.next(t, "result")
	// A request/response round trip ensures the preceding event has been handled.
	two.request(t, "subscribe", []Topic{Projects}, false)
	two.next(t, "snapshot")
	if tick.stopped.Load() != 1 {
		t.Fatalf("scheduler stop count=%d", tick.stopped.Load())
	}
}

func TestSlowTopicDoesNotBlockOtherTopicsAndReconnectGetsSnapshot(t *testing.T) {
	block := make(chan struct{})
	path := startServer(t, &Server{Source: &fakeSource{blocked: block}}, nil)
	one, two := connectClient(t, path), connectClient(t, path)
	one.request(t, "subscribe", []Topic{Projects}, false)
	one.next(t, "result")
	two.request(t, "subscribe", []Topic{AgentRuns}, false)
	if got := two.next(t, "snapshot"); got["topic"] != "agent_runs" {
		t.Fatal(got)
	}
	close(block)
	first := one.next(t, "snapshot")
	one.Close()
	three := connectClient(t, path)
	three.request(t, "subscribe", []Topic{Projects}, false)
	second := three.next(t, "snapshot")
	if first["revision"] == second["revision"] {
		t.Fatal("reconnect reused an unobserved snapshot")
	}
}

func TestFragmentedRequestsAndMalformedRequestRecovery(t *testing.T) {
	path := startServer(t, &Server{Source: &fakeSource{}}, nil)
	c := connectClient(t, path)
	c.Write([]byte("invalid\n"))
	if got := c.next(t, "result"); got["status"] != "error" {
		t.Fatal(got)
	}
	c.Write([]byte(`{"schema_version":1,"request_id":"x","op":"sub`))
	c.Write([]byte("scribe\",\"topics\":[\"projects\"]}\n"))
	if got := c.next(t, "snapshot"); got["status"] != "ready" {
		t.Fatal(got)
	}
}

func TestOversizedRequestDisconnects(t *testing.T) {
	path := startServer(t, &Server{Source: &fakeSource{}}, nil)
	c := connectClient(t, path)
	c.SetDeadline(time.Now().Add(time.Second))
	c.Write([]byte(strings.Repeat("x", MaxRequestBytes+2) + "\n"))
	if c.scanner.Scan() {
		t.Fatal("oversized request accepted")
	}
}

func TestSocketOwnershipAndSingleInstance(t *testing.T) {
	runtime := t.TempDir()
	if err := os.Chmod(runtime, 0700); err != nil {
		t.Fatal(err)
	}
	l, cleanup, err := Listen(runtime)
	if err != nil {
		t.Fatal(err)
	}
	defer cleanup()
	if _, release, err := Listen(runtime); err == nil {
		release()
		t.Fatal("second server acquired socket")
	}
	c, err := net.Dial("unix", l.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	c.Close()
	info, err := os.Stat(filepath.Join(runtime, "blendos-workstation", "data.sock"))
	if err != nil || info.Mode().Perm() != 0600 {
		t.Fatalf("socket permissions: %v %v", info, err)
	}
	cleanup()
	if err := os.WriteFile(filepath.Join(runtime, "blendos-workstation", "data.sock"), []byte("personal"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, release, err := Listen(runtime); err == nil {
		release()
		t.Fatal("overwrote non-socket")
	}
}
