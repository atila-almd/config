# Plan 010: Finish personal appearance from login through desktop

Status: IMPLEMENTED IN SOURCE — guest acceptance pending. Dependencies: 007, 008, 009. Outcome: coherent appearance and
working graphical login with one selected authentication stack.

RustDesk runtime acceptance follows the owner's
[deferred sequencing](README.md#owner-directed-rustdesk-sequencing-2026-09-12)
and is not a completion gate for this plan. Other required acceptance remains.

## Scope

Original name/mark and semantic style across desktop/settings/lock/login;
keyboard and scale consistency. Replace Ly with the selected greetd graphical
login. Out: custom authentication/PAM engine, new hardware profiles, unrelated
app theming, OS recovery, backup destination setup, migration and benchmarks.

Grounding: Earlier planning left identity open and used Workstation
provisionally. The system definition owns Ly/session entry; the semantic
renderer owns desktop/lock colors.
Keep working keyring/portal integration; login assets cannot require private
home mounts or the Windows share.

## Selected production decisions

On 2026-09-11 the owner authorized direct production-stack definition without
a separate proof of concept. Select greetd with an original Quickshell greeter
hosted by an isolated instance of the already-declared Hyprland compositor.
The [research record](../login-lock-selection-research.md) records the tradeoffs;
these decisions define a design, not implementation or installed acceptance.
Status and dependencies remain unchanged.

The owner subsequently accepted using the existing compositor for this
delivery; the selected isolated Hyprland host remains unchanged. The later
host-development roadmap is owned by the
[deferred backlog entry](../../BACKLOG.md#deferred-greeter-compositor), not this
plan's scope or acceptance gates.

- greetd owns login authentication and session creation. Its native Quickshell
  adapter handles prompts and launch handoff; the greeter does not use
  authentication-only `PamContext` as a replacement for the login backend.
- The greeter and Plan 006's independent locker consume the same project-owned
  Qt Quick Controls presentation source with separate controllers. Use explicit
  palette/font/layout inputs, static assets and minimal updates. No donor QML,
  SDDM, ReGreet or Noctalia Greeter is selected.
- Run the greeter compositor under its own configuration and greeter account;
  never source the desktop configuration or launch desktop services there.
  After successful greetd handoff, terminate the greeter and its compositor,
  then launch the sole Workstation session through UWSM. Recreate the greeter
  on logout. Renderer workarounds remain process/profile scoped.
- Publish approved public palette/assets and the shared presentation during
  normal system provisioning. Keep the session's private theme release private;
  login cannot depend on a home/share mount. Matching public defaults are
  selected; automatically publishing every private theme change is not.
- Extend the same pinned RustDesk DRM/KMS implementation owned by Plan 006 to
  boot-greeter and logout/relogin acceptance. No floating nightly or separate
  remote-control stack is selected.
- Preserve the existing GNOME Keyring provider through the installed greetd
  PAM/session integration and verify it. Style the Plan 006 locker; do not add
  another locker for appearance matching.

No optional prototype gate is required. The implementation must still satisfy
the authentication, asset and installed checks below; remote checks follow the
deferred sequencing above. Future
asset-generation tools or dependencies outside this defined stack follow the
normal execution contract.

## Interfaces

- One greetd display-manager service launches sole `workstation.desktop` via
  the documented UWSM boundary; no legacy route. The greeter's isolated
  compositor is a pre-login host, not a second selectable desktop session.
- Semantic palette/public assets derive from existing owners.
  `services/desktop/identity/` holds public source assets; rebuild publishes to
  a system-readable location suitable for the chosen greeter. Runtime UI never
  edits `/usr` or depends on private home state for authentication screens.
- Layout settings remain 007's private schema. Reset/export affects only its
  keys; theme selection remains `workstation-theme` responsibility.
- Authentication/keyring stay upstream-owned; failed login/unlock/unavailable
  session must have visible actionable errors.

## Deliverables

- Public sources under `services/desktop/identity/`, semantic template/QML/default
  refinements in existing owners.
- Selected greeter configuration/public-asset provisioning under `services/`
  and `system.yaml`; delete replaced Ly declarations/config/obsolete checks.
- Login/lock validation, render fixtures and acceptance checklist updates.
- Desktop/root README, AGENTS, STATE/BACKLOG describing the sole shell, actual
  accepted VM behavior and explicit physical/assistive-technology limits.

## Checks

Validate assets/palette, QML and private fixture screenshots for all surfaces;
inspect keyboard focus, contrast and 200% text. Run complete source suite and
chosen greeter configuration checks. In blendOS test successful/failed login
and unlock, logout/relogin, keyring unlock, portal file selection/screen sharing,
login assets with home/share unavailable and TTY access. Confirm one display
manager/locker. Inspect matching login/lock/desktop pixels. No storage destruction
or performance collection belongs here.

For the deferred RustDesk acceptance after the rest of the stack is ready,
establish a fresh authenticated remote
connection at the boot greeter and complete login with remote input without a
local approval prompt. Verify reconnection after logout and the locked-session
journey recorded in Plan 006. Preserve authentication and lock coverage; a
running RustDesk service alone is not acceptance. See the
[login/lock compatibility research](../login-lock-selection-research.md).

## Done criteria

- Personal appearance is consistent across login, lock and desktop surfaces.
- Sole login/lock stack works; replaced config/dependencies deleted.
- Authentication/keyring/session and supported VM journeys pass, limits recorded.
- Source, QML, asset/render and relevant installed checks pass.
- Actual launch/login commands and acceptance documented; completion commit.

## Assumptions

- Without further visual direction, record a concrete Workstation wordmark/layout
  consistent with the semantic palette; no branding interview blocks execution.
  This is an executor assumption, not a claim of prior owner selection.
- TTY is an OS diagnostic route, not an old desktop fallback.
- Historical recovery/hardware tasks do not expand this shell project.
