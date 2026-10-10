package data

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

type mockDunst struct {
	history []map[string]dbus.Variant
	paused  bool
	waiting uint32
}

func (d *mockDunst) NotificationListHistory() ([]map[string]dbus.Variant, *dbus.Error) {
	return d.history, nil
}

func (d *mockDunst) GetAll(iface string) (map[string]dbus.Variant, *dbus.Error) {
	if iface != dunstCommandInterface {
		return nil, dbus.NewError("org.freedesktop.DBus.Error.UnknownInterface", nil)
	}
	return map[string]dbus.Variant{
		"paused":        dbus.MakeVariant(d.paused),
		"waitingLength": dbus.MakeVariant(d.waiting),
	}, nil
}

func exportDunst(t *testing.T, d *mockDunst) *dbus.Conn {
	t.Helper()
	address := privateBus(t)
	t.Setenv("DBUS_SESSION_BUS_ADDRESS", address)
	bus, err := dbus.Connect(address)
	if err != nil {
		t.Fatal(err)
	}
	if err := bus.Export(d, dunstPath, dunstCommandInterface); err != nil {
		bus.Close()
		t.Fatal(err)
	}
	if err := bus.Export(d, dunstPath, "org.freedesktop.DBus.Properties"); err != nil {
		bus.Close()
		t.Fatal(err)
	}
	if _, err := bus.RequestName(dunstName, dbus.NameFlagDoNotQueue); err != nil {
		bus.Close()
		t.Fatal(err)
	}
	t.Cleanup(func() { bus.Close() })
	return bus
}

func testNotification(id int32, timestamp int64) map[string]dbus.Variant {
	return map[string]dbus.Variant{
		"id":        dbus.MakeVariant(id),
		"appname":   dbus.MakeVariant("app"),
		"summary":   dbus.MakeVariant("summary"),
		"body":      dbus.MakeVariant("body"),
		"urgency":   dbus.MakeVariant("normal"),
		"timestamp": dbus.MakeVariant(timestamp),
	}
}

func TestDunstLoadsExactBoundedSanitizedContract(t *testing.T) {
	timestamp := time.Now().UnixMicro()
	first := testNotification(7, timestamp)
	first["appname"] = dbus.MakeVariant("app\x01name")
	first["summary"] = dbus.MakeVariant(strings.Repeat("s", maxDunstTextBytes+64))
	first["body"] = dbus.MakeVariant("body\r\ntext\x01")
	first["urgency"] = dbus.MakeVariant("CRITICAL")
	first["icon_path"] = dbus.MakeVariant("/private/icon")
	first["urls"] = dbus.MakeVariant("file:///private")
	history := []map[string]dbus.Variant{first}
	for id := int32(8); id < 58; id++ {
		history = append(history, testNotification(id, timestamp))
	}
	bus := exportDunst(t, &mockDunst{history: history, paused: true, waiting: 3})
	_ = bus

	reader, err := ConnectDunst(t.Context())
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	value, err := reader.Load(t.Context())
	if err != nil {
		t.Fatal(err)
	}
	if !value.DND || value.UnreadCount == nil || *value.UnreadCount != 3 {
		t.Fatalf("dunst state: %+v", value)
	}
	if len(value.Items) != maxDunstHistoryRows {
		t.Fatalf("history rows=%d", len(value.Items))
	}
	item := value.Items[0]
	if item.ID != "7" || item.AppLabel != "appname" || item.Summary != strings.Repeat("s", maxDunstTextBytes) || item.Body != "body\n\ntext" || item.Urgency != "critical" || item.State != "history" {
		t.Fatalf("decoded notification: %+v", item)
	}
	if item.Timestamp != time.UnixMicro(timestamp).UTC().Format(time.RFC3339Nano) {
		t.Fatalf("timestamp=%q", item.Timestamp)
	}
	if item.Actions == nil || len(item.Actions) != 0 {
		t.Fatalf("history actions=%v", item.Actions)
	}

	encoded, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	var document map[string]any
	if err := json.Unmarshal(encoded, &document); err != nil {
		t.Fatal(err)
	}
	if _, ok := document["icon_path"]; ok {
		t.Fatal("icon path escaped the contract")
	}
	if _, ok := document["urls"]; ok {
		t.Fatal("URLs escaped the contract")
	}
	if document["dnd"] != true || document["unread_count"] != float64(3) {
		t.Fatalf("contract state=%v", document)
	}
	items := document["items"].([]any)
	itemDocument := items[0].(map[string]any)
	if _, ok := itemDocument["icon_path"]; ok {
		t.Fatal("item icon path escaped the contract")
	}
	if _, ok := itemDocument["urls"]; ok {
		t.Fatal("item URLs escaped the contract")
	}
	if actions, ok := itemDocument["actions"].([]any); !ok || actions == nil || len(actions) != 0 {
		t.Fatalf("encoded history actions=%v", itemDocument["actions"])
	}
}

func TestDunstSignalsInvalidateNotifications(t *testing.T) {
	bus := exportDunst(t, &mockDunst{history: []map[string]dbus.Variant{testNotification(1, time.Now().UnixMicro())}})
	reader, err := ConnectDunst(t.Context())
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	ctx, cancel := context.WithCancel(t.Context())
	defer cancel()
	changes := make(chan Change, 8)
	done := make(chan error, 1)
	go func() { done <- reader.Run(ctx, func(change Change) { changes <- change }) }()
	defer func() {
		cancel()
		select {
		case err := <-done:
			if err != nil {
				t.Error(err)
			}
		case <-time.After(time.Second):
			t.Error("Dunst subscriber did not stop")
		}
	}()

	if err := bus.Emit(dunstPath, dunstCommandInterface+".NotificationHistoryRemoved", uint32(1)); err != nil {
		t.Fatal(err)
	}
	awaitNotificationChange(t, changes)
	if err := bus.Emit(dunstPath, "org.freedesktop.DBus.Properties.PropertiesChanged", dunstCommandInterface, map[string]dbus.Variant{"waitingLength": dbus.MakeVariant(uint32(0))}, []string{}); err != nil {
		t.Fatal(err)
	}
	awaitNotificationChange(t, changes)
	if _, err := bus.ReleaseName(dunstName); err != nil {
		t.Fatal(err)
	}
	awaitNotificationChange(t, changes)
}

func TestDunstMissingOwnerIsUnavailable(t *testing.T) {
	address := privateBus(t)
	t.Setenv("DBUS_SESSION_BUS_ADDRESS", address)
	reader, err := ConnectDunst(t.Context())
	if err != nil {
		t.Fatal(err)
	}
	defer reader.Close()
	_, err = reader.Load(t.Context())
	var fault *Fault
	if !errors.As(err, &fault) || fault.Code != "backend_unavailable" {
		t.Fatalf("missing Dunst owner: %v", err)
	}
}

func TestDunstSignalBurstIsBounded(t *testing.T) {
	signals := &dunstSignals{ready: make(chan struct{}, 1)}
	for range 10000 {
		signals.DeliverSignal("", "", &dbus.Signal{Path: dunstPath, Name: dunstCommandInterface + ".NotificationHistoryRemoved"})
	}
	if len(signals.ready) != 1 || !signals.dirty.Load() {
		t.Fatal("Dunst signal burst was not coalesced")
	}
}

func awaitNotificationChange(t *testing.T, changes <-chan Change) {
	t.Helper()
	select {
	case change := <-changes:
		if change.Topic != Notifications || change.Refresh != Records|Lifecycle {
			t.Fatalf("notification change=%+v", change)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("no notification invalidation")
	}
}

// NUL and invalid UTF-8 cannot cross D-Bus STRING transport. Exercise those
// defensive decoder inputs at the sanitizer seam rather than in a wire reply.
func TestDunstSanitizerRejectsInvalidText(t *testing.T) {
	if got := sanitizeDunstText("app\x00\xffname", maxDunstTextBytes); got != "appname" {
		t.Fatalf("sanitized invalid text=%q", got)
	}
}
