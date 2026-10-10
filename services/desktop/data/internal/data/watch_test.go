package data

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func watchFixture(t *testing.T, projects, agents string, desktop ...WatchRoot) <-chan Change {
	t.Helper()
	w, err := NewWatcher(projects, agents, desktop...)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(t.Context())
	ch := make(chan Change, 128)
	done := make(chan error, 1)
	go func() {
		done <- w.Run(ctx, func(c Change) {
			select {
			case ch <- c:
			case <-ctx.Done():
			}
		})
	}()
	t.Cleanup(func() {
		cancel()
		select {
		case err := <-done:
			if err != nil {
				t.Error(err)
			}
		case <-time.After(2 * time.Second):
			t.Error("watcher did not stop")
		}
		w.Close()
	})
	return ch
}

func awaitChange(t *testing.T, ch <-chan Change, topic Topic) {
	t.Helper()
	deadline := time.After(2 * time.Second)
	for {
		select {
		case c := <-ch:
			if c.Topic == topic {
				return
			}
		case <-deadline:
			t.Fatalf("no pushed change for %s", topic)
		}
	}
}

func TestWatcherFirstRegistrationAndAtomicReplacement(t *testing.T) {
	root := t.TempDir()
	projects, agents := filepath.Join(root, "projects"), filepath.Join(root, "agents")
	ch := watchFixture(t, projects, agents)
	if _, err := os.Stat(projects); !os.IsNotExist(err) {
		t.Fatal("watcher created state")
	}
	entries := filepath.Join(projects, "entries")
	if err := os.MkdirAll(entries, 0700); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, ch, Projects)
	file := filepath.Join(entries, "demo")
	if err := os.WriteFile(file, []byte("/project/one\n"), 0600); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, ch, Projects)
	for _, path := range []string{"/project/two\n", "/project/three\n"} {
		temporary := filepath.Join(entries, ".entry")
		if err := os.WriteFile(temporary, []byte(path), 0600); err != nil {
			t.Fatal(err)
		}
		if err := os.Rename(temporary, file); err != nil {
			t.Fatal(err)
		}
		awaitChange(t, ch, Projects)
	}
}

func TestWatcherNewRunAndDirectoryReplacement(t *testing.T) {
	root := t.TempDir()
	projects, agents := filepath.Join(root, "projects"), filepath.Join(root, "agents")
	if err := os.MkdirAll(filepath.Join(agents, "runs"), 0700); err != nil {
		t.Fatal(err)
	}
	ch := watchFixture(t, projects, agents)
	run := filepath.Join(agents, "runs", "run-demo")
	if err := os.Mkdir(run, 0700); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, ch, AgentRuns)
	if err := os.WriteFile(filepath.Join(run, "record.json"), []byte("{}"), 0600); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, ch, AgentRuns)
	if err := os.Rename(run, run+"-old"); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(run, 0700); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, ch, AgentRuns)
	if err := os.WriteFile(filepath.Join(run, "record.json"), []byte("{}"), 0600); err != nil {
		t.Fatal(err)
	}
	awaitChange(t, ch, AgentRuns)
}

func TestWatcherRejectsLinkedStateRoot(t *testing.T) {
	root := t.TempDir()
	link := filepath.Join(root, "projects")
	if err := os.Symlink(t.TempDir(), link); err != nil {
		t.Fatal(err)
	}
	if w, err := NewWatcher(link, filepath.Join(root, "agents")); err == nil {
		w.Close()
		t.Fatal("followed linked state")
	}
}
