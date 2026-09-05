# Style

- Two spaces for indentation, no tabs
- Use Bash 5 `[[ ]]` string/file tests and `(( ))` numeric tests
- Do not quote variables inside `[[ ]]`; quote literals in exact comparisons
- Quote paths with spaces rather than escaping their spaces
- Use `#!/bin/bash` for executable scripts (`install.sh`, `test/*`)
- Sourced leaves under `install/` intentionally omit shebangs

# Repository purpose

This repository reproduces an Arch Linux desktop built on Niri. The
supported path is installing Arch with `archinstall` (base system, no
desktop), booting it, connecting to wifi, cloning this repository as
the intended desktop user, and running `./install.sh`.

- Arch and the AUR own packages; normal updates use `yay -Syu`.
- This repository has no release channel, self-updater, version command, or
  migration framework.
- The package sources of truth are `install/packages` (pacman) and
  `install/packages-aur` (AUR, installed through yay).
- Hardware-specific drivers and services are derived at install time by
  `install/hardware.sh`. Never hardcode machine-specific drivers into the
  base package list.
- The desktop stack is Niri + Waybar + fuzzel + mako + swaylock/swayidle
  + swaybg + kitty. Do not reintroduce a second compositor, desktop
  environment, display manager, or bar without explicit user approval.
- The terminal emulator is kitty. The terminal multiplexer is prettymux
  (AUR `prettymux-bin`, so it updates with `yay -Syu`).
- The AI usage widget is `bin/ai-usage` with scanners in
  `bin/ai-usage-scanners/`, surfaced as Waybar's `custom/ai-usage` module.
- The night-mode toggle is `bin/night-mode` (session state file plus a
  long-lived gammastep process), surfaced as Waybar's `custom/night-mode`
  module. Caffeinate uses Waybar's native `idle_inhibitor` module.
- Helpers in `bin/` are managed files: `install/user.sh` copies them to
  `~/.local/bin`, and desktop configs must reference them by that absolute
  path because login-session PATH does not include `~/.local/bin`.
- Do not add a branded lifecycle command surface; the interface is
  `./install.sh`, `yay -Syu`, and `./test/smoke`.

# Installer boundaries

The installer targets fresh Arch installations, not conversion of existing
desktops. Failed installations must be retryable without duplicate packages,
shell blocks, or services. Always resolve current packages from Arch/AUR;
do not pin versions or add a repository self-updater.
It must not partition, format, mount, write under `/boot`, configure a
bootloader, create EFI entries, replace pacman repositories, or directly run
`mkinitcpio`. Preserve an existing display manager when one is already
enabled, and preserve existing user files during a normal install.

Root-scoped integration belongs in `install/system.sh`; hardware detection
belongs in `install/hardware.sh`; user setup belongs in `install/user.sh`.
Source-specific installer variables must not leak into runtime defaults.

The AUR manifest contains binary releases, repacks, and `blesh-git` (Bash
scripts built with the existing base-devel tools). Bootstrap builds yay
from source; makepkg resolves declared build dependencies (including Go).
Do not maintain a separate list of language toolchains. The installer enables
yay's development-package checks so `yay -Syu` also updates `blesh-git`.

# Desktop configuration

Niri configuration lives in `config/niri/config.kdl` and is validated by
Niri itself on save. Keep keybindings in the Super-based scheme documented
in the README; Niri-specific adaptations (columns, workspaces, monitors,
overview) are expected and welcome.

User defaults seed from `config/` into `~/.config` without overwriting.
System files seed from `etc/` and converge on the repository state.

# Tests and verification

Run `./test/smoke` for every change touching the installer, package
manifests, desktop configs, or the AI widget. It runs on any machine
with bash and python3.

Full graphical acceptance happens in a disposable Arch VM installed
through the current `./install.sh`.

# Git

Keep commits atomic and messages succinct. Stage only task-related files and
preserve unrelated worktree changes.

After completing requested repository changes and their verification, commit
the task-related files and push the current branch to its configured remote.
Do not leave finished work uncommitted or unpushed unless the user explicitly
asks for that or pushing would overwrite/diverge from remote work.
