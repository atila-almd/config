package data

import (
	"bufio"
	"context"
	"io"
	"math"
	"os/exec"
	"sync/atomic"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

const testUnitPath = dbus.ObjectPath("/org/freedesktop/systemd1/unit/blendos_2dagent_2ddemo_2escope")

type testManager struct{ subscriptions atomic.Int32 }

func (m *testManager) Subscribe() *dbus.Error { m.subscriptions.Add(1); return nil }
func (m *testManager) GetUnit(name string) (dbus.ObjectPath, *dbus.Error) {
	if name != "blendos-agent-demo.scope" {
		return "", dbus.NewError(systemdName+".NoSuchUnit", []any{"missing"})
	}
	return testUnitPath, nil
}

type testProperties struct{}

func (testProperties) Get(iface, name string) (dbus.Variant, *dbus.Error) {
	if iface == systemdName+".Unit" && name == "ActiveState" {
		return dbus.MakeVariant("active"), nil
	}
	return dbus.Variant{}, dbus.NewError("org.freedesktop.DBus.Error.UnknownProperty", nil)
}
func (testProperties) GetAll(iface string) (map[string]dbus.Variant, *dbus.Error) {
	if iface != systemdName+".Scope" {
		return nil, dbus.NewError("org.freedesktop.DBus.Error.UnknownInterface", nil)
	}
	return map[string]dbus.Variant{"CPUUsageNSec": dbus.MakeVariant(uint64(9007199254740993)), "MemoryCurrent": dbus.MakeVariant(uint64(math.MaxUint64))}, nil
}

func privateBus(t *testing.T) string {
	t.Helper()
	if _, err := exec.LookPath("dbus-daemon"); err != nil {
		t.Fatal("dbus-daemon is required for isolated D-Bus tests")
	}
	cmd := exec.Command("dbus-daemon", "--session", "--nofork", "--nopidfile", "--print-address=1")
	cmd.Stderr = io.Discard
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { cmd.Process.Kill(); cmd.Wait() })
	scanner := bufio.NewScanner(stdout)
	if !scanner.Scan() {
		t.Fatalf("private bus failed: %v", scanner.Err())
	}
	return scanner.Text()
}

func TestSystemdReadsExactMetricsAndPushesLifecycle(t *testing.T) {
	address := privateBus(t)
	t.Setenv("DBUS_SESSION_BUS_ADDRESS", address)
	bus, err := dbus.Connect(address)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { bus.Close() })
	manager := &testManager{}
	if err := bus.Export(manager, systemdPath, systemdName+".Manager"); err != nil {
		t.Fatal(err)
	}
	if err := bus.Export(testProperties{}, testUnitPath, "org.freedesktop.DBus.Properties"); err != nil {
		t.Fatal(err)
	}
	if _, err := bus.RequestName(systemdName, dbus.NameFlagDoNotQueue); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(t.Context())
	systemd, err := ConnectSystemd(ctx)
	if err != nil {
		cancel()
		t.Fatal(err)
	}
	defer systemd.Close()
	if manager.subscriptions.Load() != 1 {
		t.Fatal("systemd Manager.Subscribe was not called")
	}
	state, err := systemd.State(ctx, "blendos-agent-demo.scope")
	if err != nil || !state.Active {
		t.Fatalf("state: %+v %v", state, err)
	}
	cpu, memory, err := systemd.Usage(ctx, state.Path)
	if err != nil || cpu == nil || *cpu != "9007199254740993" || memory != nil {
		t.Fatalf("usage: %v %v %v", cpu, memory, err)
	}
	missing, err := systemd.State(ctx, "blendos-agent-missing.scope")
	if err != nil || missing.Active {
		t.Fatalf("missing scope: %+v %v", missing, err)
	}
	changes := make(chan Change, 16)
	done := make(chan error, 1)
	go func() { done <- systemd.Run(ctx, func(c Change) { changes <- c }) }()
	defer func() {
		cancel()
		select {
		case err := <-done:
			if err != nil {
				t.Error(err)
			}
		case <-time.After(time.Second):
			t.Error("D-Bus subscriber did not stop")
		}
	}()
	if err := bus.Emit(testUnitPath, "org.freedesktop.DBus.Properties.PropertiesChanged", systemdName+".Unit", map[string]dbus.Variant{"ActiveState": dbus.MakeVariant("inactive")}, []string{}); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, changes, AgentRuns)
	if _, err := bus.ReleaseName(systemdName); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, changes, AgentRuns)
	if _, err := systemd.State(ctx, "blendos-agent-demo.scope"); err == nil {
		t.Fatal("absent manager became a missing scope")
	}
	if _, err := bus.RequestName(systemdName, dbus.NameFlagDoNotQueue); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, changes, AgentRuns)
	if manager.subscriptions.Load() != 2 {
		t.Fatalf("manager restart was not resubscribed: %d", manager.subscriptions.Load())
	}
}

func TestBusInvalidationsAreBoundedAndFiltered(t *testing.T) {
	s := &busSignals{ready: make(chan struct{}, 1)}
	for range 10000 {
		s.DeliverSignal("", "", &dbus.Signal{Name: systemdName + ".Manager.UnitNew", Body: []any{"blendos-agent-demo.scope", testUnitPath}})
	}
	if len(s.ready) != 1 {
		t.Fatal("invalidations did not coalesce")
	}
	<-s.ready
	s.DeliverSignal("", "", &dbus.Signal{Name: systemdName + ".Manager.UnitNew", Body: []any{"unrelated.service", testUnitPath}})
	if len(s.ready) != 0 {
		t.Fatal("unrelated unit refreshed agent data")
	}
}
