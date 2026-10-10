# Project development workflow

`workstation-project` keeps a small registry of projects that the owner
explicitly names. The registry is Local State under
`${XDG_STATE_HOME:-$HOME/.local/state}/blendos-workstation/projects/`; it is
never written into a project or this repository. A project path is resolved
when it is added and must still name a directory when it is opened.

The helper does not search for repositories, inspect project files, download
tools, read credentials, or invent an agent command. The caller supplies the
directory and the complete command argv. Arguments are passed directly to the
terminal process, so shell syntax in an argument remains data.

## Register and select projects

Use a stable ID made of letters, numbers, `.`, `_`, or `-`, beginning with a
letter or number. The directory must already exist:

```sh
workstation-project add workstation "$HOME/Projects/workstation"
workstation-project add api "$HOME/Projects/api service"
workstation-project list
workstation-project choose workstation
```

Project `list` and agent `list`/`status` emit versioned JSON. Agent `list` reads
stored facts; `status` also observes the live scope. The shared desktop adapter
adds event-driven lifecycle and measured resource updates. See the
[data API](../desktop/API.md) for schemas, limits and subscription commands.
Island's Projects card opens the project/agent workflow. It shares this registry
and launches through this helper; shell-specific commands and acceptance checks
are owned by the [Island guide](../desktop/ISLAND.md).

`choose` without an ID presents the registered IDs through Walker. Escape or
an empty choice cancels without changing the selected project. A successful
choice saves the selection and opens its default terminal. The desktop project
binding uses this operation. Remove a registration with
`workstation-project remove ID`; removing the selected project clears the
selection.

The selected project can be opened explicitly from a terminal or Neovim:

```sh
workstation-project open
workstation-project open api
workstation-project open api editor
```

Every terminal window is launched through `session-terminal`. It passes
Ghostty `--working-directory=... -e ...`, retaining the workstation's
explicit `vm` Machine Profile rendering fallback. Ghostty documents the
[`working-directory` option and `-e` command execution](https://ghostty.org/docs/config/reference#working-directory)
in its upstream option reference. The default terminal uses `$SHELL`; the
editor mode requires `nvim`.

Once the terminal is open, the normal window workflow remains available:
`Super+Shift+Left/Right/Up/Down` moves it, `Super+Ctrl+Left/Right/Up/Down`
resizes it by 40 pixels, `Super+F` makes it fullscreen, `Super+Shift+F`
maximizes it, `Super+J` toggles split behavior, and `Super+1` through
`Super+9` select workspaces. These are compositor bindings; the project
helper only chooses the directory and starts the requested process.

## Run project commands and agents

Pass a complete command after `--`. The command runs in a terminal whose
working directory is the registered project:

```sh
workstation-project run api -- npm run dev -- --host 127.0.0.1
workstation-project agent workstation -- claude --resume
```

`run` launches the requested command directly. `agent` routes it through
`workstation-agent` in the project terminal to record status and resource use.
Neither selects an agent, creates an approval policy, or supplies credentials.
The first command must be available
as an external executable in `PATH` (shell builtins are rejected), or be an
executable path. Relative executable paths such as `./scripts/dev` and
`../shared/dev` are resolved from the registered project directory. A missing
command returns status 127.
The terminal's exit status is returned to the caller.

`workstation-project path ID` is a read-only lookup used by supervised
launchers. It prints the canonical registered directory and does not change
the selected project. Project instructions can be initialized explicitly with
`workstation-project instructions ID --init`; this refuses an existing
`AGENTS.md`, including a symlink, and writes only the documentation template.
The file is never sourced or executed by the workstation helpers.

For an interactive coding-agent run, use the supervised wrapper:

```sh
workstation-agent run workstation -- claude --resume
workstation-agent list
workstation-agent status RUN-ID
```

The wrapper requires exactly one active managed graphical session target and
places the command in a transient user systemd scope tied to that target. It
passes the command argv and terminal streams directly, records only local
process and cgroup measurements, and stores private run metadata under
`${XDG_STATE_HOME:-$HOME/.local/state}/blendos-workstation/agents/`. Metadata
does not contain prompts, argv, environment, credentials, provider token
counts, or quota estimates. `status` reports live CPU and memory values when
the user manager provides them; unavailable accounting is reported as such.
Use `list --wait` or `status RUN-ID --wait` only from a terminal when a menu
window should pause for Enter after displaying its result.

After completion, `status` reports measured wall time, user/system CPU time and
maximum resident memory from GNU time. The wrapper exit status is authoritative;
GNU time's reported exit field can differ for a signaled command. Completed
records survive normal scope removal. A still-running record whose scope is
missing is displayed as `state-lost`; status queries do not rewrite records.
The wrapper requires systemd's `--expand-environment=no` support to preserve
literal arguments. It fails on older managers that lack that option.

Keep project startup, dependencies, secrets, and service-specific commands in
the project's own documentation. Portless and rootless Podman Compose remain
the owners of development routing and container lifecycle; this helper only
chooses a directory and starts an explicitly requested argv.

## Codex CLI

The owner-selected Codex CLI serves the existing project coding-agent workflow.
The common System Definition declares Arch's
[`openai-codex` package](https://archlinux.org/packages/extra/x86_64/openai-codex/),
which provides `codex` for both Machine Profiles. Installation and updates use
the normal bootstrap/rebuild path. Its package is Apache-2.0 licensed.

After rebuilding, run these commands in the blendOS account's terminal:

```sh
codex --version
codex login
codex login status
workstation-project agent workstation -- codex
# Or, from an existing terminal, use the registered project and supervised scope:
workstation-agent run workstation -- codex
```

Replace `workstation` with your registered project ID. Sign-in is an explicit
personal step following the [official OpenAI authentication guide](https://learn.chatgpt.com/docs/auth).
Keep account settings, credentials and conversation/run state in the upstream
`CODEX_HOME` directory (normally `~/.codex`) outside the checkout; cached
credentials may instead live in the OS credential store. Bootstrap does not
authenticate, select a model or change Codex permissions. Accidental `.codex/`
copies at this repository's root are ignored.

Codex runs on demand in the project terminal. The existing agent wrapper binds
its scope to the managed graphical session and records resource facts without
prompts or credentials; there is no Codex autostart service. The development
doctor checks command availability without launching Codex or reading its
authentication state. To accept integration after deployment, verify the
version/sign-in checks, one registered-project run, its agent status, and that
the scope ends on logout. Until then the contract remains **Planned** for both
profiles. See the [official CLI guide](https://learn.chatgpt.com/docs/codex/cli)
for upstream usage.

## Runtimes and containers

Use project-owned Mise configuration for each project's runtime requirements.
The workstation's existing login environment supplies Mise shims. Inspect
`mise ls` in the project, then run `mise install` only for a project whose
configuration you trust. For example:

```sh
workstation-project run api -- mise exec -- node --version
workstation-project run api -- podman compose ps
```

Podman is rootless and its socket starts on demand. Use the
[Portless guide](../portless/README.md) for loopback `.localhost` routes and
Compose startup/cleanup. `Super+K` shows effective compositor shortcuts,
including generated workspace and movement bindings.

After the next deployment, smoke-test `Super+Ctrl+P`, one terminal/editor
launch in a path containing spaces, an explicitly selected agent, and window
movement/resizing. WSL tests cover the launcher contract; they do not establish
Ghostty or Hyprland's live graphical behavior.

## Troubleshooting

If `open` reports that `session-terminal` is unavailable, install or deploy
the workstation session helpers before using the project launcher. If chooser
selection fails, check the Walker session service. A stale path is fixed by
removing the registration and adding the existing directory again. Inspect
the private registry only for diagnosis; do not commit its contents.
