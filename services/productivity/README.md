# Capture, media and reminders

The productivity helpers are on-demand commands. `Super+Ctrl+C` opens the
capture menu in the Workstation session; `Super+Shift+Space` opens all Workstation
tools. Existing screenshots, color picking and Elephant clipboard history retain
their bindings. On an account that has not rebuilt the declared packages yet,
complete the normal blendOS rebuild before using the affected helper.

## Record a region

```sh
workstation-record start
workstation-record start --audio
workstation-record status
workstation-record stop
```

Choose the region interactively. Audio is captured only with `--audio`.
Each recording gets a private directory under XDG Videos/Recordings, falling
back to `~/Videos/Recordings`. The helper owns only `blendos-recording.service`;
a second concurrent recording is refused. The transient user service stops with
`blendos-workstation-session.target`, or after two hours. Stop sends SIGINT
so the recorder can finalize its file, with a 30-second shutdown limit. Status
distinguishes a running recording from a stopped file with a readable video
stream. A crash or forced shutdown can leave an incomplete MP4.

Island's Recorder card displays the authoritative run state and offers Stop for
the currently observed run. If that run has been replaced, the request fails
rather than stopping a newer recording. Start remains an explicit
capture-menu/helper action; the shell adds no recorder-owned polling.
Island's Media card uses each player's native capabilities for separate Play,
Pause, Previous and Next actions. See the [Island guide](../desktop/ISLAND.md).

## OCR, QR and conversions

```sh
workstation-media ocr --copy
workstation-media ocr "$HOME/Pictures/document.png"
workstation-media qr-read --copy
workstation-media qr-create 'Text to share' "$HOME/Pictures/code.png"
workstation-media image input.png output.webp
workstation-media transcode input.wav output.ogg
workstation-media share "$HOME/Pictures/code.png"
```

OCR uses the English and Portuguese Tesseract data. OCR and QR reading accept
an existing image; without one they select a private screen region, then remove
the intermediate image. Successful decoding prints text. `--copy` explicitly
replaces the clipboard; failed, empty or cancelled OCR leaves it alone. QR
reading disables ZBar's D-Bus broadcast and never opens decoded URLs.

QR creation accepts `-` as its text argument to read stdin. Image outputs can
be PNG, JPEG or WebP. Transcoding outputs can be MP4, WebM, MP3, WAV or Ogg;
FFmpeg selects the format's normal defaults. Output directories must exist and
existing outputs, including symlinks, are refused. Private staging and a
non-overwriting rename keep partial conversions out of the destination path.

`share` copies PNG/JPEG image data, or a correctly escaped file URI for other
files, to the clipboard. Paste into the application you choose and perform its
send/attach action there. Application support for pasted file URIs varies; its
ordinary file picker remains available. The helper sends no files and starts
no network listener. Clipboard history remains Local State and may retain data
copied by these explicit actions.

## Reminders during this login

```sh
workstation-remind after 30m 'Take a break'
workstation-remind list
workstation-remind cancel ID
```

Creation prints the ID used for cancellation. Delays accept positive whole
seconds, minutes or hours, up to 24 hours. Both the transient timer and its
notification service belong to the active desktop target. Reminders are
cancelled when that session ends and do not survive reboot; no lingering or
persistent calendar policy is enabled. DND and the active notification daemon
control presentation. Message text is passed literally, without environment
expansion or shell evaluation. Cancellation targets only the requested reminder.

## Verification and troubleshooting

Run `bash scripts/check-repository.sh` for contract and fixture tests. Local
WSL checks also exercised real QR encode/decode, English/Portuguese OCR, WebP
conversion and audio transcoding. These checks require no graphical VM.

After the next rebuild, verify `tesseract --list-langs` includes `eng` and `por`.
In the graphical account test one region recording and clean stop, one region
OCR/QR capture, clipboard paste into the intended application, and a short
reminder. Use `journalctl --user -u blendos-recording.service` for a failed
recording. A service start alone does not establish successful capture.

The unmodified QR CLI is selected from upstream LGPL source evidence; Arch's
conflicting package license label remains a packaging metadata note. No upstream
code is vendored here.
