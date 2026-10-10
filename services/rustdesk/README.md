# RustDesk unattended Wayland package

The workstation selects the distinct `rustdesk-unattended-wayland` native Arch
package for root-service DRM capture and remote display wake. The source commit
and vcpkg commit are owned by [PKGBUILD](PKGBUILD). The pinned upstream `build.py`
owns the libdrmtap commit and ABI gate. Credentials, pairing and RustDesk settings
remain Local State. The existing firewall policy still applies.

This is a project-owned packaging adapter, not a RustDesk fork. Upstream's
`build.py --drm` rejects its Arch packaging branch because it does not stage the
capture library or name the variant correctly. This recipe compiles the selected
features directly, stages the Flutter bundle as a native pacman archive, and
reuses upstream's library builder and artifact checks. No Debian package is
installed or converted. The existing root service loads the private library at
`/usr/lib/rustdesk/libdrmtap.so.0`; no privileged helper or capability grant is
added. The service starts at boot; its desktop launcher opens the client.

The Rust feature set is `flutter,drm,drm-wake,hwcodec,unix-file-copy-paste`, matching
the selected commit's `build-rustdesk-linux-drm` workflow. Hardware codec and
Unix file clipboard flags preserve that upstream build's behavior; they do not
change authentication or authorization defaults.
Display wake defaults on in this selected variant; an existing private
`enable-drm-display-wake=N` setting disables it. See the
[pinned wake implementation](https://github.com/rustdesk/rustdesk/blob/e82dd12350479b848630d1e500c2f6870609a884/src/ipc/drm.rs).
The native adapter explicitly passes Clang's builtin header directory to the
bridge generator on Arch and rejects fatal header diagnostics, which the older
generator can otherwise report without a failing exit status.
For the pinned libwebm dependency, Cargo's C++ compilation explicitly includes
the standard `cstdint` header that newer GCC no longer supplies indirectly.
This preserves both the locked dependency source and Arch's hardening flags.
For libdrmtap alone, the adapter normalizes Arch's preprocessor spelling of
`_FORTIFY_SOURCE` so the library's own explicit fortified-build flags take effect
without a conflicting macro definition. Wayland protocol files are declared
build prerequisites so native keyboard-shortcut inhibition is compiled in.

## Build and publish

Use an x86_64 Arch build environment as an ordinary user. Build prerequisites in
the recipe are installed by `makepkg --syncdeps` using that environment's sudo.
Install Rustup with its current stable toolchain and Rust 1.75.0 with rustfmt for
the upstream bridge generator. Provision separate Flutter SDKs 3.24.5 and 3.22.3
(bridge generation), and bootstrap a vcpkg checkout at the exact commit in the
recipe using its `bootstrap-vcpkg.sh -disableMetrics`. Use a full vcpkg clone;
the manifest resolves older port trees that a shallow checkout does not contain.
These toolchains and native
codec builds require substantial storage and network access; they are not
workstation runtime packages.

```bash
export FLUTTER_ROOT=/absolute/path/to/flutter-3.24.5
export BRIDGE_FLUTTER_ROOT=/absolute/path/to/flutter-3.22.3
export VCPKG_ROOT=/absolute/path/to/pinned-vcpkg
bash scripts/build-rustdesk-package.sh
bash scripts/rustdesk-package-repo.sh publish /absolute/path/to/rustdesk-unattended-wayland-1.5.0.dev.e82dd123-1-x86_64.pkg.tar.zst
bash scripts/rustdesk-package-repo.sh serve
```

Artifacts live outside the repository. If built elsewhere, copy the native
archive to the blendOS account and run `publish` there. That account needs
`repo-add` (Arch pacman), `bsdtar` and Python. Publication checks package metadata,
the compiled DRM/wake markers, the EGL library and the service/launcher payload.
The build additionally checks the upstream runtime ABI gate.

Keep the foreground server running during `sudo akshara update` in another
terminal. `system.yaml` declares the `workstation-local` pacman repository at
`http://127.0.0.1:18789`; the helper serves its actual database and package from
`${XDG_STATE_HOME:-$HOME/.local/state}/blendos-workstation/package-repo`.
Akshara's build chroot can access this loopback listener without access to host
home directories. Its standard package installation happens before service
enablement. A missing server or unpublished package prevents the rebuild; start
the server for every later rebuild too. Stop it with Ctrl+C after the rebuild.
The listener binds only to loopback. This local repository uses blendOS's
custom-repository signature policy; publish only the reviewed local build.

## Verification and acceptance

### Known capture failure — deferred by owner (2026-09-12)

With the installed `1.5.0.dev.e82dd123-1` package in the VirtualBox blendOS
guest, a fresh Windows connection authenticates while the workstation is locked
but remains on “Connected, waiting for image.” The DRM stream repeatedly closes
before producing a frame, even with the guest display awake, then attempts
portal capture. The software-rendering preference fixes GUI startup and survives
logout/login, but does not resolve this capture failure. The root cause is
unknown; remote image/input, unlock/reconnect and display wake remain unaccepted.

Temporary SSH ended at reboot and Guest Control is unavailable. Privileged
capture logs have not been inspected. Sanitized evidence is retained outside
the repository under
`%LOCALAPPDATA%\blendos-workstation\validation\plan006\`.

The owner's latest direction schedules diagnosis, remote tests, access
restoration and fixes after the remaining non-RustDesk workstation work is ready;
see the [execution sequencing](../../docs/plans/README.md#owner-directed-rustdesk-sequencing-2026-09-12).
Do not resume this work before that point. Deferral does not constitute
successful remote-access acceptance.

In VirtualBox, enable RustDesk's **Settings → General → Other → Always use
software rendering** preference. An administrator can set the same preference
before the first GUI launch, with `rustdesk.service` running:

```bash
sudo rustdesk --option allow-always-software-render Y
sudo rustdesk --option allow-always-software-render
```

The query should print `Y`. This is upstream Local State, not a session-wide
renderer variable. The pinned RustDesk startup removes `LIBGL_ALWAYS_SOFTWARE`
unless this preference is enabled; setting that environment variable alone does
not select software rendering. Changing a live process's configuration file
directly is insufficient because the service can overwrite it from cached state.
This preference fixes the observed VM GUI startup failure; it does not establish
DRM capture or remote lock compatibility. Physical machines keep their own
rendering preference.

[Pinned option handling](https://github.com/rustdesk/rustdesk/blob/e82dd12350479b848630d1e500c2f6870609a884/src/core_main.rs).

```bash
bash scripts/validate-rustdesk.sh
bash scripts/test-rustdesk-package.sh
bash scripts/validate-rustdesk.sh --package /absolute/path/to/package.pkg.tar.zst
# Only inside the rebuilt blendOS installation:
pacman -Qi rustdesk-unattended-wayland
systemctl status rustdesk.service
journalctl -b -u rustdesk.service
```

Repository and fixture checks do not establish a successful native build or live
remote access. Both remain required acceptance steps. In the graphical account,
configure unattended authentication privately, then verify remote viewing,
keyboard and pointer input while unlocked, while the selected lock surface is
active, and after the eleven-minute display-off transition. Confirm that the
remote connection wakes the display without unlocking it and that reconnect
works after disconnect and reboot. Test the NVIDIA machine and supported VM
separately; DRM capture compatibility is a live hardware question.

When updating, review RustDesk's DRM security documentation and changes to its
private-library ABI, root-service behavior, bridge workflow and Flutter build.
Advance the source pin/version and vcpkg pin deliberately, rebuild, inspect the
artifact and repeat installed acceptance before publishing. If upstream gains a
native Arch variant with equivalent features and checks, replace this recipe
and retain the component/service contract.

Sources: [blendOS system.yaml contract](https://blendos.co/reference/configs/system/),
[pinned upstream packaging](https://github.com/rustdesk/rustdesk/blob/e82dd12350479b848630d1e500c2f6870609a884/build.py),
[pinned bridge workflow](https://github.com/rustdesk/rustdesk/blob/e82dd12350479b848630d1e500c2f6870609a884/.github/workflows/bridge.yml).
