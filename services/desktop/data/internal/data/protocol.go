package data

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"regexp"
	"unicode/utf8"
)

const (
	Version          = 1
	MaxRequestBytes  = 64 * 1024
	MaxSnapshotBytes = 4 * 1024 * 1024
	MaxItems         = 2048
)

type Topic string

const (
	Projects      Topic = "projects"
	AgentRuns     Topic = "agent_runs"
	Network       Topic = "network"
	Appearance    Topic = "appearance"
	Recording     Topic = "recording"
	Power         Topic = "power"
	Notifications Topic = "notifications"
)

var Topics = []Topic{Projects, AgentRuns, Network, Appearance, Recording, Power, Notifications}

const (
	NotificationShowAction    = "notifications.show"
	NotificationDismissAction = "notifications.dismiss"
	NotificationClearAction   = "notifications.clear"
	NotificationSetDNDAction  = "notifications.set_dnd"
)

func (t Topic) Valid() bool {
	for _, topic := range Topics {
		if t == topic {
			return true
		}
	}
	return false
}

type Request struct {
	SchemaVersion int     `json:"schema_version"`
	RequestID     string  `json:"request_id"`
	Op            string  `json:"op"`
	Topics        []Topic `json:"topics"`
	Metrics       bool    `json:"metrics,omitempty"`
}

func DecodeRequest(line []byte) (Request, error) {
	var r Request
	if len(line) > MaxRequestBytes || !utf8.Valid(line) {
		return r, errors.New("invalid request encoding or size")
	}
	d := json.NewDecoder(bytes.NewReader(line))
	d.DisallowUnknownFields()
	if err := d.Decode(&r); err != nil {
		return r, err
	}
	if err := d.Decode(new(any)); err != io.EOF {
		return r, errors.New("one JSON object required")
	}
	if r.SchemaVersion != Version || !identifier.MatchString(r.RequestID) || len(r.RequestID) > 64 {
		return r, errors.New("invalid schema version or request ID")
	}
	if r.Op != "subscribe" && r.Op != "unsubscribe" {
		return r, errors.New("unknown operation")
	}
	if len(r.Topics) == 0 || len(r.Topics) > len(Topics) {
		return r, errors.New("one to seven topics required")
	}
	seen := map[Topic]bool{}
	for _, topic := range r.Topics {
		if !topic.Valid() || seen[topic] {
			return r, errors.New("unknown or duplicate topic")
		}
		seen[topic] = true
	}
	if r.Metrics && (r.Op != "subscribe" || !seen[AgentRuns]) {
		return r, errors.New("metrics require agent_runs subscription")
	}
	return r, nil
}

type Fault struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func (f *Fault) Error() string { return f.Code + ": " + f.Message }

type Snapshot struct {
	SchemaVersion int    `json:"schema_version"`
	Type          string `json:"type"`
	Topic         Topic  `json:"topic"`
	Revision      string `json:"revision"`
	ObservedAt    string `json:"observed_at"`
	Status        string `json:"status"`
	Data          any    `json:"data"`
	Error         *Fault `json:"error"`
}

type Result struct {
	SchemaVersion int    `json:"schema_version"`
	Type          string `json:"type"`
	RequestID     string `json:"request_id"`
	Status        string `json:"status"`
	Error         *Fault `json:"error"`
}

type Project struct {
	ID                 string `json:"id"`
	Label              string `json:"label"`
	DirectoryAvailable bool   `json:"directory_available"`
}

type ProjectData struct {
	SelectedID *string   `json:"selected_id"`
	Items      []Project `json:"items"`
}

type Run struct {
	ID               string  `json:"id"`
	ProjectID        *string `json:"project_id"`
	Label            string  `json:"label"`
	Unit             string  `json:"unit"`
	State            string  `json:"state"`
	StartedAt        string  `json:"started_at"`
	EndedAt          *string `json:"ended_at"`
	ExitStatus       *int    `json:"exit_status"`
	CPUUsageNS       *string `json:"cpu_usage_ns"`
	MemoryBytes      *string `json:"memory_bytes"`
	MaxRSSBytes      *string `json:"max_rss_bytes"`
	WallSeconds      *string `json:"wall_seconds"`
	UserCPUSeconds   *string `json:"user_cpu_seconds"`
	SystemCPUSeconds *string `json:"system_cpu_seconds"`
	ProviderUsage    any     `json:"provider_usage"`
}

type RunData struct {
	Items []Run `json:"items"`
}

// NotificationData is the bounded Dunst history contract. Dunst does not
// track an application-level read state; unread_count therefore mirrors its
// waitingLength property, and is nil when that property is unavailable.
type NotificationData struct {
	DND         bool               `json:"dnd"`
	UnreadCount *int               `json:"unread_count"`
	Items       []NotificationItem `json:"items"`
}

type NotificationItem struct {
	ID        string               `json:"id"`
	AppLabel  string               `json:"app_label"`
	Summary   string               `json:"summary"`
	Body      string               `json:"body"`
	Urgency   string               `json:"urgency"`
	Timestamp string               `json:"timestamp"`
	Actions   []NotificationAction `json:"actions"`
	State     string               `json:"state"`
}

type NotificationAction struct {
	ID    string `json:"id"`
	Label string `json:"label"`
}

type Refresh uint8

const (
	Records Refresh = 1 << iota
	Lifecycle
	Metrics
)

var identifier = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]*$`)
var runID = regexp.MustCompile(`^run-[A-Za-z0-9T._-]+$`)
var unitID = regexp.MustCompile(`^blendos-agent-[A-Za-z0-9T._-]+\.scope$`)
