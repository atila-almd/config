package data

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"

	"github.com/fsnotify/fsnotify"
)

type Watcher struct {
	watcher  *fsnotify.Watcher
	projects string
	agents   string
	desktop  []WatchRoot
}

type WatchRoot struct {
	Path     string
	Topic    Topic
	Children bool
}

func NewWatcher(projectRoot, agentRoot string, desktop ...WatchRoot) (*Watcher, error) {
	if !filepath.IsAbs(projectRoot) || !filepath.IsAbs(agentRoot) {
		return nil, errors.New("state roots must be absolute")
	}
	w, err := fsnotify.NewWatcher()
	if err != nil {
		return nil, err
	}
	for _, root := range desktop {
		if !filepath.IsAbs(root.Path) || !root.Topic.Valid() {
			w.Close()
			return nil, errors.New("invalid desktop state root")
		}
	}
	result := &Watcher{watcher: w, projects: filepath.Clean(projectRoot), agents: filepath.Clean(agentRoot), desktop: desktop}
	if err := result.sync(); err != nil {
		w.Close()
		return nil, err
	}
	return result, nil
}

func (w *Watcher) Close() error { return w.watcher.Close() }

// Watch only registry/run directories, never project contents. Watching an
// existing ancestor also catches the first registration without creating state.
func (w *Watcher) sync() error {
	wanted := map[string]bool{}
	current := map[string]bool{}
	for _, path := range w.watcher.WatchList() {
		current[path] = true
	}
	add := func(path string) error {
		for range 8 {
			parent, err := existingDirectory(path)
			if err != nil {
				return err
			}
			if !current[parent] {
				if err := w.watcher.Add(parent); err != nil {
					if os.IsNotExist(err) {
						continue
					}
					return err
				}
				current[parent] = true
			}
			wanted[parent] = true
			// The child may have appeared between lookup and watch installation.
			// Recheck after adding the ancestor, while subsequent changes are watched.
			now, err := existingDirectory(path)
			if err != nil {
				return err
			}
			if now == parent {
				return nil
			}
		}
		return errors.New("state directory changed repeatedly while installing watches")
	}
	for _, path := range []string{w.projects, filepath.Join(w.projects, "entries"), w.agents, filepath.Join(w.agents, "runs")} {
		if err := add(path); err != nil {
			return err
		}
	}
	runs := filepath.Join(w.agents, "runs")
	entries, err := os.ReadDir(runs)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() && runID.MatchString(entry.Name()) {
			if err := add(filepath.Join(runs, entry.Name())); err != nil {
				return err
			}
		}
	}
	for _, root := range w.desktop {
		if err := add(root.Path); err != nil {
			return err
		}
		if root.Children {
			entries, err := os.ReadDir(root.Path)
			if err != nil && !os.IsNotExist(err) {
				return err
			}
			for _, entry := range entries {
				if entry.IsDir() && themeIdentifier.MatchString(entry.Name()) {
					if err := add(filepath.Join(root.Path, entry.Name())); err != nil {
						return err
					}
				}
			}
		}
	}
	if len(wanted) > MaxItems*2+16 {
		return errors.New("too many agent run directories to watch")
	}
	// Add before removing so a parent replacement cannot introduce an unwatched gap.
	for path := range current {
		if !wanted[path] {
			if err := w.watcher.Remove(path); err != nil && !errors.Is(err, fsnotify.ErrNonExistentWatch) {
				return err
			}
		}
	}
	return nil
}

func existingDirectory(path string) (string, error) {
	for {
		info, err := os.Lstat(path)
		if err == nil {
			if !info.IsDir() {
				return "", errors.New("state directory must not be a file or symlink")
			}
			return path, nil
		}
		if !os.IsNotExist(err) {
			return "", err
		}
		parent := filepath.Dir(path)
		if parent == path {
			return "", err
		}
		path = parent
	}
}

func overlaps(path, root string) bool {
	return path == root || strings.HasPrefix(path, root+string(os.PathSeparator)) || strings.HasPrefix(root, path+string(os.PathSeparator))
}

func (w *Watcher) Run(ctx context.Context, invalidate func(Change)) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		case err, ok := <-w.watcher.Errors:
			if !ok {
				return errors.New("file watcher stopped")
			}
			if !errors.Is(err, fsnotify.ErrEventOverflow) {
				return err
			}
			if err := w.sync(); err != nil {
				return err
			}
			invalidate(Change{Projects, Records})
			invalidate(Change{AgentRuns, Records | Lifecycle})
			for _, root := range w.desktop {
				invalidate(Change{root.Topic, Records | Lifecycle})
			}
		case event, ok := <-w.watcher.Events:
			if !ok {
				return errors.New("file watcher stopped")
			}
			projects, agents := overlaps(event.Name, w.projects), overlaps(event.Name, w.agents)
			desktop := map[Topic]bool{}
			for _, root := range w.desktop {
				if overlaps(event.Name, root.Path) {
					desktop[root.Topic] = true
				}
			}
			if !projects && !agents && len(desktop) == 0 {
				continue
			}
			if err := w.sync(); err != nil {
				return err
			}
			if projects {
				invalidate(Change{Projects, Records})
			}
			if agents {
				invalidate(Change{AgentRuns, Records | Lifecycle})
			}
			for topic := range desktop {
				invalidate(Change{topic, Records | Lifecycle})
			}
		}
	}
}
