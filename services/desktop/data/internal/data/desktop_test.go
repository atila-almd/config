package data

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

const ethernetPath = dbus.ObjectPath("/org/freedesktop/NetworkManager/Devices/1")
const wifiPath = dbus.ObjectPath("/org/freedesktop/NetworkManager/Devices/2")

type mockNetwork struct{}

func (mockNetwork) GetDevices() ([]dbus.ObjectPath, *dbus.Error) {
	return []dbus.ObjectPath{ethernetPath, wifiPath}, nil
}

type mockDevice struct {
	kind  uint32
	state atomic.Uint32
	gone  atomic.Bool
}

func (d *mockDevice) GetAll(iface string) (map[string]dbus.Variant, *dbus.Error) {
	if d.gone.Load() {
		return nil, dbus.NewError("org.freedesktop.DBus.Error.UnknownObject", nil)
	}
	return map[string]dbus.Variant{"DeviceType": dbus.MakeVariant(d.kind), "Interface": dbus.MakeVariant("enp0s3"), "State": dbus.MakeVariant(d.state.Load())}, nil
}
func (d *mockDevice) Get(iface, name string) (dbus.Variant, *dbus.Error) {
	return dbus.MakeVariant(true), nil
}

type mockLogin struct{}

func (mockLogin) CanSuspend() (string, *dbus.Error)  { return "challenge", nil }
func (mockLogin) CanReboot() (string, *dbus.Error)   { return "yes", nil }
func (mockLogin) CanPowerOff() (string, *dbus.Error) { return "no", nil }

func TestDesktopReadsWiredFactsAndCapabilitiesAndRecoversOwners(t *testing.T) {
	address := privateBus(t)
	t.Setenv("DBUS_SYSTEM_BUS_ADDRESS", address)
	bus, err := dbus.Connect(address)
	if err != nil {
		t.Fatal(err)
	}
	defer bus.Close()
	wired := &mockDevice{kind: 1}
	wired.state.Store(100)
	for _, item := range []struct {
		value any
		path  dbus.ObjectPath
		iface string
	}{
		{mockNetwork{}, networkPath, networkName}, {wired, ethernetPath, propertiesInterface}, {&mockDevice{kind: 2}, wifiPath, propertiesInterface}, {mockLogin{}, loginPath, loginName + ".Manager"},
	} {
		if err := bus.Export(item.value, item.path, item.iface); err != nil {
			t.Fatal(err)
		}
	}
	for _, name := range []string{networkName, loginName} {
		if _, err := bus.RequestName(name, dbus.NameFlagDoNotQueue); err != nil {
			t.Fatal(err)
		}
	}
	ctx, cancel := context.WithCancel(t.Context())
	defer cancel()
	desktop, err := ConnectDesktop(ctx, &fakeSystemd{active: true})
	if err != nil {
		t.Fatal(err)
	}
	defer desktop.Close()
	value, err := desktop.Load(ctx, Network)
	if err != nil {
		t.Fatal(err)
	}
	items := value.(NetworkData).Items
	if len(items) != 1 || items[0].ID != string(ethernetPath) || items[0].State != "connected" || items[0].Carrier == nil || !*items[0].Carrier {
		t.Fatalf("wired-only native facts: %+v", items)
	}
	value, err = desktop.Load(ctx, Power)
	if err != nil {
		t.Fatal(err)
	}
	actions := value.(PowerData).Actions
	if len(actions) != 5 || !actions[0].Available || actions[1].Authorization != "challenge" || !actions[1].Available || actions[4].Available {
		t.Fatalf("capability facts: %+v", actions)
	}
	changes := make(chan Change, 32)
	done := make(chan error, 1)
	go func() { done <- desktop.Run(ctx, func(c Change) { changes <- c }) }()
	defer func() {
		cancel()
		select {
		case err := <-done:
			if err != nil {
				t.Error(err)
			}
		case <-time.After(time.Second):
			t.Error("desktop subscriber did not stop")
		}
	}()
	wired.state.Store(30)
	if err := bus.Emit(ethernetPath, propertiesInterface+".PropertiesChanged", networkName+".Device", map[string]dbus.Variant{"State": dbus.MakeVariant(uint32(30))}, []string{}); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, changes, Network)
	value, err = desktop.Load(ctx, Network)
	if err != nil || value.(NetworkData).Items[0].State != "disconnected" {
		t.Fatalf("state signal/read: %v %v", value, err)
	}
	if _, err := bus.ReleaseName(networkName); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, changes, Network)
	_, err = desktop.Load(ctx, Network)
	var fault *Fault
	if !errors.As(err, &fault) || fault.Code != "backend_unavailable" {
		t.Fatalf("owner loss became empty devices: %v", err)
	}
	if _, err := bus.RequestName(networkName, dbus.NameFlagDoNotQueue); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, changes, Network)
	if _, err := desktop.Load(ctx, Network); err != nil {
		t.Fatal("owner recovery", err)
	}
	wired.gone.Store(true)
	value, err = desktop.Load(ctx, Network)
	if err != nil || len(value.(NetworkData).Items) != 0 {
		t.Fatalf("hot-unplug became whole backend failure: %v %v", value, err)
	}
	if _, err := bus.ReleaseName(loginName); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, changes, Power)
	if _, err := desktop.Load(ctx, Power); err == nil {
		t.Fatal("missing login manager became available power actions")
	}
	if _, err := bus.RequestName(loginName, dbus.NameFlagDoNotQueue); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, changes, Power)
	if _, err := desktop.Load(ctx, Power); err != nil {
		t.Fatal(err)
	}
}

func TestDesktopSignalBurstKeepsBothTopics(t *testing.T) {
	s := &desktopSignals{ready: make(chan struct{}, 1)}
	for range 10000 {
		s.DeliverSignal("", "", &dbus.Signal{Path: ethernetPath, Name: propertiesInterface + ".PropertiesChanged"})
		s.DeliverSignal("", "", &dbus.Signal{Path: loginPath, Name: loginName + ".Manager.PrepareForSleep"})
	}
	if len(s.ready) != 1 || s.dirty.Swap(0) != 3 {
		t.Fatal("bounded signal coalescing lost one topic")
	}
}

func TestDesktopTransportFailureUsesServiceRestartBoundary(t *testing.T) {
	t.Setenv("DBUS_SYSTEM_BUS_ADDRESS", "unix:path=/nonexistent/workstation-test-system-bus")
	if desktop, err := ConnectDesktop(t.Context(), &fakeSystemd{}); err == nil {
		desktop.Close()
		t.Fatal("initial bus connection failure was hidden")
	}
	t.Setenv("DBUS_SYSTEM_BUS_ADDRESS", privateBus(t))
	desktop, err := ConnectDesktop(t.Context(), &fakeSystemd{})
	if err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { done <- desktop.Run(t.Context(), func(Change) {}) }()
	desktop.Close()
	select {
	case err := <-done:
		if err == nil {
			t.Fatal("disconnected bus did not request service restart")
		}
	case <-time.After(time.Second):
		t.Fatal("disconnected bus subscriber remained stuck")
	}
}

func TestControlsSourceRejectsMalformedSettingsAndRecording(t *testing.T) {
	for _, text := range []string{
		`{"schema_version":1,"data":{"theme_id":null,"release_id":null,"wallpaper_id":null,"themes":[],"wallpapers":[],"settings":{"schema_version":1,"private_path":"/secret"}}}`,
		`{"schema_version":1,"data":{"theme_id":null,"release_id":null,"wallpaper_id":null,"themes":[],"wallpapers":[],"settings":{"schema_version":1,"text_scale":3}}}`,
	} {
		h := &Helpers{ControlsCommand: helperFixture(t, text)}
		if _, _, err := h.Load(t.Context(), Appearance, Records, false); err == nil {
			t.Fatal("accepted malformed appearance")
		}
	}
	h := &Helpers{ControlsCommand: helperFixture(t, `{"schema_version":1,"error":{"code":"invalid_settings","message":"/private/should/not/leak"},"data":null}`)}
	_, _, err := h.Load(t.Context(), Appearance, Records, false)
	var fault *Fault
	if !errors.As(err, &fault) || fault.Code != "invalid_settings" || fault.Message == "/private/should/not/leak" {
		t.Fatal("lost sanitized settings error", err)
	}
	h.RecordCommand = helperFixture(t, `{"schema_version":1,"data":{"run_id":null,"state":"recording","can_stop":true}}`)
	if _, _, err := h.Load(t.Context(), Recording, Records, false); err == nil {
		t.Fatal("accepted stop without native run identity")
	}
	h.RecordCommand = helperFixture(t, `{"schema_version":1,"data":{"run_id":null,"state":"idle","can_stop":false}}`)
	if _, _, err := h.Load(t.Context(), Recording, Records, false); err != nil {
		t.Fatal(err)
	}
}
