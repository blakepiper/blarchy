# Style

- Two spaces for indentation, no tabs
- Use bash 5 conditionals: use `[[ ]]` for string/file tests and `(( ))` for numeric tests
- In `[[ ]]`, don't quote variables, but do quote string literals when comparing values (e.g., `[[ $branch == "dev" ]]`)
- Prefer `(( ))` over numeric operators inside `[[ ]]` (e.g., `(( count < 50 ))`, not `[[ $count -lt 50 ]]`)
- For strings/paths with spaces, quote them instead of escaping spaces with `\ ` (e.g., `"$APP_DIR/Disk Usage.desktop"`, not `$APP_DIR/Disk\ Usage.desktop`)
- Shebangs must use `#!/bin/bash` consistently (never `#!/usr/bin/env bash`)
- Scripts under `install/` and `migrations/` may be sourced and intentionally omit shebangs

# BLARCHY Source of Truth

BLARCHY is a personal Arch Linux + Hyprland environment derived from Omarchy.
It is not a distribution and does not own the base operating system. The
supported installation path is a user cloning this repository on an already
bootable minimal Arch system and running `./install.sh`.

- The package manifest selected by `install.sh` is BLARCHY-owned even if a
  compatibility filename is temporarily retained.
- `yay -Syu` is the normal system and AUR update path.
- `blarchy update` is the BLARCHY environment update path. It may fast-forward
  only a clean configured checkout tracking `blakepiper/blarchy`, then reruns
  the installer. Package updates must never pull or replace this checkout.
- Never add partitioning, formatting, mounting, bootloader, EFI, `/boot`, or
  initramfs ownership to the standalone installer.
- Do not depend on private Omarchy package repositories, `omarchy-pkgs`,
  `omarchy-settings`, an Omarchy ISO, or `/etc/skel` package seeding.
- The `omarchy-*` command names, `$OMARCHY_PATH`, `~/.config/omarchy`, plugin
  IDs, and related internal namespaces are retained compatibility APIs. New
  user-facing lifecycle commands use `blarchy`; do not rename inherited APIs
  merely for branding.
- Some inherited ISO/package code remains for history and deliberate review. It
  is not an alternate supported BLARCHY installation path and must not be wired
  into `./install.sh` without first adapting it to the standalone ownership
  boundary.

# Command Naming

Most inherited commands start with `omarchy-`; BLARCHY-native lifecycle
commands use the small `blarchy` command surface. Prefixes indicate purpose.

The authoritative command group list lives in `bin/omarchy` in `GROUP_DESCRIPTIONS`. Keep `GROUP_DESCRIPTIONS` updated when adding a new command prefix.

Common prefixes include:

- `cmd-` - check if commands exist, misc utility commands
- `capture-` - screenshots, screen recordings, and other capture tools
- `pkg-` - package management helpers
- `hw-` - hardware detection (return exit codes for use in conditionals)
- `refresh-` - copy default config to user's `~/.config/`
- `restart-` - restart a component
- `launch-` - open applications
- `install-` - install optional software
- `setup-` - interactive setup wizards
- `toggle-` - toggle features on/off
- `theme-` - theme management
- `update-` - update components

Do not maintain a second exhaustive prefix list here. Consult
`GROUP_DESCRIPTIONS` when selecting or checking a command group so this
guidance does not drift from the router.

# Command Metadata

Commands in `bin/` can declare CLI metadata in comments near the top of the file. `bin/omarchy` scans the first 80 lines, and tests expect command metadata to remain valid.

Supported metadata keys:

- `# omarchy:group=...` - override the command group inferred from the filename
- `# omarchy:name=...` - override the command name inferred from the filename
- `# omarchy:summary=...` - short help text
- `# omarchy:args=...` - usage arguments
- `# omarchy:examples=...` - examples separated with ` | `
- `# omarchy:alias=...` / `# omarchy:aliases=...` - alternate routes
- `# omarchy:hidden=true` - hide from default command listings
- `# omarchy:requires-sudo=true` - mark commands that require sudo

Only use `omarchy:examples` where there are args that need explaining.

Prefer explicit metadata for user-facing commands. Keep routes consistent with the filename unless there is a deliberate alias or compatibility route.

Example:

```bash
# omarchy:summary=Take a screenshot
# omarchy:args=[smart|region|windows|fullscreen] [slurp|copy]
# omarchy:examples=omarchy screenshot | omarchy capture screenshot region
```

# Runtime Environment

- Source, installed runtime, and user configuration are separate layers. The
  checkout is development source; `/usr/local/share/blarchy` is the live
  installed runtime; XDG locations contain user-owned configuration and state.
- `$BLARCHY_PATH` is set at the top level by the uwsm session environment and
  points at the installed runtime. Commands and Quickshell should prefer it and
  default to `/usr/local/share/blarchy`.
- `$OMARCHY_PATH` remains a legacy compatibility/test override. It may be used
  as a fallback after `$BLARCHY_PATH`, but production defaults must never point
  at an Omarchy installation or infer a checkout from `$HOME`. Explicit
  development links use `/etc/blarchy-dev.conf` to override `$BLARCHY_PATH`.

# Privileged Commands

- Follow the "Privilege Escalation" section of `default/omarchy-skill/SKILL.md`. It draws the
  `sudo`/`pkexec` line by whether the caller has a terminal to enter a password in, and the repo's
  own scripts follow it.

# Git

- Commits should be atomic: include only one coherent change or fix, and do not mix unrelated work.
- Commit messages should be succinct and describe the change being made.

# Install Scripts

`./install.sh` is BLARCHY's primary installer. It runs on an already bootable
minimal Arch system and must remain idempotent and bootloader-agnostic. It must
not partition, format, mount, write under `/boot`, install/configure a
bootloader, write EFI entries, or directly rebuild the initramfs. Preserve
existing network and display managers when configured, and preserve existing
user files on a normal install.

Standalone-specific leaves live under `install/standalone/`. Reuse the package
manifest and runtime setup abstractions, but do not call inherited leaves that
replace pacman configuration or assume Limine, Snapper, an ISO chroot, or
package-seeded `/etc/skel` defaults.

Migrations that alter boot or snapshot state must declare
`# blarchy:standalone-safe=false` immediately after their opening `echo` so the
standalone migration runner excludes them.

The active flow is:

- `install.sh` installs packages with yay and orchestrates system and user setup.
- `install/standalone/system.sh` installs system integration without taking over
  the machine's boot, storage, or pacman configuration. It publishes a copied
  runtime at `/usr/local/share/blarchy`; never replace that with symlinks into
  the Git checkout. Keep systemd command paths aligned with `/usr/local/bin`.
- `install/standalone/user.sh` seeds missing user files, or overwrites only when
  its explicit `overwrite` mode is requested.
- `bin/blarchy-finalize-user` handles runtime-dependent per-user setup and
  sources `install/user/all.sh`; `omarchy-finalize-user` is a compatibility
  wrapper.
- `bin/omarchy-reinstall-configs` is the explicit destructive resync path.
- sourced leaves under `install/` intentionally omit shebangs and must avoid
  `exit` unless aborting the parent setup is intended.
- use source-specific installer variables while publishing and `$BLARCHY_PATH`
  for installed runtime assets. Use `$OMARCHY_PATH` only for compatibility or
  explicit inherited repair work.
- new root-scoped standalone work belongs in `install/standalone/system.sh` or a
  standalone leaf it sources. Treat `bin/omarchy-setup-system`,
  `install/config/`, `install/hardware/`, and `install/login/` as inherited
  upstream code unless the standalone installer explicitly adopts a safe leaf.
- keep every per-user setup leaf under `install/user/` (including `install/user/hardware/` and `install/user/first-run/`) so it is clear what must run for each user.
- prefer helper commands for package and command checks where available.

Raw `command -v`, `pacman`, and `pacman-key` are acceptable in package-helper contexts where direct package-manager behavior is the point of the script.

# Helper Commands

Use these instead of raw shell commands:

- `omarchy-cmd-missing` / `omarchy-cmd-present` - check for commands
- `omarchy-pkg-missing` / `omarchy-pkg-present` - check for packages (don't use these if you can just use `omarchy-pkg-add`/`omarchy-pkg-drop`)
- `omarchy-pkg-add` - install packages (handles both pacman and AUR)
- `omarchy-pkg-drop` - remove packages; use this instead of raw `pacman -R*`
- `omarchy-notification-send` - send desktop notifications; do not call `notify-send` directly
- `omarchy-hw-asus-rog` - detect ASUS ROG hardware (and similar `hw-*` commands)

Commands installed by BLARCHY's default package manifest are runtime invariants. Invoke them directly; do not add defensive `omarchy-cmd-present` / `omarchy-cmd-missing` checks around them. Use command-presence helpers only for genuinely optional dependencies or code that can run before the default package set is installed.

Exceptions are allowed for migration and package-helper scripts where the helper may not be available yet, where the helper itself is being implemented, or where direct package-manager behavior is required.

# Config Structure

- `config/` - default configs copied to `~/.config/`
- `default/themed/*.tpl` - templates with `{{ variable }}` placeholders for theme colors
- `themes/*/colors.toml` - theme color definitions (accent, background, foreground, red/green/yellow/blue/magenta/cyan and bright_* variants)

# Tests

Run focused automated tests for the area you changed. Current test entry points:

- `./test/all` - aggregate runner for CLI and shell tests; it intentionally does not run graphical acceptance tests
- `./test/cli` - CLI routing, command metadata, theme helpers, and safe dispatch coverage
- `./test/shell` - all BLARCHY shell tests under `test/shell.d/`

New BLARCHY shell tests should live in `test/shell.d/*-test.sh` so `./test/shell` picks them up automatically. Source `test/shell.d/base-test.sh` for shared root-path discovery, assertions, and Node test helpers.

# Acceptance Tests

The inherited graphical acceptance suite lives in `test/acceptance` with test files under
`test/acceptance.d/*-test.sh`. It exercises a real installed desktop,
including session health, shell surfaces, panels, keyboard navigation,
representative applications, and system setup. Source
`test/acceptance.d/base-test.sh` for the shared helpers.

Run acceptance tests only in a disposable Arch VM installed through the current
`./install.sh`, never in the active development session. The suite opens and
closes applications and temporarily changes desktop configuration. Package
manifest, installer, finalization, and shipped-default changes require a fresh
minimal Arch VM so the supported installation path is actually exercised.

The old sibling `omarchy-iso` harness is upstream infrastructure. It may still
help diagnose inherited graphical behavior, but it does not validate BLARCHY's
installer or ownership model and is not a release gate. There is not yet a
BLARCHY-specific VM harness; document manual VM coverage honestly rather than
claiming an ISO test proves the standalone flow.

Keep unrelated acceptance workflows in separate test files. The runner records
a failed file and continues with the remaining files, which preserves as much
diagnostic coverage as possible. Restore modified user state with traps, close
anything the test opens, and capture every visually distinct state (including
entered input where relevant) as `success-<step>.png`; failure helpers capture
`failure-<step>.png`. Preserve screenshots and logs with the VM test artifacts.

In-guest `wtype` is suitable for typing into focused controls, but it does not
reliably prove that a global Hyprland keybinding works. Use compositor-level
input from the VM host when validating global shortcuts.

# Visual Verification

Visual changes must be verified in the running UI in addition to automated
tests. This includes BLARCHY shell styling and layout, panels, menus,
notifications, desktop appearance, animations, transitions, screenshots, and
screen recording flows. Creating an artifact is not sufficient: inspect it for
clipping, overlap, incorrect spacing, stale state, focus problems, and visual
regressions before finishing.

Take a full-screen screenshot without opening the editor:

```bash
omarchy capture screenshot fullscreen save
```

The command prints the saved path and writes to the configured Pictures
directory. Use `omarchy screenshot` for the interactive smart-region flow.
Capture reference and candidate states as separate images when changing a
layer-shell surface or layout, then compare both.

Record a short full-screen video for animation, transition, timing, capture, or
screen-recording changes:

```bash
omarchy screenrecord --fullscreen
# Exercise the changed behavior.
omarchy screenrecord --stop-recording
```

The stop command prints the saved video path in the configured Videos
directory. Review the recording before finishing, and keep it short and focused
on the changed behavior.

For interactive UI work, use `wtype` to simulate keyboard input when available. Example: start the UI in the background, wait briefly for focus, then run `wtype -k Right -k Return` to exercise keyboard selection and confirm the resulting command output or state change. Prefer this over manual-only verification when a UI returns a selected value or changes a symlink/config.

If a launched UI would otherwise remain open, keep track of its PID and stop it
after the screenshot or recording; avoid broad process kills unless checking
with `ps` first.

# BLARCHY shell (retained Omarchy namespace)

The Quickshell desktop runs as a single long-running process out of
`shell/`. Hyprland autostart launches it directly with `quickshell -n -p`;
do not start additional standalone Quickshell instances for individual
components.

Run `omarchy-restart-shell` after making changes to QML files.

Plugin contract:

- First-party plugins live directly under `shell/plugins/` or one category
  level deeper, such as `shell/plugins/panels/weather/`. First-party bar-only
  widgets may use adjacent `*.manifest.json` files. Third-party plugins live
  at `~/.config/omarchy/plugins/<id>/` with a `manifest.json` at the root.
- Every plugin manifest declares `schemaVersion`, `id`, `name`, `version`,
  `kinds`, and `entryPoints`. See
  [`docs/omarchy-shell.md`](docs/omarchy-shell.md) and
  `shell/services/PluginRegistry.qml` for the current contract; fields such as
  `activation` are optional.
- Entry-point QML files are `Item`s (not `ShellRoot`), and accept the
  shell-injected properties `omarchyPath`, `shell`, `manifest`, and
  `pluginRegistry` / `barWidgetRegistry` as appropriate.
- Panel / overlay / menu plugins must expose `open(payloadJson)` and
  `close()` lifecycle methods for `shell summon` and `shell hide`.

IPC:

- `bin/omarchy-shell` is the canonical IPC entry point. It forwards to
  the running shell and does not start it. Prefer it over re-implementing
  direct Quickshell socket calls in every CLI.
- The `shell` IPC target exposes lifecycle and configuration methods including
  `ping`, `summon`, `hide`, `toggle`, `call`, `rescanPlugins`, `reloadConfig`,
  `setPluginEnabled`, and `listPlugins`. `shell.qml` also registers
  `image-selector`, which drives the `omarchy.image-picker` panel.
- Individual plugins register their own IPC targets, named for the plugin rather
  than for where they appear: the background switcher registers `background`, and
  bar widgets register one target each — `omarchy.indicators`,
  `omarchy.system-update`, `omarchy.clock`. There is no `bar` target.

Widget files in `shell/plugins/bar/widgets/` contain Nerd Font glyphs as raw
unicode characters. The `Write` and `Edit` tools strip multi-byte
codepoints in some positions — do **not** rewrite widget files wholesale
through those tools. For glyph fixes, use the targeted `Edit` tool with
the surrounding context, or a Python script that inserts codepoints via
`chr(0xXXXXX)`.

# Refresh Pattern

To copy a default config to user config with automatic backup:

```bash
omarchy-refresh-config hypr/hyprland.lua
```

This copies `$BLARCHY_PATH/config/hypr/hyprland.lua` to `~/.config/hypr/hyprland.lua`. The argument
is interpolated into both paths and only checked with `[[ -e ]]`, so pass a plain relative path: a
name containing `..` resolves and copies, landing outside `~/.config` rather than being rejected.

# Migrations

Read `docs/migrations.md` before creating or changing migrations.

Migrations are per-user and run through `blarchy migrate` during `blarchy
update`, an explicit installer rerun, or the login-time migration notification.
Normal system updates use `yay -Syu` and do not pull BLARCHY source. Put
migrations directly under `migrations/<timestamp>.sh`. Completion state is
BLARCHY-owned and may import the retained v0.1 state so every user keeps their
history. Migrations run as the user; privileged work should invoke the
appropriate helper or privilege prompt, and no-op when another user already
applied it.

To create a new migration, run `omarchy-dev-add-migration --no-edit`.

New migration format:
- File permissions must be `0644` (`-rw-r--r--`); migration runners execute them with `bash -euo pipefail`, not through executable bits
- No shebang line
- Start with an `echo` describing what the migration does
- Use `$BLARCHY_PATH` to reference installed BLARCHY assets; use
  `$OMARCHY_PATH` only when repairing inherited state
- Prefer helper commands such as `omarchy-cmd-present`, `omarchy-cmd-missing`, `omarchy-pkg-present`, and `omarchy-pkg-missing`

`bin/omarchy-upgrade-to-quattro` is retained upstream upgrade code, not part of
the supported BLARCHY install or update path. Do not add new BLARCHY migration
work to it.

Migrations may use raw `pacman`, `command -v`, or direct config edits when needed for one-off repair work.
