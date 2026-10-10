#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
mkdir -p "$temporary/bin"
cat > "$temporary/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DOCTOR_TEST_LOG"
case "$*" in
  *is-active*)
    [[ "${DOCTOR_TARGET:-workstation}" == workstation && "$*" == *blendos-workstation-session.target ]] && exit 0
    exit 3 ;;
  *show*) printf '%s\n' "${DOCTOR_UNIT_STATE:-active}" ;;
  *) exit 91 ;;
esac
EOF
cat > "$temporary/bin/tesseract" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == --list-langs ]] || exit 92
printf 'List of languages:\neng\n'
[[ "${DOCTOR_MISSING_POR:-no}" == yes ]] || printf 'por\n'
EOF
for command in hyprctl session-terminal workstation-project workstation-agent mise podman systemd-run workstation-capture workstation-record workstation-media workstation-remind wf-recorder grim slurp zbarimg qrencode ffmpeg magick wl-copy notify-send; do
  printf '#!/usr/bin/env bash\nexit 93\n' > "$temporary/bin/$command"
done
for command in lsblk findmnt df; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$temporary/bin/$command"
done
cat > "$temporary/bin/fwupdmgr" <<'EOF'
#!/usr/bin/env bash
printf 'firmware %s\n' "$*" >> "$DOCTOR_TEST_LOG"
[[ "$*" == get-devices || "$*" == get-updates ]] || exit 94
exit "${DOCTOR_FIRMWARE_STATUS:-2}"
EOF
chmod +x "$temporary/bin/"*
export PATH="$temporary/bin:$PATH" DOCTOR_TEST_LOG="$temporary/log"
bash "$repo_dir/bin/workstation-doctor" all > "$temporary/output"
grep -Fq 'provider tokens/quota: unavailable' "$temporary/output"
grep -Fq 'OCR language available: por' "$temporary/output"
: > "$temporary/log"
bash "$repo_dir/bin/workstation-doctor" desktop > "$temporary/output"
grep -Fq 'awww-daemon.service: active' "$temporary/output"
if DOCTOR_TARGET=none bash "$repo_dir/bin/workstation-doctor" desktop > "$temporary/output"; then exit 1; fi
grep -Fq 'required managed target is inactive' "$temporary/output"
if DOCTOR_UNIT_STATE=failed bash "$repo_dir/bin/workstation-doctor" desktop > "$temporary/output"; then exit 1; fi
grep -Fq 'workstation-shell.service: failed' "$temporary/output"
if DOCTOR_MISSING_POR=yes bash "$repo_dir/bin/workstation-doctor" productivity > "$temporary/output"; then exit 1; fi
grep -Fq 'OCR language unavailable: por' "$temporary/output"
if DOCTOR_FIRMWARE_STATUS=1 bash "$repo_dir/bin/workstation-doctor" firmware > "$temporary/output"; then exit 1; fi
grep -Fq 'firmware query unavailable: get-updates' "$temporary/output"
if grep -Eq 'start|stop|restart|enable|disable|reset-failed' "$temporary/log"; then
  printf 'doctor attempted a mutation\n' >&2; exit 1
fi
printf 'workstation-doctor tests passed\n'
