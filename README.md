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

## The default stack

| Role | BLARCHY choice |
| --- | --- |
| Browser | Firefox + uBlock Origin |
| Terminal | Alacritty |
| Files | Nautilus |
| Code | VSCodium |
| Launcher and top bar | Omarchy Quickshell |
| Dock | `nwg-dock-hyprland` |
| Music and games | Spotify + Steam |
| Creative | GIMP |
| Development | Git, Node.js/npm, Python/pip, Codex CLI, Claude Code |
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
omarchy update
```

The retained update pipeline handles snapshots, Arch packages, AUR packages,
BLARCHY source, migrations, hooks, and restart checks. It never globally
updates every npm package.

The `quattro` branch tracks this repository's `origin/quattro`. Runtime source
updates explicitly refuse the Basecamp/Omarchy remote, and pacman ignores
upstream Omarchy content packages so they cannot replace BLARCHY-owned files.

## Working with upstream

Basecamp/Omarchy remains a development remote named `upstream`:

```bash
git fetch upstream
git merge upstream/quattro
```

Rebase or cherry-pick instead when that better fits the change. Upstream is
incorporated deliberately; it is never used by the normal BLARCHY runtime
update path.

## Repository map

```text
bin/          commands and update helpers
config/       BLARCHY user configuration defaults
default/      shared application, shell, boot, and theme defaults
install/      system and per-user setup leaves
shell/        the retained Quickshell desktop
test/         CLI, shell, and graphical acceptance coverage
```

## Credits

BLARCHY is based on [Omarchy](https://github.com/basecamp/omarchy) and preserves
its project history, copyright notices, and attribution. BLARCHY modifications
are released under the [MIT License](./LICENSE).
