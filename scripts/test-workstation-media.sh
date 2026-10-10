#!/usr/bin/env bash

set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

fake_bin="$test_dir/bin"
mkdir -p -- "$fake_bin" "$test_dir/input dir" "$test_dir/output dir"
input="$test_dir/input dir/input image.jpg"
printf 'input' > "$input"
log="$test_dir/log"
clipboard="$test_dir/clipboard"

cat > "$fake_bin/workstation-capture" <<'EOF'
#!/usr/bin/env bash
printf 'capture\n' >> "$MEDIA_TEST_LOG"
[[ "${MEDIA_CAPTURE_STATUS:-0}" == 0 ]] || exit "$MEDIA_CAPTURE_STATUS"
output="${@: -1}"
[[ "${MEDIA_CAPTURE_EMPTY:-0}" == 1 ]] || printf 'PNG' > "$output"
EOF
cat > "$fake_bin/tesseract" <<'EOF'
#!/usr/bin/env bash
printf 'tesseract\n' >> "$MEDIA_TEST_LOG"
printf '%s\n' "$@" >> "$MEDIA_TEST_LOG"
[[ "${MEDIA_TESSERACT_STATUS:-0}" == 0 ]] || exit "$MEDIA_TESSERACT_STATUS"
[[ "${MEDIA_TESSERACT_EMPTY:-0}" == 1 ]] && exit 0
printf 'Portuguese text\n'
EOF
cat > "$fake_bin/zbarimg" <<'EOF'
#!/usr/bin/env bash
printf 'zbarimg\n' >> "$MEDIA_TEST_LOG"
printf '%s\n' "$@" >> "$MEDIA_TEST_LOG"
[[ "${MEDIA_ZBAR_STATUS:-0}" == 0 ]] || exit "$MEDIA_ZBAR_STATUS"
printf 'https://example.test/qr\n'
EOF
cat > "$fake_bin/qrencode" <<'EOF'
#!/usr/bin/env bash
printf 'qrencode\n' >> "$MEDIA_TEST_LOG"
printf '%s\n' "$@" >> "$MEDIA_TEST_LOG"
output=''
while (($#)); do case "$1" in -o) output="$2"; shift 2 ;; *) shift ;; esac; done
printf 'PNG' > "$output"
EOF
cat > "$fake_bin/magick" <<'EOF'
#!/usr/bin/env bash
printf 'magick\n' >> "$MEDIA_TEST_LOG"
printf '%s\n' "$@" >> "$MEDIA_TEST_LOG"
printf 'IMAGE' > "${@: -1}"
EOF
cat > "$fake_bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
printf 'ffmpeg\n' >> "$MEDIA_TEST_LOG"
printf '%s\n' "$@" >> "$MEDIA_TEST_LOG"
printf 'MEDIA' > "${@: -1}"
EOF
cat > "$fake_bin/wl-copy" <<'EOF'
#!/usr/bin/env bash
printf 'wl-copy\n' >> "$MEDIA_TEST_LOG"
printf '%s\n' "$@" >> "$MEDIA_TEST_LOG"
cat > "$MEDIA_CLIPBOARD"
EOF
chmod u+x -- "$fake_bin"/*

run_media() (
  export HOME="$test_dir/home"
  export MEDIA_TEST_LOG="$log"
  export MEDIA_CLIPBOARD="$clipboard"
  export TMPDIR="$test_dir/tmp"
  mkdir -p -- "$TMPDIR"
  export PATH="$fake_bin:$repo_dir/bin:/usr/bin:/bin"
  "$repo_dir/bin/workstation-media" "$@"
)

: > "$log"
run_media ocr --copy >/dev/null
grep -Fxq 'capture' "$log" || fail 'OCR without an image did not use private region capture'
grep -Fxq -- '-l' "$log" || fail 'OCR did not pass a language option'
grep -Fxq -- 'eng+por' "$log" || fail 'OCR did not request English and Portuguese'
grep -Fxq 'Portuguese text' "$clipboard" || fail 'OCR --copy did not copy recognized text'
[[ -z "$(find "$test_dir/tmp" -mindepth 1 -print -quit)" ]] || fail 'OCR private temporary state leaked'

: > "$log"
run_media ocr >/dev/null || fail 'OCR without --copy returned failure after printing text'
grep -Fxq 'Portuguese text' "$clipboard" || fail 'OCR without --copy changed clipboard unexpectedly'

: > "$log"
run_media qr-read "$input" --copy >/dev/null
grep -Fxq 'zbarimg' "$log" || fail 'QR reader was not invoked'
grep -Fxq -- '--quiet' "$log" || fail 'QR reader omitted --quiet'
grep -Fxq -- '--raw' "$log" || fail 'QR reader omitted --raw'
grep -Fxq -- '--nodbus' "$log" || fail 'QR reader could broadcast decoded data'
grep -Fxq 'https://example.test/qr' "$clipboard" || fail 'QR --copy did not copy decoded value'
run_media qr-read "$input" >/dev/null || fail 'QR without --copy returned failure after printing text'

qr_output="$test_dir/output dir/qr result.png"
run_media qr-create 'text with spaces' "$qr_output" >/dev/null
[[ -s "$qr_output" ]] || fail 'QR output was not created'
if run_media qr-create again "$qr_output" >/dev/null 2>&1; then fail 'QR creation overwrote an existing output'; fi

converted="$test_dir/output dir/converted.webp"
run_media image "$input" "$converted" >/dev/null
[[ -s "$converted" ]] || fail 'image conversion output was not created'
if run_media image "$input" "$converted" >/dev/null 2>&1; then fail 'image conversion overwrote an existing output'; fi

ln -s -- "$test_dir/missing.png" "$test_dir/output dir/dangling.webp"
if run_media image "$input" "$test_dir/output dir/dangling.webp" >/dev/null 2>&1; then
  fail 'image conversion accepted a dangling output symlink'
fi

transcoded="$test_dir/output dir/audio.ogg"
run_media transcode "$input" "$transcoded" >/dev/null
[[ -s "$transcoded" ]] || fail 'transcode output was not created'
grep -Fxq 'ffmpeg' "$log" || fail 'ffmpeg was not invoked'
grep -Fxq -- '-n' "$log" || fail 'ffmpeg was not no-overwrite'

: > "$clipboard"
printf 'PNG bytes' > "$test_dir/output dir/share.png"
run_media share "$test_dir/output dir/share.png"
grep -Fxq -- '--type' "$log" || fail 'share did not set a clipboard MIME type'
grep -Fxq 'PNG bytes' "$clipboard" || fail 'share did not copy image bytes'

printf 'document' > "$test_dir/output dir/document.txt"
: > "$clipboard"
run_media share "$test_dir/output dir/document.txt"
grep -Fq 'file://' "$clipboard" || fail 'share did not copy a file URI list'
grep -Fq '%20' "$clipboard" || fail 'share did not URI-escape spaces'

if MEDIA_CAPTURE_EMPTY=1 run_media ocr >/dev/null 2>&1; then :; else fail 'cancelled OCR capture failed'; fi
[[ -z "$(find "$test_dir/tmp" -mindepth 1 -print -quit)" ]] || fail 'cancelled capture leaked private temporary state'
if MEDIA_TESSERACT_EMPTY=1 run_media ocr >/dev/null 2>&1; then
  fail 'empty OCR output was accepted'
fi
[[ -z "$(find "$test_dir/tmp" -mindepth 1 -print -quit)" ]] || fail 'failed OCR leaked private temporary state'

printf 'workstation-media tests passed\n'
