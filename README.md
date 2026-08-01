<p align="center">
  <img src="./icon.png" alt="BLARCHY icon" width="180">
</p>

<h1 align="center">BLARCHY</h1>

<p align="center">
  <strong>Blake's Arch + Hyprland Environment</strong><br>
  A minimal, keyboard-first desktop with sensible mouse support.
</p>

<p align="center">
  <img alt="Version 0.1.0" src="https://img.shields.io/badge/version-0.1.0-8bd450?style=for-the-badge&labelColor=111111">
  <img alt="Arch Linux" src="https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white">
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-58E1FF?style=for-the-badge&logo=wayland&logoColor=111111">
  <a href="./LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-8bd450?style=for-the-badge&labelColor=111111"></a>
</p>

---

BLARCHY is my personal Arch Linux + Hyprland environment, built on the proven
infrastructure of [Omarchy](https://github.com/basecamp/omarchy). It is not a
separate Linux distribution: Arch owns the operating system and packages;
BLARCHY owns the desktop defaults, configuration, scripts, branding, and update
behavior.

> [!NOTE]
> BLARCHY is currently a personal v0.1 environment. It keeps internal
> `omarchy-*` command names intentionally so useful upstream changes remain
> practical to merge.

## Install on an existing Arch system

Start with a bootable minimal Arch installation that you control. Complete the
normal Arch installation yourself, including:

- partitions and filesystems;
- a kernel and firmware;
- networking;
- your preferred bootloader;
- a non-root user with `sudo` access.

GRUB, systemd-boot, rEFInd, Limine, and dual-boot layouts are all outside
BLARCHY's ownership. Once the machine boots into Arch:

```bash
sudo pacman -S --needed git
git clone https://github.com/blakepiper/blarchy.git ~/blarchy
cd ~/blarchy
./install.sh
```

The installer enables Arch multilib for Steam, bootstraps yay when needed,
installs the desktop packages, links this checkout as the BLARCHY runtime,
installs session integration, and seeds missing user configuration. It is safe
to rerun: package operations use `--needed`, managed system files and symlinks
converge on the same state, existing user configuration is preserved, and
one-time finalization uses completion markers.

It never partitions, formats, mounts, edits bootloader configuration, writes
EFI entries, installs a bootloader, or directly rebuilds the initramfs. Normal
Arch package hooks may still update an installed kernel or its initramfs during
the package transaction. See the detailed
[standalone installation contract](./docs/standalone-install.md).

## The default stack

| Role | BLARCHY choice |
| --- | --- |
| Browser | Firefox + uBlock Origin |
| Terminal | Alacritty + Bash predictive suggestions |
| Files | Nautilus |
| Code | VSCodium |
| Launcher and top bar | BLARCHY Quickshell (retained Omarchy architecture) |
| Dock | `nwg-dock-hyprland` |
| Music and games | Spotify + Steam |
| Creative | GIMP |
| Development | Node.js/npm, Python/pip, Codex CLI, Claude Code |
| Packages | pacman + yay |

No Chrome, Chromium, Foot, Docker, Discord, Google web apps, or social/messaging
web-app shortcuts are installed on a fresh BLARCHY setup.

## Keyboard first

| Shortcut | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Application launcher |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>Space</kbd> | BLARCHY system menu |
| <kbd>Super</kbd> + <kbd>Enter</kbd> | Alacritty |
| <kbd>Super</kbd> + <kbd>F</kbd> | Nautilus |
| <kbd>Super</kbd> + <kbd>B</kbd> | Firefox |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close focused window |
| <kbd>Super</kbd> + <kbd>L</kbd> | Lock |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Region screenshot: save + copy |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>F</kbd> | True fullscreen |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Previous workspace |
| <kbd>Super</kbd> + <kbd>1–9</kbd> | Switch workspace |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>1–9</kbd> | Move window to workspace |
| <kbd>Super</kbd> + arrow | Snap window to that half of the monitor |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + arrow | Focus the window in that direction |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + arrow | Move window to an adjacent monitor |
| <kbd>Super</kbd> + <kbd>T</kbd> | Return a snapped window to tiling |

Screenshots land in `~/Pictures/Screenshots` and are copied to the clipboard.
Window snapping uses the active monitor's scaled geometry and usable work area,
not hard-coded display dimensions.

## Mouse friendly

- <kbd>Super</kbd> + left-button drag moves a window.
- <kbd>Super</kbd> + right-button drag resizes a window.
- Workspaces and system indicators in the top bar are clickable.
- Audio supports scroll-to-adjust and click-to-open controls.
- Network, Bluetooth, calendar, notifications, and system actions open from the
  bar.
- The bottom-center dock reveals at the screen edge and shows pinned and running
  apps. Initial pins are Firefox, Nautilus, Alacritty, Spotify, and Steam.

No title bars are required.

## Updates

```bash
yay -Syu
```

That is the complete normal update path. BLARCHY does not block pacman, wrap
yay, replace the user's package configuration, pull Git source during a package
transaction, or globally update npm packages. `omarchy update` remains only as
a compatibility alias for `yay -Syu`. The installer enables yay's development
package checks so installed `*-git` packages participate too.

BLARCHY source is intentionally pinned to the checked-out revision. Until a
real `blarchy-git` package is published to the AUR, update BLARCHY itself
explicitly and rerun the idempotent installer:

```bash
cd ~/blarchy
git pull --ff-only
./install.sh
```

## Working with upstream

Basecamp/Omarchy remains a development remote named `upstream`:

```bash
git fetch upstream
git merge upstream/quattro
```

Rebase or cherry-pick instead when that better fits the change. Upstream is
incorporated deliberately; it is never involved in `yay -Syu`.

## Repository map

```text
bin/          commands and update helpers
config/       BLARCHY user configuration defaults
default/      shared application, system-integration, shell, and theme defaults
install/      system and per-user setup leaves
shell/        the retained Quickshell desktop
test/         CLI, shell, and graphical acceptance coverage
```

## Credits

BLARCHY is based on [Omarchy](https://github.com/basecamp/omarchy) and preserves
its project history, copyright notices, and attribution. BLARCHY modifications
are released under the [MIT License](./LICENSE).
