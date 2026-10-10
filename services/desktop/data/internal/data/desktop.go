package data

import (
	"context"
	"errors"
	"slices"
	"strings"
	"sync/atomic"

	"github.com/godbus/dbus/v5"
)

const networkName = "org.freedesktop.NetworkManager"
const networkPath = dbus.ObjectPath("/org/freedesktop/NetworkManager")
const loginName = "org.freedesktop.login1"
const loginPath = dbus.ObjectPath("/org/freedesktop/login1")
const propertiesInterface = "org.freedesktop.DBus.Properties"

// Signals only mark a topic dirty. The server performs a bounded read when that
// topic has subscribers, so closed control panels do no backend reads.
type desktopSignals struct {
	ready chan struct{}
	dirty atomic.Uint32
}

func (s *desktopSignals) DeliverSignal(_ string, _ string, signal *dbus.Signal) {
	var bits uint32
	if signal.Name == "org.freedesktop.DBus.NameOwnerChanged" {
		if len(signal.Body) != 3 {
			return
		}
		switch signal.Body[0] {
		case networkName:
			bits = 1
		case loginName:
			bits = 2
		}
	} else if strings.HasPrefix(string(signal.Path), string(networkPath)) {
		bits = 1
	} else if strings.HasPrefix(string(signal.Path), string(loginPath)) {
		bits = 2
	}
	if bits == 0 {
		return
	}
	s.dirty.Or(bits)
	select {
	case s.ready <- struct{}{}:
	default:
	}
}

type Desktop struct {
	conn    *dbus.Conn
	signals *desktopSignals
	systemd SystemdReader
}

func ConnectDesktop(ctx context.Context, systemd SystemdReader) (*Desktop, error) {
	signals := &desktopSignals{ready: make(chan struct{}, 1)}
	conn, err := dbus.ConnectSystemBus(dbus.WithContext(ctx), dbus.WithSignalHandler(signals))
	if err != nil {
		return nil, err
	}
	d := &Desktop{conn: conn, signals: signals, systemd: systemd}
	for _, name := range []string{networkName, loginName} {
		matches := [][]dbus.MatchOption{
			{dbus.WithMatchSender(name)},
			{dbus.WithMatchSender("org.freedesktop.DBus"), dbus.WithMatchInterface("org.freedesktop.DBus"), dbus.WithMatchMember("NameOwnerChanged"), dbus.WithMatchArg(0, name)},
		}
		for _, match := range matches {
			if err := conn.AddMatchSignalContext(ctx, match...); err != nil {
				conn.Close()
				return nil, err
			}
		}
	}
	return d, nil
}
func (d *Desktop) Close() error { return d.conn.Close() }
func (d *Desktop) Run(ctx context.Context, invalidate func(Change)) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-d.conn.Context().Done():
			return errors.New("system bus disconnected")
		case <-d.signals.ready:
			dirty := d.signals.dirty.Swap(0)
			if dirty&1 != 0 {
				invalidate(Change{Network, Lifecycle})
			}
			if dirty&2 != 0 {
				invalidate(Change{Power, Lifecycle})
			}
		}
	}
}
func (d *Desktop) Load(ctx context.Context, topic Topic) (any, error) {
	switch topic {
	case Network:
		return d.network(ctx)
	case Power:
		return d.power(ctx)
	}
	return nil, malformed()
}
func (d *Desktop) network(ctx context.Context) (any, error) {
	var devices []dbus.ObjectPath
	if err := d.conn.Object(networkName, networkPath).CallWithContext(ctx, networkName+".GetDevices", dbus.FlagNoAutoStart).Store(&devices); err != nil {
		return nil, &Fault{"backend_unavailable", "Wired network status is unavailable."}
	}
	if len(devices) > MaxItems {
		return nil, malformed()
	}
	result := NetworkData{Items: []NetworkItem{}}
	seen := map[dbus.ObjectPath]bool{}
	for _, path := range devices {
		if !path.IsValid() || !strings.HasPrefix(string(path), string(networkPath)+"/Devices/") || seen[path] {
			return nil, malformed()
		}
		seen[path] = true
		var props map[string]dbus.Variant
		if err := d.conn.Object(networkName, path).CallWithContext(ctx, propertiesInterface+".GetAll", dbus.FlagNoAutoStart, networkName+".Device").Store(&props); err != nil {
			if dbusError(err, "org.freedesktop.DBus.Error.UnknownObject") {
				continue
			}
			return nil, &Fault{"backend_unavailable", "Wired network status is unavailable."}
		}
		kind, ok := props["DeviceType"].Value().(uint32)
		if !ok {
			return nil, malformed()
		}
		if kind != 1 {
			continue
		}
		name, ok := props["Interface"].Value().(string)
		if !ok || len(name) == 0 || len(name) > 256 {
			return nil, malformed()
		}
		state, ok := props["State"].Value().(uint32)
		if !ok {
			return nil, malformed()
		}
		item := NetworkItem{ID: string(path), Interface: name, Label: name, State: "unavailable"}
		switch {
		case state == 100:
			item.State = "connected"
		case state >= 40 && state <= 90:
			item.State = "connecting"
		case state == 30 || state == 110:
			item.State = "disconnected"
		case state == 120:
			item.State = "failed"
		}
		var carrier dbus.Variant
		if err := d.conn.Object(networkName, path).CallWithContext(ctx, propertiesInterface+".Get", dbus.FlagNoAutoStart, networkName+".Device.Wired", "Carrier").Store(&carrier); err == nil {
			v, ok := carrier.Value().(bool)
			if !ok {
				return nil, malformed()
			}
			item.Carrier = &v
		} else if !dbusError(err, "org.freedesktop.DBus.Error.UnknownProperty") && !dbusError(err, "org.freedesktop.DBus.Error.UnknownObject") {
			return nil, &Fault{"backend_unavailable", "Wired network status is unavailable."}
		}
		result.Items = append(result.Items, item)
	}
	slices.SortFunc(result.Items, func(a, b NetworkItem) int { return compare(a.ID, b.ID) })
	return result, nil
}
func (d *Desktop) power(ctx context.Context) (any, error) {
	result := PowerData{Actions: []PowerAction{}}
	session, err := d.systemd.State(ctx, "blendos-workstation-session.target")
	if err != nil {
		return nil, &Fault{"backend_unavailable", "Session power capabilities are unavailable."}
	}
	for _, id := range []string{"lock", "suspend", "logout", "reboot", "shutdown"} {
		auth := "no"
		if id == "lock" || id == "logout" {
			if session.Active {
				auth = "yes"
			}
		} else {
			method := map[string]string{"suspend": "CanSuspend", "reboot": "CanReboot", "shutdown": "CanPowerOff"}[id]
			if err := d.conn.Object(loginName, loginPath).CallWithContext(ctx, loginName+".Manager."+method, dbus.FlagNoAutoStart).Store(&auth); err != nil {
				return nil, &Fault{"backend_unavailable", "Session power capabilities are unavailable."}
			}
			switch auth {
			case "yes", "challenge", "no", "na":
			default:
				return nil, malformed()
			}
		}
		result.Actions = append(result.Actions, PowerAction{ID: id, Available: auth == "yes" || auth == "challenge", Authorization: auth})
	}
	return result, nil
}
