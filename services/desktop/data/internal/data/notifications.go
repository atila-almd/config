package data

import (
	"context"
	"strconv"
	"strings"
	"sync/atomic"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/godbus/dbus/v5"
)

const (
	dunstName             = "org.freedesktop.Notifications"
	dunstPath             = dbus.ObjectPath("/org/freedesktop/Notifications")
	dunstCommandInterface = "org.dunstproject.cmd0"

	maxDunstHistoryRows = 50
	maxDunstAppBytes    = 256
	maxDunstTextBytes   = 4096
)

// NotificationReader is deliberately narrower than DesktopReader: the
// notification source owns the session-bus contract and its bounded decoder.
type NotificationReader interface {
	Load(context.Context) (NotificationData, error)
}

// dunstSignals only marks the topic dirty. The server performs the bounded
// history/property read when notifications has an active subscriber.
type dunstSignals struct {
	ready chan struct{}
	dirty atomic.Bool
}

func (s *dunstSignals) mark() {
	s.dirty.Store(true)
	select {
	case s.ready <- struct{}{}:
	default:
	}
}

func (s *dunstSignals) DeliverSignal(_ string, _ string, signal *dbus.Signal) {
	if signal == nil {
		return
	}
	switch signal.Name {
	case "org.freedesktop.DBus.NameOwnerChanged":
		if len(signal.Body) == 3 && signal.Body[0] == dunstName {
			s.mark()
		}
	case dunstCommandInterface + ".NotificationHistoryRemoved",
		dunstCommandInterface + ".NotificationHistoryCleared",
		dunstName + ".NotificationClosed",
		dunstName + ".ActionInvoked":
		s.mark()
	case "org.freedesktop.DBus.Properties.PropertiesChanged":
		if signal.Path != dunstPath || len(signal.Body) == 0 {
			return
		}
		if iface, ok := signal.Body[0].(string); ok && iface == dunstCommandInterface {
			s.mark()
		}
	}
}

type DunstReader struct {
	conn    *dbus.Conn
	signals *dunstSignals
}

func ConnectDunst(ctx context.Context) (*DunstReader, error) {
	signals := &dunstSignals{ready: make(chan struct{}, 1)}
	conn, err := dbus.ConnectSessionBus(dbus.WithContext(ctx), dbus.WithSignalHandler(signals))
	if err != nil {
		return nil, err
	}
	d := &DunstReader{conn: conn, signals: signals}
	matches := [][]dbus.MatchOption{
		{dbus.WithMatchSender(dunstName), dbus.WithMatchInterface(dunstCommandInterface), dbus.WithMatchMember("NotificationHistoryRemoved"), dbus.WithMatchObjectPath(dunstPath)},
		{dbus.WithMatchSender(dunstName), dbus.WithMatchInterface(dunstCommandInterface), dbus.WithMatchMember("NotificationHistoryCleared"), dbus.WithMatchObjectPath(dunstPath)},
		{dbus.WithMatchSender(dunstName), dbus.WithMatchInterface(dunstName), dbus.WithMatchMember("NotificationClosed"), dbus.WithMatchObjectPath(dunstPath)},
		{dbus.WithMatchSender(dunstName), dbus.WithMatchInterface(dunstName), dbus.WithMatchMember("ActionInvoked"), dbus.WithMatchObjectPath(dunstPath)},
		{dbus.WithMatchSender(dunstName), dbus.WithMatchInterface("org.freedesktop.DBus.Properties"), dbus.WithMatchMember("PropertiesChanged"), dbus.WithMatchObjectPath(dunstPath)},
		{dbus.WithMatchSender("org.freedesktop.DBus"), dbus.WithMatchInterface("org.freedesktop.DBus"), dbus.WithMatchMember("NameOwnerChanged"), dbus.WithMatchArg(0, dunstName)},
	}
	for _, options := range matches {
		if err := conn.AddMatchSignalContext(ctx, options...); err != nil {
			conn.Close()
			return nil, err
		}
	}
	return d, nil
}

func (d *DunstReader) Close() error { return d.conn.Close() }

func (d *DunstReader) Run(ctx context.Context, invalidate func(Change)) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-d.conn.Context().Done():
			return &Fault{"backend_unavailable", "The notification bus disconnected."}
		case <-d.signals.ready:
			if d.signals.dirty.Swap(false) {
				invalidate(Change{Notifications, Records | Lifecycle})
			}
		}
	}
}

func (d *DunstReader) Load(ctx context.Context) (NotificationData, error) {
	object := d.conn.Object(dunstName, dunstPath)
	var raw []map[string]dbus.Variant
	if err := object.CallWithContext(ctx, dunstCommandInterface+".NotificationListHistory", dbus.FlagNoAutoStart).Store(&raw); err != nil {
		return NotificationData{}, &Fault{"backend_unavailable", "Desktop notifications are unavailable."}
	}
	var properties map[string]dbus.Variant
	if err := object.CallWithContext(ctx, "org.freedesktop.DBus.Properties.GetAll", dbus.FlagNoAutoStart, dunstCommandInterface).Store(&properties); err != nil {
		return NotificationData{}, &Fault{"backend_unavailable", "Desktop notification state is unavailable."}
	}
	dnd, ok := properties["paused"].Value().(bool)
	if !ok {
		return NotificationData{}, malformed()
	}
	unread, err := dunstWaitingLength(properties)
	if err != nil {
		return NotificationData{}, err
	}
	items, err := decodeDunstHistory(raw)
	if err != nil {
		return NotificationData{}, err
	}
	return NotificationData{DND: dnd, UnreadCount: unread, Items: items}, nil
}

func dunstWaitingLength(properties map[string]dbus.Variant) (*int, error) {
	value, ok := properties["waitingLength"]
	if !ok {
		return nil, nil
	}
	n, ok := dunstUnsigned(value.Value())
	if !ok || n > MaxItems {
		return nil, malformed()
	}
	count := int(n)
	return &count, nil
}

func decodeDunstHistory(raw []map[string]dbus.Variant) ([]NotificationItem, error) {
	if len(raw) > MaxItems {
		return nil, malformed()
	}
	if len(raw) > maxDunstHistoryRows {
		raw = raw[:maxDunstHistoryRows]
	}
	items := make([]NotificationItem, 0, len(raw))
	seen := make(map[string]bool, len(raw))
	for _, fields := range raw {
		id, err := dunstID(fields["id"])
		if err != nil || seen[id] {
			return nil, malformed()
		}
		seen[id] = true
		appLabel, err := dunstText(fields, "appname", maxDunstAppBytes)
		if err != nil {
			return nil, malformed()
		}
		if appLabel == "" {
			appLabel = "Notification"
		}
		summary, err := dunstText(fields, "summary", maxDunstTextBytes)
		if err != nil {
			return nil, malformed()
		}
		body, err := dunstText(fields, "body", maxDunstTextBytes)
		if err != nil {
			return nil, malformed()
		}
		urgency, err := dunstText(fields, "urgency", 32)
		if err != nil {
			return nil, malformed()
		}
		urgency = strings.ToLower(urgency)
		if urgency == "" {
			urgency = "normal"
		}
		switch urgency {
		case "low", "normal", "critical":
		default:
			return nil, malformed()
		}
		timestamp, err := dunstTimestamp(fields["timestamp"])
		if err != nil {
			return nil, malformed()
		}
		items = append(items, NotificationItem{
			ID:        id,
			AppLabel:  appLabel,
			Summary:   summary,
			Body:      body,
			Urgency:   urgency,
			Timestamp: timestamp,
			Actions:   []NotificationAction{},
			State:     "history",
		})
	}
	return items, nil
}

func dunstID(value dbus.Variant) (string, error) {
	n, ok := dunstUnsigned(value.Value())
	if !ok || n > uint64(^uint32(0)) {
		return "", malformed()
	}
	return strconv.FormatUint(n, 10), nil
}

func dunstText(fields map[string]dbus.Variant, name string, maxBytes int) (string, error) {
	value, ok := fields[name]
	if !ok {
		return "", nil
	}
	text, ok := value.Value().(string)
	if !ok {
		return "", malformed()
	}
	return sanitizeDunstText(text, maxBytes), nil
}

func sanitizeDunstText(value string, maxBytes int) string {
	value = strings.ToValidUTF8(value, "")
	var result strings.Builder
	result.Grow(minInt(len(value), maxBytes))
	for _, char := range value {
		if unicode.IsControl(char) {
			switch char {
			case '\n', '\t':
			case '\r':
				char = '\n'
			default:
				continue
			}
		}
		width := utf8.RuneLen(char)
		if width < 0 || result.Len()+width > maxBytes {
			break
		}
		result.WriteRune(char)
	}
	return result.String()
}

func dunstTimestamp(value dbus.Variant) (string, error) {
	n, ok := dunstUnsigned(value.Value())
	if !ok || n == 0 || n > uint64(^uint64(0)>>1) {
		return "", malformed()
	}
	return time.UnixMicro(int64(n)).UTC().Format(time.RFC3339Nano), nil
}

func dunstUnsigned(value any) (uint64, bool) {
	switch n := value.(type) {
	case uint8:
		return uint64(n), true
	case uint16:
		return uint64(n), true
	case uint32:
		return uint64(n), true
	case uint64:
		return n, true
	case int8:
		return uint64(n), n >= 0
	case int16:
		return uint64(n), n >= 0
	case int32:
		return uint64(n), n >= 0
	case int64:
		return uint64(n), n >= 0
	case int:
		return uint64(n), n >= 0
	default:
		return 0, false
	}
}

func maxInt() int { return int(^uint(0) >> 1) }

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}
