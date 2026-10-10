package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"sync"
	"syscall"
	"time"

	"workstation.local/data/internal/data"
)

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	if err := run(ctx, os.Args[1:]); err != nil {
		// Do not log command argv, raw backend output or private record paths.
		fmt.Fprintln(os.Stderr, "workstation-data:", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, args []string) error {
	if len(args) == 1 && args[0] == "version" {
		fmt.Println("workstation-data protocol 1")
		return nil
	}
	if len(args) == 1 && (args[0] == "--help" || args[0] == "help") {
		fmt.Println("Usage: workstation-data serve | get TOPIC | watch TOPIC [TOPIC] [--metrics] | version")
		return nil
	}
	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeDir == "" {
		return errors.New("XDG_RUNTIME_DIR is required")
	}
	if len(args) == 1 && args[0] == "serve" {
		return serve(ctx, runtimeDir)
	}
	if len(args) < 2 || (args[0] != "get" && args[0] != "watch") {
		return errors.New("use --help for supported commands")
	}
	request := data.Request{SchemaVersion: data.Version, RequestID: "cli", Op: "subscribe"}
	for _, name := range args[1:] {
		if name == "--metrics" {
			request.Metrics = true
			continue
		}
		request.Topics = append(request.Topics, data.Topic(name))
	}
	if args[0] == "get" && len(request.Topics) != 1 {
		return errors.New("get requires one topic")
	}
	if args[0] == "get" && request.Topics[0] == data.AgentRuns {
		request.Metrics = true
	}
	encoded, _ := json.Marshal(request)
	if _, err := data.DecodeRequest(encoded); err != nil {
		return err
	}
	return readSocket(ctx, filepath.Join(runtimeDir, "blendos-workstation", "data.sock"), encoded, args[0] == "get")
}

func serve(parent context.Context, runtimeDir string) error {
	ctx, cancel := context.WithCancel(parent)
	defer cancel()
	listener, cleanup, err := data.Listen(runtimeDir)
	if err != nil {
		return err
	}
	defer cleanup()
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	state := envOr("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	projects := envOr("BLENDOS_WORKSTATION_PROJECT_STATE_HOME", filepath.Join(state, "blendos-workstation", "projects"))
	agents := envOr("BLENDOS_WORKSTATION_AGENT_STATE_HOME", filepath.Join(state, "blendos-workstation", "agents"))
	config := envOr("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	themeState := envOr("BLENDOS_WORKSTATION_THEME_STATE_HOME", state)
	themeConfig := envOr("BLENDOS_WORKSTATION_THEME_CONFIG_HOME", config)
	roots := []data.WatchRoot{
		{Path: filepath.Join(themeState, "blendos-workstation", "theme"), Topic: data.Appearance},
		{Path: filepath.Join(themeState, "blendos-workstation", "theme", "wallpapers"), Topic: data.Appearance},
		{Path: filepath.Join(state, "blendos-workstation", "shell"), Topic: data.Appearance},
		{Path: filepath.Join(state, "blendos-workstation", "recording"), Topic: data.Recording},
		{Path: filepath.Join(themeConfig, "blendos-workstation", "themes"), Topic: data.Appearance, Children: true},
	}
	if helper, err := exec.LookPath("workstation-theme"); err == nil {
		if resolved, err := filepath.EvalSymlinks(helper); err == nil {
			builtin := envOr("BLENDOS_WORKSTATION_THEME_BUILTIN_HOME", filepath.Join(filepath.Dir(filepath.Dir(resolved)), "themes"))
			roots = append(roots, data.WatchRoot{Path: builtin, Topic: data.Appearance, Children: true})
		}
	}
	watcher, err := data.NewWatcher(projects, agents, roots...)
	if err != nil {
		return errors.New("unable to watch workstation state")
	}
	defer watcher.Close()
	systemd, err := data.ConnectSystemd(ctx)
	if err != nil {
		return errors.New("unable to subscribe to the user systemd manager")
	}
	defer systemd.Close()
	helpers := &data.Helpers{ProjectCommand: "workstation-project", AgentCommand: "workstation-agent", ControlsCommand: "workstation-controls", RecordCommand: "workstation-record", Systemd: systemd}
	loops := []func(context.Context, func(data.Change)) error{watcher.Run, systemd.Run}
	// Transport loss, including initial connection failure, uses the existing
	// systemd service restart boundary. Missing backend names remain topic-local
	// unavailability and recover through NameOwnerChanged on a healthy bus.
	desktop, err := data.ConnectDesktop(ctx, systemd)
	if err != nil {
		return errors.New("unable to subscribe to the system bus")
	}
	defer desktop.Close()
	helpers.Desktop = desktop
	loops = append(loops, desktop.Run)
	notifications, err := data.ConnectDunst(ctx)
	if err != nil {
		return errors.New("unable to subscribe to desktop notifications")
	}
	defer notifications.Close()
	helpers.Notifications = notifications
	loops = append(loops, notifications.Run)
	server := &data.Server{Source: helpers}
	changes := make(chan data.Change, len(data.Topics))
	// Separate coalesced channels guarantee a filesystem burst cannot drop the
	// only systemd invalidation (or vice versa). Forwarders block, never discard it.
	var wg sync.WaitGroup
	errCh := make(chan error, len(loops))
	for _, loop := range loops {
		wg.Add(1)
		go func(loop func(context.Context, func(data.Change)) error) {
			defer wg.Done()
			err := loop(ctx, func(change data.Change) {
				select {
				case changes <- change:
				case <-ctx.Done():
				}
			})
			if err != nil {
				errCh <- err
				cancel()
			}
		}(loop)
	}
	err = server.Serve(ctx, listener, changes)
	cancel()
	wg.Wait()
	select {
	case <-errCh:
		return errors.New("an event subscription stopped; restart the service")
	default:
	}
	return err
}

func envOr(name, value string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return value
}

func readSocket(ctx context.Context, path string, request []byte, once bool) error {
	dialer := net.Dialer{Timeout: 3 * time.Second}
	conn, err := dialer.DialContext(ctx, "unix", path)
	if err != nil {
		return errors.New("data service is unavailable; start workstation-data.service")
	}
	defer conn.Close()
	stop := context.AfterFunc(ctx, func() { conn.Close() })
	defer stop()
	conn.SetWriteDeadline(time.Now().Add(3 * time.Second))
	if _, err := conn.Write(append(request, '\n')); err != nil {
		return err
	}
	if once {
		conn.SetReadDeadline(time.Now().Add(10 * time.Second))
	}
	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 4096), data.MaxSnapshotBytes)
	for scanner.Scan() {
		var header struct {
			Type   string `json:"type"`
			Status string `json:"status"`
		}
		if err := json.Unmarshal(scanner.Bytes(), &header); err != nil {
			return errors.New("invalid service response")
		}
		if header.Type == "result" {
			if header.Status != "ok" {
				return errors.New("subscription rejected")
			}
			continue
		}
		if header.Type != "snapshot" {
			return errors.New("unexpected service response")
		}
		if _, err := os.Stdout.Write(append(scanner.Bytes(), '\n')); err != nil {
			return err
		}
		if once {
			if header.Status != "ready" {
				return errors.New("topic is unavailable; see the JSON error")
			}
			return nil
		}
	}
	if ctx.Err() != nil {
		return nil
	}
	if scanner.Err() != nil {
		return errors.New("socket read failed")
	}
	return errors.New("data service disconnected")
}
