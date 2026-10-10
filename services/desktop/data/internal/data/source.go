package data

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"math"
	"os/exec"
	"slices"
	"strconv"
	"syscall"
	"time"
)

// A Source is called serially per topic; different topics may refresh concurrently.
// Every returned value is immutable after return and safe for JSON publication.
type Source interface {
	Load(context.Context, Topic, Refresh, bool) (value any, activeRuns bool, err error)
}

type UnitState struct {
	Active bool
	Path   string
}

type SystemdReader interface {
	State(context.Context, string) (UnitState, error)
	Usage(context.Context, string) (cpu, memory *string, err error)
}

type Helpers struct {
	ProjectCommand  string
	AgentCommand    string
	ControlsCommand string
	RecordCommand   string
	Desktop         DesktopReader
	Notifications   NotificationReader
	Systemd         SystemdReader
	runs            []Run
	states          map[string]UnitState
}

func (h *Helpers) Load(ctx context.Context, topic Topic, refresh Refresh, metrics bool) (any, bool, error) {
	switch topic {
	case Projects:
		var p ProjectData
		if err := readHelper(ctx, h.ProjectCommand, &p); err != nil {
			return nil, false, err
		}
		if p.Items == nil || len(p.Items) > MaxItems {
			return nil, false, malformed()
		}
		seen := map[string]bool{}
		for _, item := range p.Items {
			if !identifier.MatchString(item.ID) || seen[item.ID] || len(item.Label) > 4096 {
				return nil, false, malformed()
			}
			seen[item.ID] = true
		}
		if p.SelectedID != nil && !seen[*p.SelectedID] {
			return nil, false, malformed()
		}
		slices.SortFunc(p.Items, func(a, b Project) int { return compare(a.ID, b.ID) })
		return p, false, nil
	case AgentRuns:
		return h.loadRuns(ctx, refresh, metrics)
	case Network, Power:
		if h.Desktop == nil {
			return nil, false, &Fault{"backend_unavailable", "The desktop backend is unavailable."}
		}
		value, err := h.Desktop.Load(ctx, topic)
		return value, false, err
	case Notifications:
		if h.Notifications == nil {
			return nil, false, &Fault{"backend_unavailable", "Desktop notifications are unavailable."}
		}
		value, err := h.Notifications.Load(ctx)
		return value, false, err
	case Appearance:
		var value AppearanceData
		if err := readHelperArgs(ctx, h.ControlsCommand, &value, "snapshot"); err != nil {
			return nil, false, err
		}
		if !value.valid() {
			return nil, false, malformed()
		}
		return value, false, nil
	case Recording:
		var value RecordingData
		if err := readHelperArgs(ctx, h.RecordCommand, &value, "snapshot"); err != nil {
			return nil, false, err
		}
		if !value.valid() {
			return nil, false, malformed()
		}
		return value, false, nil
	default:
		return nil, false, malformed()
	}
}

func (h *Helpers) loadRuns(ctx context.Context, refresh Refresh, metrics bool) (any, bool, error) {
	if refresh&Records != 0 || h.runs == nil {
		var raw struct {
			Items []struct {
				Run
				MaxRSSKiB *string `json:"max_rss_kib"`
			} `json:"items"`
		}
		if err := readHelper(ctx, h.AgentCommand, &raw); err != nil {
			return nil, false, err
		}
		if raw.Items == nil || len(raw.Items) > MaxItems {
			return nil, false, malformed()
		}
		runs := make([]Run, 0, len(raw.Items))
		seen := map[string]bool{}
		for _, item := range raw.Items {
			r := item.Run
			if !runID.MatchString(r.ID) || !unitID.MatchString(r.Unit) || seen[r.ID] || len(r.Label) > 4096 || r.ProviderUsage != nil {
				return nil, false, malformed()
			}
			if r.ProjectID != nil && !identifier.MatchString(*r.ProjectID) {
				return nil, false, malformed()
			}
			if _, err := time.Parse(time.RFC3339, r.StartedAt); err != nil {
				return nil, false, malformed()
			}
			if r.EndedAt != nil {
				if _, err := time.Parse(time.RFC3339, *r.EndedAt); err != nil {
					return nil, false, malformed()
				}
			}
			if r.ExitStatus != nil && (*r.ExitStatus < 0 || *r.ExitStatus > 255) {
				return nil, false, malformed()
			}
			switch r.State {
			case "running", "succeeded", "failed", "interrupted":
			default:
				return nil, false, malformed()
			}
			seen[r.ID] = true
			r.CPUUsageNS = counter(r.CPUUsageNS)
			r.MemoryBytes = counter(r.MemoryBytes)
			r.MaxRSSBytes = kibibytes(item.MaxRSSKiB)
			runs = append(runs, r)
		}
		slices.SortFunc(runs, func(a, b Run) int {
			if a.StartedAt != b.StartedAt {
				return compare(b.StartedAt, a.StartedAt)
			}
			return compare(a.ID, b.ID)
		})
		h.runs = runs
		refresh |= Lifecycle
	}
	if refresh&Lifecycle != 0 || h.states == nil {
		states := make(map[string]UnitState)
		for _, r := range h.runs {
			if r.State != "running" {
				continue
			}
			state, err := h.Systemd.State(ctx, r.Unit)
			if err != nil {
				return nil, false, &Fault{"systemd_unavailable", "Unable to observe agent scopes."}
			}
			states[r.Unit] = state
		}
		h.states = states
	}
	result := RunData{Items: slices.Clone(h.runs)}
	active := false
	for i := range result.Items {
		r := &result.Items[i]
		if r.State != "running" {
			continue
		}
		r.CPUUsageNS, r.MemoryBytes = nil, nil
		state := h.states[r.Unit]
		if !state.Active {
			r.State = "state-lost"
			continue
		}
		active = true
		if metrics {
			cpu, memory, err := h.Systemd.Usage(ctx, state.Path)
			if err != nil {
				return nil, false, &Fault{"systemd_unavailable", "Unable to read agent accounting."}
			}
			r.CPUUsageNS, r.MemoryBytes = cpu, memory
		}
	}
	return result, active, nil
}

func counter(value *string) *string {
	if value == nil {
		return nil
	}
	n, err := strconv.ParseUint(*value, 10, 64)
	if err != nil || n == math.MaxUint64 {
		return nil
	}
	s := strconv.FormatUint(n, 10)
	return &s
}

func kibibytes(value *string) *string {
	v := counter(value)
	if v == nil {
		return nil
	}
	n, _ := strconv.ParseUint(*v, 10, 64)
	if n > math.MaxUint64/1024 {
		return nil
	}
	s := strconv.FormatUint(n*1024, 10)
	return &s
}

func compare(a, b string) int {
	if a < b {
		return -1
	}
	if a > b {
		return 1
	}
	return 0
}

func malformed() *Fault {
	return &Fault{"invalid_backend_data", "The backend returned invalid or oversized data."}
}

type limitedBuffer struct{ bytes.Buffer }

func (b *limitedBuffer) Write(p []byte) (int, error) {
	if b.Len()+len(p) > MaxSnapshotBytes {
		return 0, errors.New("backend response too large")
	}
	return b.Buffer.Write(p)
}

func readHelper(ctx context.Context, command string, value any) error {
	return readHelperArgs(ctx, command, value, "list")
}

func readHelperArgs(ctx context.Context, command string, value any, args ...string) error {
	cmd := exec.CommandContext(ctx, command, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	cmd.WaitDelay = 250 * time.Millisecond
	var output limitedBuffer
	cmd.Stdout = &output
	// Helper stderr can contain private paths; it is never sent to the UI/log.
	cmd.Stderr = io.Discard
	if err := cmd.Run(); err != nil {
		return &Fault{"backend_unavailable", "The backend snapshot could not be read."}
	}
	var envelope struct {
		SchemaVersion int             `json:"schema_version"`
		Data          json.RawMessage `json:"data"`
		Error         *Fault          `json:"error"`
	}
	if err := json.Unmarshal(output.Bytes(), &envelope); err != nil || envelope.SchemaVersion != Version || len(envelope.Data) == 0 {
		return malformed()
	}
	if envelope.Error != nil {
		if envelope.Error.Code == "invalid_settings" {
			return &Fault{"invalid_settings", "Saved shell settings are invalid; reset them explicitly."}
		}
		return malformed()
	}
	if err := json.Unmarshal(envelope.Data, value); err != nil {
		return malformed()
	}
	return nil
}
