package data

import (
	"context"
	"encoding/json"
	"regexp"
)

type DesktopReader interface {
	Load(context.Context, Topic) (any, error)
}
type NetworkItem struct {
	ID        string `json:"id"`
	Interface string `json:"interface"`
	Label     string `json:"label"`
	State     string `json:"state"`
	Carrier   *bool  `json:"carrier"`
}
type NetworkData struct {
	Items []NetworkItem `json:"items"`
}
type PowerAction struct {
	ID            string `json:"id"`
	Available     bool   `json:"available"`
	Authorization string `json:"authorization"`
}
type PowerData struct {
	Actions []PowerAction `json:"actions"`
}
type ThemeItem struct {
	ID    string `json:"id"`
	Label string `json:"label"`
	Mode  string `json:"mode"`
}
type WallpaperItem struct {
	ID    string `json:"id"`
	Label string `json:"label"`
}
type AppearanceData struct {
	ThemeID     *string                    `json:"theme_id"`
	ReleaseID   *string                    `json:"release_id"`
	WallpaperID *string                    `json:"wallpaper_id"`
	Themes      []ThemeItem                `json:"themes"`
	Wallpapers  []WallpaperItem            `json:"wallpapers"`
	Settings    map[string]json.RawMessage `json:"settings"`
}

var themeIdentifier = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,127}$`)
var wallpaperIdentifier = regexp.MustCompile(`^[0-9]{1,6}$`)
var recordingIdentifier = regexp.MustCompile(`^recording-[A-Za-z0-9]+$`)

func (a AppearanceData) valid() bool {
	if a.Themes == nil || a.Wallpapers == nil || len(a.Themes) > MaxItems || len(a.Wallpapers) > MaxItems {
		return false
	}
	if (a.ThemeID == nil) != (a.ReleaseID == nil) || a.ThemeID != nil && (!themeIdentifier.MatchString(*a.ThemeID) || !identifier.MatchString(*a.ReleaseID) || len(*a.ReleaseID) > 256) {
		return false
	}
	seen := map[string]bool{}
	for _, v := range a.Themes {
		if !themeIdentifier.MatchString(v.ID) || seen[v.ID] || len(v.Label) == 0 || len(v.Label) > 4096 || (v.Mode != "dark" && v.Mode != "light") {
			return false
		}
		seen[v.ID] = true
	}
	seen = map[string]bool{}
	for _, v := range a.Wallpapers {
		if !wallpaperIdentifier.MatchString(v.ID) || seen[v.ID] || len(v.Label) == 0 || len(v.Label) > 4096 {
			return false
		}
		seen[v.ID] = true
	}
	if a.WallpaperID != nil && !seen[*a.WallpaperID] {
		return false
	}
	if string(a.Settings["schema_version"]) != "1" {
		return false
	}
	for key, raw := range a.Settings {
		switch key {
		case "schema_version":
		case "density":
			var v string
			if json.Unmarshal(raw, &v) != nil || (v != "compact" && v != "spacious") {
				return false
			}
		case "text_scale":
			var v float64
			if json.Unmarshal(raw, &v) != nil || v < 1 || v > 2 {
				return false
			}
		default:
			return false
		}
	}
	return true
}

type RecordingData struct {
	RunID   *string `json:"run_id"`
	State   string  `json:"state"`
	CanStop bool    `json:"can_stop"`
}

func (r RecordingData) valid() bool {
	if r.RunID != nil && (!recordingIdentifier.MatchString(*r.RunID) || len(*r.RunID) > 128) {
		return false
	}
	if r.CanStop && (r.RunID == nil || (r.State != "recording" && r.State != "starting")) {
		return false
	}
	switch r.State {
	case "idle", "starting", "recording", "stopping", "completed", "failed", "unknown":
		return true
	}
	return false
}
