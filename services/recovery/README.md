# Backup, recovery and maintenance

The backup helper is opt in. It stores its configuration, generated source
manifest, lock, and operation status under:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/blendos-workstation/backup/
```

The JSON configuration and password file remain Local State. The password file
must be a regular file owned by the account with no group or other permission;
it is never sourced as shell code. Backend credentials remain caller-owned.

## Configure a repository

Choose a repository outside the backed-up sources and, for disaster recovery,
outside the source disk. The repository destination is deliberately not
selected by this repository. Configuration does not initialize the repository
or upload data:

Create a private password file once, or use an existing private file. This
example refuses to overwrite a previous password:

```sh
backup_state="${XDG_STATE_HOME:-$HOME/.local/state}/blendos-workstation/backup"
install -d -m 700 "$backup_state"
(umask 077; set -o noclobber; head -c 32 /dev/urandom | base64 > "$backup_state/restic-password")
```

Keep a separate recoverable copy of the password before relying on the backup.
An encrypted repository cannot supply its own lost password. Replace the
destination and sources below with the selected existing storage and data:

```sh
workstation-backup configure \
  /path/to/restic-repository \
  "$backup_state/restic-password" \
  "$HOME/Documents" \
  "$HOME/Pictures" \
  "$HOME/omarchy"
```

The source arguments must be absolute existing paths. The helper resolves them
with `realpath`, rejects newline paths, and refuses a local repository inside
any source, or containing a source. Root `/` is excluded from this file-backup
workflow. Changed symlink targets require explicit reconfiguration.
The repository checkout may resolve to the VirtualBox `vboxsf` working tree;
the guest disk does not protect the Windows-side data if the host share is
excluded or unavailable. Include resolved working-tree content deliberately;
Restic records symlinks rather than following them.

An optional user-maintained exclude file can be supplied explicitly:

```sh
workstation-backup configure --exclude-file "$HOME/.config/blendos-backup/excludes" \
  /path/to/restic-repository "$HOME/.local/state/blendos-workstation/backup/restic-password" \
  "$HOME/Documents" "$HOME/Pictures"
```

No default destination or generic source list is assumed. Missing destinations
are errors for `run`, `snapshots`, `check`, and `restore`; the helper does not
report a healthy skipped backup.

## Initialize and run explicitly

After reviewing the configuration and selecting the destination, initialize it
once and run a labelled checkpoint:

```sh
workstation-backup init
workstation-backup run manual
workstation-backup snapshots
workstation-backup check
workstation-backup status
```

`init` is the only command that initializes a repository. `run` creates a
private `--files-from-verbatim` manifest from the configured realpaths and
passes it, the optional exclude file, and `blendos-workstation` plus the label
tags to Restic. It uses a lock so concurrent configure, run, restore, and
maintenance operations fail closed. The status JSON is replaced atomically;
Restic failures, including incomplete-backup status 3, remain failures.
`run` without a label means `manual`. Initialization refuses an existing
nonempty destination; ordinary backup operations never initialize missing storage.

The helper never runs `delete` or `prune`. `retention-preview` only previews
the proposed policy of 7 daily, 4 weekly, and 6 monthly snapshots:

```sh
workstation-backup retention-preview
```

The preview uses `forget --dry-run`; it does not remove snapshots or repository
data. Any future retention change needs an explicit owner decision and a
verified restore first.

## Restore safely

Restore into a new absolute directory. The destination must not exist, must be
private mode `0700`, and must not be inside a source or local repository:

```sh
workstation-backup restore SNAPSHOT /tmp/workstation-restore-2026-09-07
```

Inspect the restored files before copying selected data into place. This helper
does not perform in-place restoration and does not delete files absent from a
snapshot. A successful restore is recorded as evidence for the timer opt-in.

For a broken managed configuration, use Git history and the resolved source
content first. Restic can restore selected Local State and personal data. It
cannot recreate a bootable blendOS system or replace Akshara's system rebuild.

## Enable or disable the daily timer

The unit is independent of the graphical desktop session and uses the user
manager. Installation does not enable it, and the timer remains disabled until
the owner explicitly enables it after a successful manual backup, repository
check, and private restore:

```sh
workstation-backup schedule on
workstation-backup schedule off
```

`schedule on` enables `blendos-backup.timer`; `schedule off` disables and
stops it. The timer is `daily`, `Persistent=true`, and has a 15-minute random
delay. It does not require lingering, so it runs only while the user manager
is available. It does not belong to `blendos-workstation-session.target` and does
not reboot, update, prune, or delete anything.

## Recovery boundaries

Restic protects only the explicit files selected in its manifest. It is the
file-history and disaster-recovery layer for documents, repositories, photos,
important Local State, and application data that the owner chooses. It does
not provide a root filesystem rollback, preserve a separate EFI/boot layout,
or guarantee a bootable previous blendOS generation.

The current VirtualBox guest has ext4 storage and a Windows-backed `vboxsf`
working tree. A guest disk snapshot does not contain the Windows directory, and
a Restic repository stored on that same guest disk is rewound with it. The
physical machine's filesystem and boot layout are still uninspected; inspect
them before proposing Btrfs/Snapper or live-USB rollback commands. For a
failed Akshara update, preserve current work, use the existing operator-led
update recovery process, then restore Managed Configuration and selected Local
State from Git/Restic after the machine is bootable.

The commands and limits in this guide are the current recovery contract. Git
history retains the earlier research and rejected alternatives.

## Source coverage and application consistency

Select documents, photographs, SSH keys, browser profiles, repositories with
uncommitted files, game saves, and required Local State explicitly. Include
`~/.var/app` for relevant Flatpak data and the actual persistent container
volumes or application exports. Inspect each application's storage location;
downloaded runtimes and game installations do not establish save-data coverage.
Pause stateful applications or use their native export operation when needed.
Restic reading live files does not establish database consistency.

Back up the resolved working tree, including its Git history, alongside the
home data you need. A home symlink to a Windows share is insufficient. Keep the
backup repository outside those sources. For SSD-loss recovery it must also
reside on independent storage; no cloud/NAS/off-device destination is selected
yet. The local disposable WSL restore test proves the command path, not that
this machine's real data is protected.

## Checkpointed system updates

Deploy the declared Restic package and helpers through the normal
[installation procedure](../../README.md#requirements-and-bootstrap).
Then configure a repository, perform a manual backup/check/restore and inspect
the restored content before relying on update checkpoints:

```sh
workstation-maintain preflight
workstation-maintain update
workstation-maintain status
# Reboot deliberately after a successful build.
workstation-maintain verify-update
```

Before `update`, [start the local RustDesk package server](../rustdesk/README.md#build-and-publish)
and keep it running throughout the Akshara rebuild.

`preflight` requires blendOS and `/system.yaml` resolving to this account’s
rendered machine Local State, matching this checkout and its selected profile. It
shows available storage and updater service state, verifies that the configured
loopback package repository serves `workstation-local.db`, and checks the
configured backup repository. `update` creates a `pre-update` file backup before
invoking `sudo akshara update`. A missing package server or failed/incomplete
backup prevents that invocation.
Akshara still owns building and activation; the helper never schedules updates
or reboots, changes Akshara's units, or promises sufficient staging space from
`df` output alone. Direct Akshara invocations bypass this helper's checkpoints.
An existing enabled updater service also bypasses them; inspect the preflight
service state when deciding the machine's update policy.

Maintenance tracking is private JSON under
`${XDG_STATE_HOME:-$HOME/.local/state}/blendos-workstation/maintenance/`.
It distinguishes building, build failure and awaiting reboot. Verification
requires a different boot ID, installed component/session checks, healthy
desktop services and no failed system/user units. Only then does it create a
`post-update` file backup and archive the pending record as verified. These
checks do not replace interactive or physical-device acceptance.

On failure, inspect `workstation-maintain status`, build output and the
relevant failed unit. A pending record blocks another helper-driven update.
After investigating a failed/interrupted build or an update performed outside
the helper, `workstation-maintain archive-record` preserves the tracking record
in a new private archive and clears that block. It does not undo a build or
alter any system filesystem.

## Recover a configuration or an unbootable system

For one broken managed file, preserve current work and inspect the chosen
revision before restoring that file. For example, from the checkout:

```sh
workstation-backup run pre-config-restore
git log --oneline -- .config/hypr/hyprland.lua
git diff HEAD -- .config/hypr/hyprland.lua
revision=KNOWN_GOOD_COMMIT
git show "$revision:.config/hypr/hyprland.lua"
git restore --source="$revision" --worktree -- .config/hypr/hyprland.lua
```

The final command replaces only that working-tree file. Deploy managed files
using the installation guide and run the owning validator. Installer-displaced
files use the [installer's timestamped backups](../../README.md#local-state-and-reruns);
those backups are not OS snapshots. A deleted personal file can be recovered
with `workstation-backup restore` even after its original source path is gone.

For the observed ext4 VM, a verified powered-off VirtualBox disk snapshot can
provide whole-guest rollback. It also rewinds newer guest personal data, so
preserve that data outside the rollback boundary first. The Windows working
tree remains outside the VM snapshot. Snapshot-compatible disk modes and a
restore rehearsal still require acceptance; this change creates no VM snapshot.

There is no verified retained boot-generation contract here. For an unbootable
machine, boot recovery media, identify the actual storage using `lsblk -f` and
`findmnt`, and preserve current personal files before any restore. Recover from
a previously verified matched disk/boot snapshot if available. Otherwise
reinstall blendOS onto the chosen recovery storage, restore the repository and
credential custody, apply the System Definition through the installation guide,
then restore selected personal/application data into a new directory for review.
Exact encrypted-device, mount and boot-repair commands depend on the physical
layout, which has not been inspected. Do not apply guessed Btrfs subvolume
switches or rely on Akshara's temporary `/.old.*` directories.

## Customization, runtime updates and hardware inspection

Edit Managed Configuration in the owning source paths listed in
[AGENTS.md](../../AGENTS.md#sources-of-truth); generated theme files and private
GUI settings remain Local State. Take `workstation-backup run pre-config`
before major changes and run the relevant repository checks afterward. Keep
credentials and machine-specific paths out of Git.

The workstation Mise default now pins Node 24.20.0 LTS; the official release
index and download checksum were checked, and Portless 0.15.6 loaded under that
runtime in WSL. Projects can declare their own reviewed Mise versions. To
update the workstation default, review the upstream release, change
`.config/mise/config.toml`, run the shell/container and Portless checks, then
use the normal installer runtime setup. OS/AUR repositories still roll: a
previous Git commit does not reproduce the exact previous OS binaries.
Flatpak applications, container images and project runtimes need their own
reviewed update operations. [Node release policy](https://nodejs.org/en/about/previous-releases)

```sh
workstation-doctor storage
workstation-doctor firmware
```

Storage diagnosis displays filesystems and space. Firmware diagnosis uses
`fwupdmgr get-devices` and `get-updates` against existing metadata; it never
refreshes metadata, installs firmware, changes BIOS settings or reboots. An
upstream exit status of 2 means the query succeeded with no actions available.
Physical hardware results cannot be inferred from VirtualBox devices.
[fwupdmgr interface](https://fwupd.github.io/libfwupdplugin/fwupdmgr.html)

## Verification still required on the target

Repository checks cover configuration, failure propagation, fresh restore
targets, timer opt-in and update ordering. Real WSL Restic checks backed up
fixture files, deleted the source, restored matching contents and ran a
repository check and retention preview. No real backup destination was used.

After deployment, run `bash scripts/validate-maintenance.sh --installed`,
verify a representative backup and restore on the chosen destination, then
test the timer through a new login. Rehearse an update and recovery on the VM
before relying on whole-system recovery. Off-device restoration onto replacement
storage and the physical machine's disk/boot layout remain unresolved.
