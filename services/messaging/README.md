# Messaging

The owner selected [ZapFast](https://github.com/crmne/zapfast), a native,
unofficial WhatsApp client, to send and receive WhatsApp messages. The common
System Definition declares the upstream-recommended AUR `zapfast-bin` package
for both Machine Profiles. Normal bootstrap/rebuild operations install and
update it; no source fork or compatibility shim is added. The package includes
the MIT application and third-party notices, including GPL-2.0 notification
sounds; retain those upstream licenses.

## Launch and pair

After rebuilding and deploying, search for ZapFast in the application launcher
(the package provides `zapfast.desktop`), select **Workstation > Tools > ZapFast**,
or run `zapfast` from a terminal. It runs on demand as a user application.
There is no managed autostart service. Keep its **Start at login** setting off
for this lifecycle; if **Keep running when the window closes** is enabled,
use the application's Quit action to exit completely.

On first launch, use WhatsApp on your phone: **Linked devices > Link a device**,
then scan the displayed QR code. Pairing is personal Local State; bootstrap
does not link an account. The [upstream setup guide](https://zapfast.rocks/getting-started/)
owns the alternative phone-number pairing flow.

## Local State and recovery

Default Linux locations are `~/.config/zapfast/` for settings/account lists,
`~/.local/state/zapfast/` for account sessions, archives and logs, and
`~/.cache/zapfast/` for media caches. Keep all of these outside the checkout;
accidental copies under the repository's corresponding directories are ignored.
No account settings or database templates are deployed by this repository.

The encrypted archive also needs its key from Secret Service, supplied here by
GNOME Keyring. If the keyring is locked, unlock it and use ZapFast's Retry action.
An archive-only backup cannot restore history: preserve the corresponding
keyring entry too. Follow the [upstream settings and files guide](https://zapfast.rocks/settings-and-files/)
for recovery and account removal.

## Acceptance still pending

The Capability status is **Planned** for both profiles. In the rebuilt blendOS
session, verify launcher and Tools entry activation, pairing, a sent/received
message, Dunst notifications, Island tray behavior, attachment portal selection,
keyring unlock after login, Quit/logout behavior, and Wayland display scaling.
Review appearance against workstation defaults; a custom semantic theme
integration is not implemented. These checks have not been accepted in the VM
or on physical hardware. Repository validation checks the package/menu contract
and generated status, without accessing an account or sending messages.
