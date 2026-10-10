#!/usr/bin/env bash

set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_dir="$(cd -- "$script_dir/.." && pwd -P)"
helper="$repo_dir/bin/workstation-backup"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
fake_bin="$test_root/bin"
home="$test_root/home"
state="$test_root/state"
source_dir="$test_root/source with spaces"
repository="$test_root/repository"
password_file="$test_root/password"
exclude_file="$test_root/excludes"
log="$test_root/restic.log"
system_log="$test_root/systemctl.log"
mkdir -p -- "$fake_bin" "$home" "$source_dir/Documents" "$source_dir/Pictures"
printf 'secret-password\n' > "$password_file"
chmod 600 -- "$password_file"
printf '*.cache\n' > "$exclude_file"
printf 'document\n' > "$source_dir/Documents/file.txt"

cat > "$fake_bin/restic" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BACKUP_TEST_RESTIC_LOG"
case " $* " in
  *' init '*) mkdir -p -- "$BACKUP_TEST_REPOSITORY" ;;
  *' restore '*)
    target=''
    previous=''
    for argument in "$@"; do
      if [[ "$previous" == --target ]]; then target="$argument"; fi
      previous="$argument"
    done
    printf 'restored data\n' > "$target/restored.txt"
    ;;
esac
exit "${BACKUP_TEST_RESTIC_STATUS:-0}"
EOF
cat > "$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BACKUP_TEST_SYSTEM_LOG"
exit "${BACKUP_TEST_SYSTEM_STATUS:-0}"
EOF
chmod +x "$fake_bin/restic" "$fake_bin/systemctl" "$helper"

run_helper() {
  PATH="$fake_bin:$PATH" \
    HOME="$home" \
    XDG_STATE_HOME="$state" \
    BACKUP_TEST_RESTIC_LOG="$log" \
    BACKUP_TEST_REPOSITORY="$repository" \
    BACKUP_TEST_SYSTEM_LOG="$system_log" \
    BACKUP_TEST_SYSTEM_STATUS="${BACKUP_TEST_SYSTEM_STATUS:-0}" \
    "$helper" "$@"
}

assert_failure() {
  if "$@" >/dev/null 2>&1; then
    printf 'command unexpectedly succeeded: %s\n' "$*" >&2
    exit 1
  fi
}

assert_log_contains() {
  grep -Fq -- "$1" "$2" || {
    printf 'expected log entry missing: %s\n' "$1" >&2
    cat "$2" >&2
    exit 1
  }
}

assert_failure env PATH="$fake_bin:$PATH" HOME="$home" XDG_STATE_HOME="$state" \
  BACKUP_TEST_RESTIC_LOG="$log" BACKUP_TEST_REPOSITORY="$source_dir/inside" \
  "$helper" configure "$source_dir/inside" "$password_file" "$source_dir"

: > "$log"
run_helper configure --exclude-file "$exclude_file" "$repository" "$password_file" "$source_dir/Documents" "$source_dir/Pictures" > "$test_root/configure.out"
config="$state/blendos-workstation/backup/config.json"
status="$state/blendos-workstation/backup/status.json"
manifest="$state/blendos-workstation/backup/files-from-verbatim"
[[ "$(jq -r '.repository' -- "$config")" == "$repository" ]]
[[ "$(jq -r '.password_file' -- "$config")" == "$password_file" ]]
[[ "$(jq -r '.sources[0]' -- "$config")" == "$source_dir/Documents" ]]
[[ "$(jq -r '.exclude_file' -- "$config")" == "$exclude_file" ]]
[[ "$(jq -r '.timer_enabled' -- "$config")" == false ]]
[[ "$(stat -c '%a' -- "$config")" == 600 ]]
! grep -Fq -- 'secret-password' "$config"

repository_parent="$test_root/repository-parent"
mkdir -p -- "$repository_parent/source"
assert_failure env PATH="$fake_bin:$PATH" HOME="$home" XDG_STATE_HOME="$test_root/state-parent" \
  BACKUP_TEST_RESTIC_LOG="$log" BACKUP_TEST_REPOSITORY="$repository_parent" \
  "$helper" configure "$repository_parent" "$password_file" "$repository_parent/source"
nonempty_repository="$test_root/nonempty-repository"
mkdir -p -- "$nonempty_repository"
printf 'keep me\n' > "$nonempty_repository/existing-file"
env PATH="$fake_bin:$PATH" HOME="$home" XDG_STATE_HOME="$test_root/state-nonempty" \
  BACKUP_TEST_RESTIC_LOG="$log" BACKUP_TEST_REPOSITORY="$nonempty_repository" \
  "$helper" configure "$nonempty_repository" "$password_file" "$source_dir/Documents"
assert_failure env PATH="$fake_bin:$PATH" HOME="$home" XDG_STATE_HOME="$test_root/state-nonempty" \
  BACKUP_TEST_RESTIC_LOG="$log" BACKUP_TEST_REPOSITORY="$nonempty_repository" \
  "$helper" init
[[ -f "$nonempty_repository/existing-file" ]]

symlink_source="$test_root/source-link"
symlink_repository="$test_root/symlink-repository"
ln -s -- "$source_dir/Documents" "$symlink_source"
mkdir -p -- "$symlink_repository"
env PATH="$fake_bin:$PATH" HOME="$home" XDG_STATE_HOME="$test_root/state-symlink" \
  BACKUP_TEST_RESTIC_LOG="$log" BACKUP_TEST_REPOSITORY="$symlink_repository" \
  "$helper" configure "$symlink_repository" "$password_file" "$symlink_source"
rm -- "$symlink_source"
ln -s -- "$symlink_repository" "$symlink_source"
assert_failure env PATH="$fake_bin:$PATH" HOME="$home" XDG_STATE_HOME="$test_root/state-symlink" \
  BACKUP_TEST_RESTIC_LOG="$log" BACKUP_TEST_REPOSITORY="$symlink_repository" \
  "$helper" run
[[ "$(jq -r '.result' -- "$test_root/state-symlink/blendos-workstation/backup/status.json")" == failure ]]

run_helper init
assert_log_contains 'init' "$log"
[[ -d "$repository" ]]

# A configured repository path must not silently follow a newly installed link.
mv -- "$repository" "$test_root/original-repository"
ln -s -- "$source_dir/Documents" "$repository"
: > "$log"
assert_failure run_helper run
[[ ! -s "$log" ]]
[[ "$(jq -r .result "$status")" == failure ]]
rm -- "$repository"
mv -- "$test_root/original-repository" "$repository"

: > "$log"
run_helper run > "$test_root/run.out"
assert_log_contains '--files-from-verbatim' "$log"
assert_log_contains '--exclude-file' "$log"
assert_log_contains '--tag blendos-workstation --tag manual' "$log"
grep -Fxq -- "$source_dir/Documents" "$manifest"
grep -Fxq -- "$source_dir/Pictures" "$manifest"
[[ "$(jq -r '.operation' -- "$status")" == run ]]
[[ "$(jq -r '.result' -- "$status")" == success ]]
! grep -Fq -- 'secret-password' "$log"

BACKUP_TEST_RESTIC_STATUS=3 run_helper run failed-label >/dev/null 2>&1 || status_code=$?
[[ "${status_code:-0}" == 3 ]]
[[ "$(jq -r '.result' -- "$status")" == failure ]]

: > "$log"
run_helper run manual >/dev/null
run_helper snapshots
run_helper check
assert_log_contains 'snapshots --tag blendos-workstation' "$log"
assert_log_contains 'check' "$log"
[[ "$(jq -r '.last_successful_check' -- "$status")" != null ]]

rm -rf -- "$source_dir/Documents" "$source_dir/Pictures" "$exclude_file"
run_helper snapshots
run_helper check
restore_dir="$test_root/restore"
run_helper restore latest "$restore_dir"
[[ -f "$restore_dir/restored.txt" ]]
[[ "$(stat -c '%a' -- "$restore_dir")" == 700 ]]
[[ "$(jq -r '.last_successful_restore' -- "$status")" != null ]]
assert_failure env PATH="$fake_bin:$PATH" HOME="$home" XDG_STATE_HOME="$state" \
  BACKUP_TEST_RESTIC_LOG="$log" BACKUP_TEST_REPOSITORY="$repository" \
  "$helper" restore latest "$restore_dir"
assert_failure env PATH="$fake_bin:$PATH" HOME="$home" XDG_STATE_HOME="$state" \
  BACKUP_TEST_RESTIC_LOG="$log" BACKUP_TEST_REPOSITORY="$repository" \
  "$helper" restore latest "$source_dir/Documents/new-restore"

: > "$log"
run_helper retention-preview
assert_log_contains '--keep-daily 7 --keep-weekly 4 --keep-monthly 6 --dry-run' "$log"
! grep -Fq -- 'prune' "$log"

run_helper schedule on
assert_log_contains '--user enable --now blendos-backup.timer' "$system_log"
[[ "$(jq -r '.timer_enabled' -- "$config")" == true ]]
if BACKUP_TEST_SYSTEM_STATUS=17 run_helper schedule off >/dev/null 2>&1; then
  printf 'timer disable failure was reported as success\n' >&2
  exit 1
fi
[[ "$(jq -r '.timer_enabled' -- "$config")" == false ]]
run_helper schedule off
assert_log_contains '--user disable --now blendos-backup.timer' "$system_log"
[[ "$(jq -r '.timer_enabled' -- "$config")" == false ]]

mv -- "$repository" "$test_root/missing-repository"
assert_failure env PATH="$fake_bin:$PATH" HOME="$home" XDG_STATE_HOME="$state" \
  BACKUP_TEST_RESTIC_LOG="$log" BACKUP_TEST_REPOSITORY="$repository" \
  "$helper" run unavailable
[[ "$(jq -r '.operation' -- "$status")" == run ]]
[[ "$(jq -r '.result' -- "$status")" == failure ]]

grep -Fq 'UMask=0077' "$repo_dir/.config/systemd/user/blendos-backup.service"
grep -Fq 'OnCalendar=daily' "$repo_dir/.config/systemd/user/blendos-backup.timer"
grep -Fq 'Persistent=true' "$repo_dir/.config/systemd/user/blendos-backup.timer"
grep -Fq 'RandomizedDelaySec=15m' "$repo_dir/.config/systemd/user/blendos-backup.timer"

printf 'workstation-backup tests passed\n'
