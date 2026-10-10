package data

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

type Change struct {
	Topic   Topic
	Refresh Refresh
}

type ticker interface {
	Channel() <-chan time.Time
	Stop()
}
type realTicker struct{ *time.Ticker }

func (t realTicker) Channel() <-chan time.Time { return t.C }

type Server struct {
	Source    Source
	Interval  time.Duration
	newTicker func(time.Duration) ticker
}

type client struct {
	conn    net.Conn
	out     chan []byte
	cancel  context.CancelFunc
	pending atomic.Int64
	topics  map[Topic]bool
	metrics bool
}

type clientEvent struct {
	client  *client
	add     bool
	drop    bool
	request Request
	err     error
}

type topicState struct {
	needed Refresh
	busy   bool
	active bool
	cancel context.CancelFunc
}

type loaded struct {
	topic  Topic
	value  any
	active bool
	err    error
}

// Serve owns subscription state and the sole sampling ticker. Slow helpers run
// outside this loop; each topic has at most one load in flight and one dirty bitset.
func (s *Server) Serve(parent context.Context, listener net.Listener, changes <-chan Change) error {
	ctx, cancel := context.WithCancel(parent)
	var wg sync.WaitGroup
	clients := make(map[*client]bool)
	defer func() {
		cancel()
		listener.Close()
		for c := range clients {
			c.cancel()
			c.conn.Close()
		}
		wg.Wait()
	}()
	interval := s.Interval
	if interval <= 0 {
		interval = 2 * time.Second
	}
	newTicker := s.newTicker
	if newTicker == nil {
		newTicker = func(d time.Duration) ticker { return realTicker{time.NewTicker(d)} }
	}
	var timer ticker
	var ticks <-chan time.Time
	defer func() {
		if timer != nil {
			timer.Stop()
		}
	}()
	events := make(chan clientEvent, 32)
	loads := make(chan loaded, len(Topics))
	acceptErr := make(chan error, 1)
	states := map[Topic]*topicState{}
	for _, topic := range Topics {
		states[topic] = &topicState{}
	}
	var nonce [8]byte
	if _, err := rand.Read(nonce[:]); err != nil {
		return err
	}
	epoch := hex.EncodeToString(nonce[:])
	var sequence uint64

	wg.Add(1)
	go func() {
		defer wg.Done()
		for {
			conn, err := listener.Accept()
			if err != nil {
				select {
				case acceptErr <- err:
				case <-ctx.Done():
				}
				return
			}
			if err := sameUser(conn); err != nil {
				conn.Close()
				continue
			}
			c := &client{conn: conn, out: make(chan []byte, 8), topics: map[Topic]bool{}}
			select {
			case events <- clientEvent{client: c, add: true}:
			case <-ctx.Done():
				conn.Close()
				return
			}
		}
	}()

	drop := func(c *client) {
		if clients[c] {
			delete(clients, c)
			c.cancel()
			c.conn.Close()
		}
	}
	send := func(c *client, payload []byte) {
		if !clients[c] {
			return
		}
		if c.pending.Load()+int64(len(payload)) > MaxSnapshotBytes {
			drop(c)
			return
		}
		c.pending.Add(int64(len(payload)))
		select {
		case c.out <- payload:
		default:
			c.pending.Add(-int64(len(payload)))
			drop(c)
		}
	}
	interested := func(t Topic) bool {
		for c := range clients {
			if c.topics[t] {
				return true
			}
		}
		return false
	}
	wantsMetrics := func() bool {
		for c := range clients {
			if c.topics[AgentRuns] && c.metrics {
				return true
			}
		}
		return false
	}
	adjustTimer := func() {
		for topic, state := range states {
			if state.cancel != nil && !interested(topic) {
				state.cancel()
				state.cancel = nil
			}
		}
		needed := wantsMetrics() && states[AgentRuns].active
		if needed && timer == nil {
			timer = newTicker(interval)
			ticks = timer.Channel()
		}
		if !needed && timer != nil {
			timer.Stop()
			timer = nil
			ticks = nil
		}
	}
	start := func(topic Topic) {
		state := states[topic]
		if state.busy || state.needed == 0 || !interested(topic) {
			return
		}
		refresh := state.needed
		state.needed = 0
		state.busy = true
		metrics := wantsMetrics()
		loadCtx, done := context.WithTimeout(ctx, 5*time.Second)
		state.cancel = done
		wg.Add(1)
		go func() {
			defer wg.Done()
			defer done()
			value, active, err := s.Source.Load(loadCtx, topic, refresh, metrics)
			select {
			case loads <- loaded{topic, value, active, err}:
			case <-ctx.Done():
			}
		}()
	}
	request := func(topic Topic, refresh Refresh) { states[topic].needed |= refresh; start(topic) }

	for {
		select {
		case <-ctx.Done():
			return nil
		case err := <-acceptErr:
			if ctx.Err() != nil {
				return nil
			}
			return err
		case change, ok := <-changes:
			if !ok {
				changes = nil
				continue
			}
			if change.Topic.Valid() {
				request(change.Topic, change.Refresh)
			}
		case <-ticks:
			request(AgentRuns, Metrics)
		case result := <-loads:
			state := states[result.topic]
			state.busy = false
			state.cancel = nil
			if state.needed&(Records|Lifecycle) != 0 && interested(result.topic) {
				start(result.topic)
				continue
			}
			state.active = result.active
			adjustTimer()
			sequence++
			message := Snapshot{SchemaVersion: Version, Type: "snapshot", Topic: result.topic,
				Revision: fmt.Sprintf("%s-%d", epoch, sequence), ObservedAt: time.Now().UTC().Format(time.RFC3339Nano),
				Status: "ready", Data: result.value}
			if result.err != nil {
				message.Data = nil
				message.Status = "error"
				var fault *Fault
				if !errors.As(result.err, &fault) {
					fault = &Fault{"backend_error", "The backend could not be refreshed."}
				}
				message.Error = fault
				if fault.Code == "backend_unavailable" || fault.Code == "systemd_unavailable" {
					message.Status = "unavailable"
				}
			}
			payload, err := json.Marshal(message)
			if err != nil || len(payload)+1 > MaxSnapshotBytes {
				message.Data = nil
				message.Status = "error"
				message.Error = malformed()
				payload, _ = json.Marshal(message)
			}
			payload = append(payload, '\n')
			for c := range clients {
				if c.topics[result.topic] {
					send(c, payload)
				}
			}
			adjustTimer()
			start(result.topic)
		case e := <-events:
			c := e.client
			if e.add {
				if len(clients) >= 16 {
					c.conn.Close()
					continue
				}
				clientCtx, clientCancel := context.WithCancel(ctx)
				c.cancel = clientCancel
				clients[c] = true
				c.run(clientCtx, events, &wg)
				continue
			}
			if !clients[c] {
				continue
			}
			if e.drop {
				drop(c)
				adjustTimer()
				continue
			}
			result := Result{SchemaVersion: Version, Type: "result", RequestID: e.request.RequestID, Status: "ok"}
			if e.err != nil {
				result.RequestID = ""
				result.Status = "error"
				result.Error = &Fault{"invalid_request", "Expected a version 1 subscription request."}
			} else {
				for _, topic := range e.request.Topics {
					if e.request.Op == "subscribe" {
						c.topics[topic] = true
					} else {
						delete(c.topics, topic)
					}
					if topic == AgentRuns {
						c.metrics = e.request.Op == "subscribe" && e.request.Metrics
					}
				}
			}
			payload, _ := json.Marshal(result)
			send(c, append(payload, '\n'))
			if e.err == nil && e.request.Op == "subscribe" {
				for _, topic := range e.request.Topics {
					request(topic, Records|Lifecycle)
				}
			}
			adjustTimer()
		}
	}
}

func (c *client) run(ctx context.Context, events chan<- clientEvent, wg *sync.WaitGroup) {
	notifyDrop := func() {
		select {
		case events <- clientEvent{client: c, drop: true}:
		case <-ctx.Done():
		}
	}
	wg.Add(2)
	go func() {
		defer wg.Done()
		defer notifyDrop()
		scanner := bufio.NewScanner(c.conn)
		scanner.Buffer(make([]byte, 4096), MaxRequestBytes+1)
		for scanner.Scan() {
			r, err := DecodeRequest(scanner.Bytes())
			select {
			case events <- clientEvent{client: c, request: r, err: err}:
			case <-ctx.Done():
				return
			}
		}
	}()
	go func() {
		defer wg.Done()
		defer notifyDrop()
		for {
			select {
			case <-ctx.Done():
				return
			case payload := <-c.out:
				c.conn.SetWriteDeadline(time.Now().Add(3 * time.Second))
				_, err := c.conn.Write(payload)
				c.pending.Add(-int64(len(payload)))
				if err != nil {
					return
				}
			}
		}
	}()
}
