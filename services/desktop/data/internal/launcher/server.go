package launcher

// Package launcher is the narrow JSON boundary used by the Quickshell
// launcher. Elephant remains the search/index authority; this package only
// translates its framed socket protocol and performs typed activation.

import (
	"bufio"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"
)

const (
	SchemaVersion    = 1
	MaxRequestBytes  = 64 * 1024
	MaxResponseBytes = 4 * 1024 * 1024
	MaxResults       = 50
	QueryTimeout     = 10 * time.Second
	ActionTimeout    = 10 * time.Second
)

type Request struct {
	SchemaVersion int      `json:"schema_version"`
	RequestID     string   `json:"request_id"`
	Op            string   `json:"op"`
	Query         string   `json:"query"`
	Kind          string   `json:"kind"`
	Limit         int      `json:"limit"`
	ExactSearch   bool     `json:"exactsearch"`
	Providers     []string `json:"providers"`
	Provider      string   `json:"provider"`
	Identifier    string   `json:"identifier"`
	Action        string   `json:"action"`
}

type Item struct {
	ID         string   `json:"id"`
	Kind       string   `json:"kind"`
	Label      string   `json:"label"`
	Detail     string   `json:"detail"`
	Icon       string   `json:"icon"`
	Available  bool     `json:"available"`
	Provider   string   `json:"provider"`
	Identifier string   `json:"identifier"`
	Actions    []string `json:"actions,omitempty"`
}

type Error struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

type Response struct {
	SchemaVersion int    `json:"schema_version"`
	Type          string `json:"type"`
	Op            string `json:"op"`
	RequestID     string `json:"request_id"`
	Status        string `json:"status"`
	Items         []Item `json:"items,omitempty"`
	Error         *Error `json:"error,omitempty"`
}

type elephantQuery struct {
	Providers   []string `json:"providers"`
	Query       string   `json:"query"`
	MaxResults  int32    `json:"maxresults"`
	ExactSearch bool     `json:"exactsearch"`
}

type elephantItem struct {
	Identifier string   `json:"identifier"`
	Text       string   `json:"text"`
	Subtext    string   `json:"subtext"`
	Icon       string   `json:"icon"`
	Provider   string   `json:"provider"`
	Actions    []string `json:"actions"`
}

type elephantResponse struct {
	Item *elephantItem `json:"item"`
}

type entryRef struct {
	Provider string
	Text     string
	Detail   string
}

type Server struct {
	RuntimeDir     string
	ElephantSocket string
	LauncherSocket string
}

func (s Server) socketPath() string {
	if s.LauncherSocket != "" {
		return s.LauncherSocket
	}
	return filepath.Join(s.RuntimeDir, "blendos-workstation", "launcher.sock")
}

func (s Server) elephantPath() string {
	if s.ElephantSocket != "" {
		return s.ElephantSocket
	}
	return filepath.Join(s.RuntimeDir, "elephant", "elephant.sock")
}

func (s Server) Serve(ctx context.Context) error {
	if s.RuntimeDir == "" {
		return errors.New("XDG_RUNTIME_DIR is required")
	}
	path := s.socketPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return errors.New("unable to create launcher runtime directory")
	}
	if err := removeSocket(path); err != nil {
		return err
	}
	listener, err := net.Listen("unix", path)
	if err != nil {
		return errors.New("unable to listen on launcher socket")
	}
	defer func() {
		_ = listener.Close()
		_ = os.Remove(path)
	}()
	if err := os.Chmod(path, 0o600); err != nil {
		return errors.New("unable to protect launcher socket")
	}

	go func() {
		<-ctx.Done()
		_ = listener.Close()
	}()
	for {
		conn, err := listener.Accept()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			continue
		}
		go s.handleClient(ctx, conn)
	}
}

func removeSocket(path string) error {
	info, err := os.Lstat(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return errors.New("unable to inspect launcher socket")
	}
	if info.Mode()&os.ModeSocket == 0 {
		return errors.New("launcher socket path is not a socket")
	}
	if err := os.Remove(path); err != nil {
		return errors.New("unable to replace launcher socket")
	}
	return nil
}

type client struct {
	server Server
	conn   net.Conn

	writeMu sync.Mutex
	mu      sync.Mutex
	cancel  context.CancelFunc
	serial  uint64
	refs    map[string]entryRef
}

func (s Server) handleClient(parent context.Context, conn net.Conn) {
	c := &client{server: s, conn: conn, refs: make(map[string]entryRef)}
	defer c.close()
	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 4096), MaxRequestBytes)
	for scanner.Scan() {
		var req Request
		if err := json.Unmarshal(scanner.Bytes(), &req); err != nil {
			_ = c.send(Response{Type: "result", Op: "query", RequestID: "", Status: "error", Error: &Error{Code: "invalid_request", Message: "Request JSON is invalid."}})
			continue
		}
		if req.SchemaVersion != SchemaVersion || req.RequestID == "" {
			_ = c.send(Response{Type: "result", Op: req.Op, RequestID: req.RequestID, Status: "error", Error: &Error{Code: "invalid_request", Message: "Request schema or ID is invalid."}})
			continue
		}
		switch req.Op {
		case "query":
			c.startQuery(parent, req)
		case "activate":
			c.activate(parent, req)
		default:
			_ = c.send(Response{Type: "result", Op: req.Op, RequestID: req.RequestID, Status: "error", Error: &Error{Code: "invalid_request", Message: "Unsupported launcher operation."}})
		}
	}
}

func (c *client) close() {
	c.mu.Lock()
	if c.cancel != nil {
		c.cancel()
		c.cancel = nil
	}
	c.mu.Unlock()
	_ = c.conn.Close()
}

func (c *client) startQuery(parent context.Context, req Request) {
	providers, err := normalizeProviders(req.Providers)
	if err != nil {
		_ = c.send(Response{Type: "result", Op: "query", RequestID: req.RequestID, Status: "error", Error: &Error{Code: "invalid_provider", Message: err.Error()}})
		return
	}
	query := req.Query
	if len(query) > 4096 {
		_ = c.send(Response{Type: "result", Op: "query", RequestID: req.RequestID, Status: "error", Error: &Error{Code: "query_too_large", Message: "Search text is too long."}})
		return
	}
	limit := req.Limit
	if limit <= 0 || limit > MaxResults {
		limit = MaxResults
	}

	c.mu.Lock()
	if c.cancel != nil {
		c.cancel()
	}
	ctx, cancel := context.WithCancel(parent)
	c.cancel = cancel
	c.serial++
	serial := c.serial
	c.mu.Unlock()

	go func() {
		defer func() {
			c.mu.Lock()
			if c.serial == serial {
				c.cancel = nil
			}
			c.mu.Unlock()
		}()
		items, err := c.query(ctx, providers, query, limit, req.ExactSearch)
		if ctx.Err() != nil || !c.current(serial) {
			return
		}
		if err != nil {
			_ = c.send(Response{Type: "result", Op: "query", RequestID: req.RequestID, Status: "error", Error: &Error{Code: errorCode(err), Message: publicError(err)}})
			return
		}
		_ = c.send(Response{Type: "result", Op: "query", RequestID: req.RequestID, Status: "ready", Items: items})
	}()
}

func (c *client) current(serial uint64) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.serial == serial
}

func (c *client) query(ctx context.Context, providers []string, query string, limit int, exact bool) ([]Item, error) {
	dialer := net.Dialer{Timeout: 2 * time.Second}
	conn, err := dialer.DialContext(ctx, "unix", c.server.elephantPath())
	if err != nil {
		return nil, errors.New("Elephant is unavailable; start elephant.service.")
	}
	defer conn.Close()
	stop := context.AfterFunc(ctx, func() { _ = conn.Close() })
	defer stop()

	payload, _ := json.Marshal(elephantQuery{Providers: providers, Query: query, MaxResults: int32(limit), ExactSearch: exact})
	if err := writeFrame(conn, 0, 1, payload); err != nil {
		return nil, errors.New("Elephant query could not be sent.")
	}
	reader := bufio.NewReader(conn)
	items := make([]Item, 0, limit)
	for {
		typeByte, payload, err := readFrame(reader)
		if err != nil {
			if ctx.Err() != nil {
				return nil, ctx.Err()
			}
			return nil, errors.New("Elephant returned an invalid response.")
		}
		switch typeByte {
		case 0, 1:
			var response elephantResponse
			if err := json.Unmarshal(payload, &response); err != nil || response.Item == nil {
				return nil, errors.New("Elephant returned an invalid item.")
			}
			if len(items) >= limit {
				continue
			}
			item := c.convertItem(*response.Item)
			items = append(items, item)
		case 254:
			continue
		case 255:
			return items, nil
		default:
			return nil, errors.New("Elephant returned an unsupported response.")
		}
	}
}

func (c *client) convertItem(raw elephantItem) Item {
	provider := raw.Provider
	if provider == "" {
		provider = "desktopapplications"
	}
	identifier := raw.Identifier
	// Calculator plugins may omit an identifier because their result is a
	// transient value. Keep that value addressable for the explicit copy action;
	// other providers fail closed when Elephant does not supply an ID.
	if identifier == "" && provider == "calc" {
		identifier = raw.Text
	}
	key := provider + "\x00" + identifier
	c.mu.Lock()
	c.refs[key] = entryRef{Provider: provider, Text: raw.Text, Detail: raw.Subtext}
	c.mu.Unlock()
	return Item{
		ID:         identifier,
		Kind:       provider,
		Label:      raw.Text,
		Detail:     raw.Subtext,
		Icon:       raw.Icon,
		Available:  identifier != "",
		Provider:   provider,
		Identifier: identifier,
		Actions:    append([]string(nil), raw.Actions...),
	}
}

func (c *client) activate(parent context.Context, req Request) {
	if req.Provider == "" || req.Identifier == "" {
		_ = c.send(Response{Type: "result", Op: "activate", RequestID: req.RequestID, Status: "error", Error: &Error{Code: "invalid_activation", Message: "A provider and item ID are required."}})
		return
	}
	ctx, cancel := context.WithTimeout(parent, ActionTimeout)
	defer cancel()
	err := c.runActivation(ctx, req)
	if err != nil {
		_ = c.send(Response{Type: "result", Op: "activate", RequestID: req.RequestID, Status: "error", Error: &Error{Code: errorCode(err), Message: publicError(err)}})
		return
	}
	_ = c.send(Response{Type: "result", Op: "activate", RequestID: req.RequestID, Status: "ok"})
}

var desktopID = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_.@+~-]*\.desktop(?::[A-Za-z0-9][A-Za-z0-9_.@+~-]*)?$`)

func (c *client) runActivation(ctx context.Context, req Request) error {
	switch req.Provider {
	case "desktopapplications":
		if req.Action != "" && req.Action != "start" && req.Action != "new_instance" {
			return errors.New("unsupported desktop action")
		}
		if !desktopID.MatchString(req.Identifier) {
			return errors.New("desktop entry ID is invalid")
		}
		return runCommand(ctx, "uwsm", "app", "--", req.Identifier)
	case "files":
		if req.Action != "" && req.Action != "open" && req.Action != "opendir" {
			return errors.New("unsupported file action")
		}
		c.mu.Lock()
		ref, ok := c.refs[req.Provider+"\x00"+req.Identifier]
		c.mu.Unlock()
		if !ok || !filepath.IsAbs(ref.Text) || strings.ContainsAny(ref.Text, "\r\n\x00") {
			return errors.New("file result is unavailable")
		}
		path := ref.Text
		if req.Action == "opendir" {
			path = filepath.Dir(path)
		}
		return runCommand(ctx, "systemd-run", "--user", "--collect", "--quiet", "--service-type=exec",
			"--property=PartOf=graphical-session.target", "--property=Requisite=graphical-session.target",
			"--property=After=graphical-session.target", "--", "xdg-open", path)
	case "calc":
		c.mu.Lock()
		ref, ok := c.refs[req.Provider+"\x00"+req.Identifier]
		c.mu.Unlock()
		if !ok {
			return errors.New("calculation result is unavailable")
		}
		value := ref.Detail
		if value == "" {
			value = ref.Text
		}
		if value == "" || strings.ContainsAny(value, "\r\n\x00") {
			return errors.New("calculation result is unavailable")
		}
		return runCommand(ctx, "wl-copy", value)
	default:
		return errors.New("this result has no safe activation")
	}
}

func runCommand(ctx context.Context, name string, args ...string) error {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Stdin = nil
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	if err := cmd.Run(); err != nil {
		if ctx.Err() != nil {
			return errors.New("activation timed out")
		}
		return errors.New("activation command failed")
	}
	return nil
}

func (c *client) send(response Response) error {
	response.SchemaVersion = SchemaVersion
	payload, err := json.Marshal(response)
	if err != nil || len(payload) > MaxResponseBytes {
		return errors.New("response could not be encoded")
	}
	payload = append(payload, '\n')
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	c.conn.SetWriteDeadline(time.Now().Add(2 * time.Second))
	_, err = c.conn.Write(payload)
	return err
}

func normalizeProviders(providers []string) ([]string, error) {
	if len(providers) == 0 {
		return nil, errors.New("at least one provider is required")
	}
	allowed := map[string]bool{
		"desktopapplications": true,
		"files":               true,
		"calc":                true,
		"websearch":           true,
		"clipboard":           true,
		"symbols":             true,
		"windows":             true,
		"runner":              true,
		"providerlist":        true,
	}
	seen := make(map[string]bool, len(providers))
	result := make([]string, 0, len(providers))
	for _, provider := range providers {
		provider = strings.TrimSpace(provider)
		if provider == "" || !allowed[provider] {
			return nil, fmt.Errorf("provider %q is not enabled", provider)
		}
		if !seen[provider] {
			seen[provider] = true
			result = append(result, provider)
		}
	}
	return result, nil
}

func writeFrame(w io.Writer, kind, format byte, payload []byte) error {
	if uint64(len(payload)) > MaxResponseBytes {
		return errors.New("frame is too large")
	}
	var header [6]byte
	header[0], header[1] = kind, format
	binary.BigEndian.PutUint32(header[2:], uint32(len(payload)))
	if _, err := w.Write(header[:]); err != nil {
		return err
	}
	_, err := w.Write(payload)
	return err
}

func readFrame(r *bufio.Reader) (byte, []byte, error) {
	var header [5]byte
	if _, err := io.ReadFull(r, header[:]); err != nil {
		return 0, nil, err
	}
	length := binary.BigEndian.Uint32(header[1:])
	if length > MaxResponseBytes {
		return 0, nil, errors.New("frame is too large")
	}
	payload := make([]byte, int(length))
	if _, err := io.ReadFull(r, payload); err != nil {
		return 0, nil, err
	}
	return header[0], payload, nil
}

func errorCode(err error) string {
	if errors.Is(err, context.DeadlineExceeded) {
		return "backend_timeout"
	}
	if strings.Contains(err.Error(), "unavailable") {
		return "backend_unavailable"
	}
	if strings.Contains(err.Error(), "unsupported") || strings.Contains(err.Error(), "safe activation") {
		return "unsupported_activation"
	}
	return "backend_error"
}

func publicError(err error) string {
	if err == nil {
		return ""
	}
	message := strings.TrimSpace(err.Error())
	message = strings.ReplaceAll(message, "\n", " ")
	message = strings.ReplaceAll(message, "\r", " ")
	if len(message) > 160 {
		message = message[:160]
	}
	return message
}
