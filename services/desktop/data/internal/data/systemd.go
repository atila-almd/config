package data

import (
	"context"
	"errors"
	"math"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/godbus/dbus/v5"
)

const systemdName = "org.freedesktop.systemd1"
const systemdPath = dbus.ObjectPath("/org/freedesktop/systemd1")

// The handler coalesces invalidations instead of retaining an unbounded signal
// history. Clients need current state, not every intermediate transition.
type busSignals struct {
	ready         chan struct{}
	ownerChanged  atomic.Bool
	recordChanged atomic.Bool
	powerChanged  atomic.Bool
	agentChanged  atomic.Bool
}

func (s *busSignals) DeliverSignal(_ string, _ string, signal *dbus.Signal) {
	if signal.Name == "org.freedesktop.DBus.NameOwnerChanged" {
		if len(signal.Body) != 3 || signal.Body[0] != systemdName {
			return
		}
		s.ownerChanged.Store(true)
		s.agentChanged.Store(true)
		s.recordChanged.Store(true)
		s.powerChanged.Store(true)
	} else if signal.Name == systemdName+".Manager.UnitNew" || signal.Name == systemdName+".Manager.UnitRemoved" {
		if len(signal.Body) < 1 {
			return
		}
		name, ok := signal.Body[0].(string)
		if !ok {
			return
		}
		if name == "blendos-recording.service" {
			s.recordChanged.Store(true)
		} else if name == "blendos-workstation-session.target" {
			s.powerChanged.Store(true)
		} else if !unitID.MatchString(name) {
			return
		} else {
			s.agentChanged.Store(true)
		}
	} else if signal.Name == "org.freedesktop.DBus.Properties.PropertiesChanged" {
		if signal.Path == "/org/freedesktop/systemd1/unit/blendos_2drecording_2eservice" {
			s.recordChanged.Store(true)
		} else if signal.Path == "/org/freedesktop/systemd1/unit/blendos_2dworkstation_2dsession_2etarget" {
			s.powerChanged.Store(true)
		} else if !strings.HasPrefix(string(signal.Path), "/org/freedesktop/systemd1/unit/blendos_2dagent_2d") {
			return
		} else {
			s.agentChanged.Store(true)
		}
	} else {
		return
	}
	select {
	case s.ready <- struct{}{}:
	default:
	}
}

type Systemd struct {
	conn    *dbus.Conn
	signals *busSignals
}

func ConnectSystemd(ctx context.Context) (*Systemd, error) {
	signals := &busSignals{ready: make(chan struct{}, 1)}
	conn, err := dbus.ConnectSessionBus(dbus.WithContext(ctx), dbus.WithSignalHandler(signals))
	if err != nil {
		return nil, err
	}
	s := &Systemd{conn: conn, signals: signals}
	matches := [][]dbus.MatchOption{
		{dbus.WithMatchSender(systemdName), dbus.WithMatchInterface(systemdName + ".Manager"), dbus.WithMatchMember("UnitNew")},
		{dbus.WithMatchSender(systemdName), dbus.WithMatchInterface(systemdName + ".Manager"), dbus.WithMatchMember("UnitRemoved")},
		{dbus.WithMatchSender(systemdName), dbus.WithMatchInterface("org.freedesktop.DBus.Properties"), dbus.WithMatchMember("PropertiesChanged"), dbus.WithMatchPathNamespace("/org/freedesktop/systemd1/unit")},
		{dbus.WithMatchSender("org.freedesktop.DBus"), dbus.WithMatchInterface("org.freedesktop.DBus"), dbus.WithMatchMember("NameOwnerChanged"), dbus.WithMatchArg(0, systemdName)},
	}
	for _, options := range matches {
		if err := conn.AddMatchSignalContext(ctx, options...); err != nil {
			conn.Close()
			return nil, err
		}
	}
	if err := s.subscribe(ctx); err != nil {
		conn.Close()
		return nil, err
	}
	return s, nil
}

func (s *Systemd) subscribe(ctx context.Context) error {
	requestCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	err := s.conn.Object(systemdName, systemdPath).CallWithContext(requestCtx, systemdName+".Manager.Subscribe", dbus.FlagNoAutoStart).Err
	// Missing systemd is explicit unavailability when reading running scopes.
	// NameOwnerChanged will trigger subscription when the service appears.
	if dbusError(err, "org.freedesktop.DBus.Error.ServiceUnknown") || dbusError(err, "org.freedesktop.DBus.Error.NameHasNoOwner") {
		return nil
	}
	return err
}

func (s *Systemd) Run(ctx context.Context, invalidate func(Change)) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-s.conn.Context().Done():
			return errors.New("session bus disconnected")
		case <-s.signals.ready:
			if s.signals.ownerChanged.Swap(false) {
				if err := s.subscribe(ctx); err != nil {
					return err
				}
			}
			if s.signals.agentChanged.Swap(false) {
				invalidate(Change{AgentRuns, Lifecycle})
			}
			if s.signals.recordChanged.Swap(false) {
				invalidate(Change{Recording, Lifecycle})
			}
			if s.signals.powerChanged.Swap(false) {
				invalidate(Change{Power, Lifecycle})
			}
		}
	}
}

func (s *Systemd) Close() error { return s.conn.Close() }

func (s *Systemd) State(ctx context.Context, unit string) (UnitState, error) {
	var path dbus.ObjectPath
	err := s.conn.Object(systemdName, systemdPath).CallWithContext(ctx, systemdName+".Manager.GetUnit", dbus.FlagNoAutoStart, unit).Store(&path)
	if dbusError(err, systemdName+".NoSuchUnit") {
		return UnitState{}, nil
	}
	if err != nil {
		return UnitState{}, err
	}
	var value dbus.Variant
	err = s.conn.Object(systemdName, path).CallWithContext(ctx, "org.freedesktop.DBus.Properties.Get", dbus.FlagNoAutoStart, systemdName+".Unit", "ActiveState").Store(&value)
	if dbusError(err, "org.freedesktop.DBus.Error.UnknownObject") {
		return UnitState{}, nil
	}
	if err != nil {
		return UnitState{}, err
	}
	state, ok := value.Value().(string)
	if !ok {
		return UnitState{}, errors.New("invalid unit state")
	}
	return UnitState{Active: state == "active", Path: string(path)}, nil
}

func (s *Systemd) Usage(ctx context.Context, path string) (*string, *string, error) {
	var properties map[string]dbus.Variant
	err := s.conn.Object(systemdName, dbus.ObjectPath(path)).CallWithContext(ctx, "org.freedesktop.DBus.Properties.GetAll", dbus.FlagNoAutoStart, systemdName+".Scope").Store(&properties)
	if err != nil {
		return nil, nil, err
	}
	return variantCounter(properties["CPUUsageNSec"]), variantCounter(properties["MemoryCurrent"]), nil
}

func variantCounter(value dbus.Variant) *string {
	n, ok := value.Value().(uint64)
	if !ok || n == math.MaxUint64 {
		return nil
	}
	s := strconv.FormatUint(n, 10)
	return &s
}

func dbusError(err error, name string) bool {
	var value dbus.Error
	return errors.As(err, &value) && value.Name == name
}
