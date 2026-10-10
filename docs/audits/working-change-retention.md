# Working-change retention audit (2026-10-10)

The original development checkout still has 19 tracked edits and 19 untracked
files. Of those, all 37 Managed Configuration/source changes are included in
`main`'s sanitized root commit `73877e8`; the one private access helper is
excluded as Local State. The original dirty checkout was deliberately preserved,
so its `git status` still shows those edits even though the fresh `main` snapshot
contains them. No original file changed after the first release audit snapshot.

The root snapshot already includes the current Island implementation, Plan 008
launcher, Plan 009 notification/OSD source and uncommitted Plan 010 greeter/shared
authentication work. Later release commits compose that work with the explicit
profiles/bootstrap and fix the notification test fixture. The current source
comparison found no omitted managed file. VM autostart and two user units moved
to `profiles/vm/`; fixture account names and personal documentation paths were
sanitized. These are deliberate release changes, not lost implementation.

| Working path | Original state | Retention |
| --- | --- | --- |
| `.config/quickshell/WorkstationShared/AuthForm.qml` | Tracked edit | Included byte-for-byte in sanitized root |
| `.config/quickshell/WorkstationShared/ThemedPane.qml` | Tracked edit | Included byte-for-byte in sanitized root |
| `.config/quickshell/workstation-lock/shell.qml` | Tracked edit | Included byte-for-byte in sanitized root |
| `AGENTS.md` | Tracked edit | Included byte-for-byte in sanitized root |
| `BACKLOG.md` | Tracked edit | Included byte-for-byte in sanitized root |
| `README.md` | Tracked edit | Included; personal evidence/home paths sanitized |
| `STATE.md` | Tracked edit | Included; personal evidence/home paths sanitized |
| `components.tsv` | Tracked edit | Included byte-for-byte in sanitized root |
| `docs/plans/010-desktop-identity-and-login.md` | Tracked edit | Included byte-for-byte in sanitized root |
| `docs/plans/README.md` | Tracked edit | Included byte-for-byte in sanitized root |
| `install.sh` | Tracked edit | Included byte-for-byte in sanitized root |
| `scripts/check-workstation-shell.sh` | Tracked edit | Included byte-for-byte in sanitized root |
| `scripts/test-installer-rerun.sh` | Tracked edit | Included byte-for-byte in sanitized root |
| `scripts/validate-user-session.sh` | Tracked edit | Included byte-for-byte in sanitized root |
| `services/desktop/API.md` | Tracked edit | Included byte-for-byte in sanitized root |
| `services/desktop/CHECKLIST.md` | Tracked edit | Included byte-for-byte in sanitized root |
| `services/desktop/README.md` | Tracked edit | Included byte-for-byte in sanitized root |
| `services/desktop/UPSTREAM.md` | Tracked edit | Included byte-for-byte in sanitized root |
| `system.yaml` | Tracked edit | Included byte-for-byte in sanitized root |
| `.priority1-access.sh` | Untracked source | Excluded: private machine-access Local State |
| `scripts/check-workstation-greeter-views.sh` | Untracked source | Included byte-for-byte in sanitized root |
| `scripts/fixtures/workstation-greeter/render-shell.qml` | Untracked source | Included; account fixture sanitized to test-user |
| `scripts/fixtures/workstation-greeter/tst_greeter.qml` | Untracked source | Included; account fixture sanitized to test-user |
| `scripts/fixtures/workstation-greeter/tst_view.qml` | Untracked source | Included; account fixture sanitized to test-user |
| `scripts/test-desktop-identity.sh` | Untracked source | Included byte-for-byte in sanitized root |
| `scripts/validate-desktop-identity.sh` | Untracked source | Included byte-for-byte in sanitized root |
| `services/desktop/identity/GreeterContract.js` | Untracked source | Included byte-for-byte in sanitized root |
| `services/desktop/identity/GreeterView.qml` | Untracked source | Included byte-for-byte in sanitized root |
| `services/desktop/identity/KeyboardState.qml` | Untracked source | Included byte-for-byte in sanitized root |
| `services/desktop/identity/README.md` | Untracked source | Included byte-for-byte in sanitized root |
| `services/desktop/identity/greeter-host` | Untracked source | Included byte-for-byte in sanitized root |
| `services/desktop/identity/greeter-ui` | Untracked source | Included byte-for-byte in sanitized root |
| `services/desktop/identity/hyprland-vm.lua` | Untracked source | Included byte-for-byte in sanitized root |
| `services/desktop/identity/hyprland.lua` | Untracked source | Included byte-for-byte in sanitized root |
| `services/desktop/identity/mark-dark.svg` | Untracked source | Included byte-for-byte in sanitized root |
| `services/desktop/identity/mark-light.svg` | Untracked source | Included byte-for-byte in sanitized root |
| `services/desktop/identity/public-theme.jq` | Untracked source | Included byte-for-byte in sanitized root |
| `services/desktop/identity/shell.qml` | Untracked source | Included byte-for-byte in sanitized root |
