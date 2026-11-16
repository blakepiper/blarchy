# Style

- Two spaces for indentation, no tabs
- Use Bash 5 `[[ ]]` string/file tests and `(( ))` numeric tests
- Do not quote variables inside `[[ ]]`; quote literals in exact comparisons
- Quote paths with spaces rather than escaping their spaces
- Use `#!/bin/bash` for executable scripts (`install.sh`, `test/*`)
- Sourced leaves under `install/` intentionally omit shebangs

# Repository purpose

This repository configures a fresh Arch installation for a manual TTY login
followed by `start-hyprland`. It is an install script and desktop config source,
not a distribution or a branded desktop product.

- Arch owns packages. The source of truth is `install/packages` for official
  repositories and `install/packages-aur` for the small AUR exception list.
- Keep normal package updates on `pacman -Syu` and AUR updates on `yay -Syu`.
- Do not pin package versions or add a repository self-updater.
- The supported session is Hyprland + Quickshell + Wofi + mako + hyprlock /
  hypridle + swaybg + Ghostty. Do not add another compositor, desktop
  environment, display manager, or bar.
- The session starts manually from a TTY with the package's `start-hyprland`.
  Do not configure automatic login or install a display manager.
- The terminal is Ghostty. `dev` uses tmux for project workspaces; do not add a
  second general-purpose terminal multiplexer.
- Neovim is vanilla and the repository's `config/nvim/init.lua` stays empty.
- Fastfetch is the system-information command. The Codex usage helper may read
  Codex data only; do not restore removed agent integrations.
- Firefox policies live in `etc/firefox/policies/policies.json`. Profile-local
  defaults live in `config/firefox/` and seed missing files into Firefox
  profiles without replacing existing profile settings.
- Helpers in `bin/` are managed files copied by `install/user.sh` to
  `~/.local/bin`. Compositor configs must reference them by absolute path.
- Installed service names, paths, app IDs, environment variables, and user
  interface text must not contain product branding.
- Keep the end-user interface to `./install.sh`, package-manager commands, and
  `./test/smoke`.

# Installer boundaries

The installer targets fresh Arch systems, not conversion of existing desktops.
Failed installations must be retryable without duplicate packages, shell
blocks, or services. It must not partition, format, mount, write under `/boot`,
configure a bootloader, create EFI entries, replace pacman repositories, or
directly run `mkinitcpio`. Existing user files are preserved.

Root-scoped integration belongs in `install/system.sh`; hardware detection
belongs in `install/hardware.sh`; per-user setup belongs in `install/user.sh`.
Installer-only variables must not leak into runtime defaults. Hardware-specific
drivers and services are detected at install time, not hardcoded in the base
package list.

# Desktop configuration

Hyprland configuration lives in `config/hypr/`; the compositor loads and
reports its own configuration errors. Quickshell lives in
`config/quickshell/`. Keep the Super-based bindings documented in README.md.

The external keyboard remap is a udev hwdb rule matching only its USB vendor
and product. Do not globally swap modifiers or affect built-in or Bluetooth
keyboards. Monitor handling must not hardcode an individual machine's driver or
connector name; preserve dynamic dock hotplug behavior.

User defaults seed from `config/` into `~/.config` without overwriting.
System files seed from `etc/` and converge on repository state.

# Tests and verification

Run `./test/smoke` for every change touching the installer, package manifests,
desktop configs, or AI usage helper. It runs with Bash and Python 3.

Full graphical acceptance happens in a disposable Arch VM installed through
the current `./install.sh`.

# Git

Keep commits atomic and messages succinct. Stage only task-related files and
preserve unrelated worktree changes.

After completing requested repository changes and verification, commit the
task-related files and push the current branch to its configured remote. Do not
leave finished work uncommitted or unpushed unless the user explicitly asks or
pushing would overwrite or diverge from remote work.
