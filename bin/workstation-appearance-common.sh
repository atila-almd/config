#!/usr/bin/env bash
# Shared implementation for the theme and wallpaper helpers. Source this file;
# it is not a standalone command.

lock_appearance() {
  need_command flock
  ensure_state_root
  local inherited="${WORKSTATION_THEME_LOCK_FD:-}" lock_file="$theme_state_root/operation.lock"
  [[ ! -L "$lock_file" ]] || fail 'appearance operation lock must not be a symlink'
  if [[ "$inherited" =~ ^[0-9]+$ && "$lock_file" -ef "/proc/$$/fd/$inherited" ]]; then
    flock -n "$inherited" || exit 73
    return
  fi
  exec {WORKSTATION_THEME_LOCK_FD}>"$lock_file"
  chmod 0600 -- "$lock_file"
  flock -n "$WORKSTATION_THEME_LOCK_FD" || {
    printf '%s: another appearance operation is in progress\n' "$program_name" >&2
    exit 73
  }
  export WORKSTATION_THEME_LOCK_FD
}

resolved_or_empty() {
  readlink -f -- "$1" 2>/dev/null || true
}

assert_inside() {
  local candidate="$1"
  local root_real candidate_real
  root_real="$(resolved_or_empty "$theme_state_root")"
  candidate_real="$(resolved_or_empty "$candidate")"
  [[ -n "$root_real" && -n "$candidate_real" ]] || fail 'unable to resolve theme state path'
  case "$candidate_real" in
    "$root_real"|"$root_real"/*) ;;
    *) fail "path escapes theme state root: $candidate" ;;
  esac
}

render_wallpaper() {
  local source="$1"
  local output="$2"
  local extension renderer
  extension="${source##*.}"
  extension="${extension,,}"
  case "$extension" in
    svg)
      renderer="$(command -v resvg || true)"
      [[ -n "$renderer" ]] || fail 'resvg is required to render SVG wallpapers'
      "$renderer" "$source" "$output" || fail "resvg failed for wallpaper: $source"
      ;;
    png|jpg|jpeg|webp)
      if command -v magick >/dev/null 2>&1; then
        magick -- "$source" "$output" || fail "ImageMagick failed for wallpaper: $source"
      elif command -v convert >/dev/null 2>&1; then
        convert -- "$source" "$output" || fail "ImageMagick failed for wallpaper: $source"
      else
        fail 'ImageMagick is required to normalize raster wallpapers'
      fi
      ;;
    *)
      fail "unsupported wallpaper format: $source"
      ;;
  esac
  [[ -s "$output" ]] || fail "wallpaper renderer produced no output: $output"
  if command -v identify >/dev/null 2>&1; then
    [[ "$(identify -format '%m' -- "$output" 2>/dev/null || true)" == 'PNG' ]] ||
      fail "wallpaper renderer did not produce a PNG: $output"
  fi
}
