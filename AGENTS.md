# Style

- Two spaces for indentation, no tabs
- Use Bash 5 `[[ ]]` string/file tests and `(( ))` numeric tests
- Do not quote variables inside `[[ ]]`; quote literals in exact comparisons
- Quote paths with spaces rather than escaping their spaces
- Use `#!/bin/bash` for executable shell scripts
- Sourced leaves under `install/` intentionally omit shebangs

# Repository purpose

This repository reproduces an Arch Linux desktop. The supported path
is cloning it onto an already bootable minimal Arch system and running
`./install.sh` as the intended desktop user.

- Arch and the AUR own packages; normal updates use `yay -Syu`.
- This repository has no release channel, self-updater, version command, or
  migration framework.
- The package source of truth is `install/packages`.
- The installer publishes a copied runtime at `/usr/local/share/rice`.
- `$RICE_PATH` is canonical. `$OMARCHY_PATH`, `~/.config/omarchy`,
  `omarchy-*` helpers, and `omarchy.*` plugin IDs remain inherited internal
  compatibility namespaces.
- Do not add a new branded lifecycle command surface.

# Installer boundaries

The installer must remain idempotent and safe for an existing Arch machine.
It must not partition, format, mount, write under `/boot`, configure a
bootloader, create EFI entries, replace pacman repositories, or directly run
`mkinitcpio`. Preserve existing network and display managers when configured,
and preserve existing user files during a normal install.

Root-scoped integration belongs in `install/standalone/system.sh`; user setup
belongs under `install/user/` or `install/standalone/user.sh`. Source-specific
installer variables must not leak into runtime defaults.

The installer standardizes AUR builds on the Arch `rustup` provider. Install it
in the prerequisite pacman transaction and initialize a stable default only
when the user has no default toolchain. Do not temporarily install and remove
the conflicting `rust` provider.

# Commands and privileges

Prefer existing `omarchy-cmd-*`, `omarchy-pkg-*`, and
`omarchy-notification-send` helpers in maintained desktop scripts. Commands
declared by `install/packages` are runtime invariants and do not need defensive
presence checks.

Use `sudo` for privileged work run from an interactive terminal. Use `pkexec`
for privileged actions launched from a graphical process that has no terminal
for password entry.

Command metadata near the top of `bin/omarchy-*` files is parsed by
`bin/omarchy`. Keep metadata valid and update `GROUP_DESCRIPTIONS` when
adding a new command prefix.

# Desktop runtime

Hyprland user overrides live under `config/hypr/`. The Quickshell desktop is a
single process rooted at `shell/shell.qml`; do not launch separate component
instances. First-party plugins live under `shell/plugins/`, while user plugins
live under `~/.config/omarchy/plugins/`.

Use `bin/omarchy-shell` for shell IPC. Panel, overlay, and menu plugins expose
`open(payloadJson)` and `close()`. Entry points are `Item`s rather than
`ShellRoot`s.

Widget files can contain raw Nerd Font glyphs. Avoid whole-file rewrites that
can strip multibyte codepoints.

# Tests and visual verification

Run focused tests for the changed area, then use:

- `./test/cli` for command routing and metadata
- `./test/shell` for shell tests
- `./test/all` for the aggregate non-graphical suite

Graphical acceptance tests run only in a disposable Arch VM installed through
the current `./install.sh`. Visual changes also require inspection in the
running UI for clipping, overlap, focus, stale state, and regressions.

# Git

Keep commits atomic and messages succinct. Stage only task-related files and
preserve unrelated worktree changes.
