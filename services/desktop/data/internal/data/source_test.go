package data

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"
)

type fakeSystemd struct {
	active     bool
	failed     bool
	stateCalls int
	usageCalls int
}

func (s *fakeSystemd) State(_ context.Context, _ string) (UnitState, error) {
	s.stateCalls++
	if s.failed {
		return UnitState{}, errors.New("private diagnostic must not escape")
	}
	return UnitState{Active: s.active, Path: "/unit/demo"}, nil
}
func (s *fakeSystemd) Usage(_ context.Context, _ string) (*string, *string, error) {
	s.usageCalls++
	return ptr("9007199254740993"), nil, nil
}

func ptr[T any](v T) *T { return &v }

func helperFixture(t *testing.T, json string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "helper")
	if err := os.WriteFile(path, []byte("#!/bin/sh\ncat <<'JSON'\n"+json+"\nJSON\n"), 0700); err != nil {
		t.Fatal(err)
	}
	return path
}

const runningRecord = `{"schema_version":1,"data":{"items":[{"id":"run-demo","project_id":"demo","label":"agent","unit":"blendos-agent-demo.scope","state":"running","started_at":"2026-09-09T00:00:00Z","ended_at":null,"exit_status":null,"cpu_usage_ns":null,"memory_bytes":null,"max_rss_kib":"9007199254740","wall_seconds":null,"user_cpu_seconds":null,"system_cpu_seconds":null,"provider_usage":null}]}}`

func TestSourceMetricsDoNotReloadRecordsOrPollLifecycle(t *testing.T) {
	helper := helperFixture(t, runningRecord)
	systemd := &fakeSystemd{active: true}
	source := &Helpers{AgentCommand: helper, Systemd: systemd}
	value, active, err := source.Load(t.Context(), AgentRuns, Records|Lifecycle, true)
	if err != nil || !active {
		t.Fatalf("initial load: %v %v", active, err)
	}
	run := value.(RunData).Items[0]
	if *run.CPUUsageNS != "9007199254740993" || run.MemoryBytes != nil || *run.MaxRSSBytes != "9223372036853760" {
		t.Fatalf("lost metric precision or availability: %+v", run)
	}
	// A metric tick must not touch the source helper or repeat lifecycle queries.
	if err := os.Remove(helper); err != nil {
		t.Fatal(err)
	}
	if _, _, err := source.Load(t.Context(), AgentRuns, Metrics, true); err != nil {
		t.Fatal(err)
	}
	if systemd.stateCalls != 1 || systemd.usageCalls != 2 {
		t.Fatalf("state=%d usage=%d", systemd.stateCalls, systemd.usageCalls)
	}
	if _, _, err := source.Load(t.Context(), AgentRuns, Lifecycle, false); err != nil {
		t.Fatal(err)
	}
	if systemd.usageCalls != 2 {
		t.Fatal("sampled metrics without interest")
	}
}

func TestSourceLostStateAndUnavailableBusAreDifferent(t *testing.T) {
	systemd := &fakeSystemd{}
	source := &Helpers{AgentCommand: helperFixture(t, runningRecord), Systemd: systemd}
	value, active, err := source.Load(t.Context(), AgentRuns, Records, true)
	if err != nil || active || value.(RunData).Items[0].State != "state-lost" {
		t.Fatalf("missing scope: %v %v %v", value, active, err)
	}
	systemd.failed = true
	_, _, err = source.Load(t.Context(), AgentRuns, Lifecycle, true)
	var fault *Fault
	if !errors.As(err, &fault) || fault.Code != "systemd_unavailable" {
		t.Fatalf("bus failure became a missing scope: %v", err)
	}
	if fault.Message == "private diagnostic must not escape" {
		t.Fatal("leaked backend diagnostic")
	}
}

func TestSourceRejectsMalformedAndKeepsEmptyArrays(t *testing.T) {
	for _, text := range []string{`broken`, `{"schema_version":9,"data":{"items":[]}}`, `{"schema_version":1,"data":{"items":null}}`, `{"schema_version":1,"data":{"items":[{"id":"../escape"}]}}`} {
		source := &Helpers{ProjectCommand: helperFixture(t, text)}
		if _, _, err := source.Load(t.Context(), Projects, Records, false); err == nil {
			t.Fatalf("accepted %s", text)
		}
	}
	source := &Helpers{ProjectCommand: helperFixture(t, `{"schema_version":1,"data":{"selected_id":null,"items":[]}}`)}
	v, _, err := source.Load(t.Context(), Projects, Records, false)
	if err != nil || v.(ProjectData).Items == nil {
		t.Fatalf("empty collection: %v %v", v, err)
	}
}

func TestHelperCancellationKillsItsProcessGroup(t *testing.T) {
	path := filepath.Join(t.TempDir(), "slow-helper")
	if err := os.WriteFile(path, []byte("#!/bin/sh\nsleep 30\n"), 0700); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(t.Context(), 50*time.Millisecond)
	defer cancel()
	started := time.Now()
	var value any
	if err := readHelper(ctx, path, &value); err == nil {
		t.Fatal("slow helper succeeded")
	}
	if time.Since(started) > 2*time.Second {
		t.Fatal("helper children outlived cancellation")
	}
}

func TestCounterAvailabilityAndOverflow(t *testing.T) {
	for _, v := range []string{"unavailable", "-1", "18446744073709551615", "18446744073709551616"} {
		if counter(&v) != nil {
			t.Fatalf("accepted counter %s", v)
		}
	}
	if kibibytes(ptr("18014398509481984")) != nil {
		t.Fatal("RSS overflow wrapped")
	}
	if v := counter(ptr("0")); v == nil || *v != "0" {
		t.Fatal("zero became unavailable")
	}
}
