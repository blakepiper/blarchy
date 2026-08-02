<div align="center">
  <samp>
&nbsp;▄██████▄&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▄███████&nbsp;&nbsp;&nbsp;▄███████&nbsp;&nbsp;&nbsp;▄███████&nbsp;&nbsp;&nbsp;▄█&nbsp;&nbsp;&nbsp;█▄&nbsp;&nbsp;&nbsp;&nbsp;▄█&nbsp;&nbsp;&nbsp;█▄<br>
███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███<br>
███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;█▀&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███<br>
███▄▄▄██▀&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▄███▄▄▄███&nbsp;▄███▄▄▄██▀&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▄███▄▄▄███▄&nbsp;███▄▄▄███<br>
███▀▀▀██▄&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▀███▀▀▀███&nbsp;▀███▀▀▀▀&nbsp;&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▀▀███▀▀▀███&nbsp;&nbsp;▀▀▀▀▀▀███<br>
███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;██████████&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;█▄&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;▄██&nbsp;&nbsp;&nbsp;███<br>
███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███<br>
&nbsp;▀██████▀&nbsp;&nbsp;&nbsp;████████&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;█▀&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;███████▀&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;█▀&nbsp;&nbsp;&nbsp;&nbsp;▀█████▀<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;███&nbsp;&nbsp;&nbsp;█▀
  </samp>
</div>

<p align="center">
  <strong>Blake's Arch + Hyprland Environment</strong><br>
  A minimal, keyboard-first desktop with sensible mouse support.
</p>

<p align="center">
  <img alt="Version 0.2.0" src="https://img.shields.io/badge/version-0.2.0-8bd450?style=for-the-badge&labelColor=111111">
  <img alt="Arch Linux" src="https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white">
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-58E1FF?style=for-the-badge&logo=wayland&logoColor=111111">
  <a href="./LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-8bd450?style=for-the-badge&labelColor=111111"></a>
</p>

---

BLARCHY (Blake's Arch + Hyprland Environment) is a customized Arch + Hyprland
desktop environment based on [Omarchy](https://github.com/basecamp/omarchy).
It began as a personal Omarchy configuration and still retains ideas, code, and
compatibility names from that project. BLARCHY releases are now maintained
independently: installed systems do not automatically track Omarchy upstream.

BLARCHY is not a separate Linux distribution. Arch owns the operating system
and packages; BLARCHY owns the desktop defaults, installed runtime,
configuration, scripts, branding, migrations, and environment updates.

> [!NOTE]
> BLARCHY v0.2 keeps selected `omarchy-*`, `omarchy.*`, and
> `~/.config/omarchy` names as compatibility APIs. Those names acknowledge its
> ancestry; they do not make Omarchy an installed dependency.

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
installs the desktop packages, copies a stable BLARCHY runtime to
`/usr/local/share/blarchy`, installs session integration, and seeds missing
user configuration. The Git checkout remains source rather than the live
desktop. It is safe to rerun: package operations use `--needed`, managed system
files converge on the same state, existing user configuration is preserved,
missing application defaults are initialized without replacing existing
preferences, and one-time finalization uses completion markers.

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

System packages and the BLARCHY environment have separate update paths.

Update Arch and AUR packages with:

```bash
yay -Syu
# or: blarchy system update
```

BLARCHY does not block pacman, wrap yay, replace the user's package
configuration, pull Git source during a package transaction, or globally update
npm packages. The installer enables yay's development-package checks so
installed `*-git` packages participate too.

Update the independently maintained BLARCHY runtime, defaults, packages, and
migrations with:

```bash
blarchy update
```

The updater requires a clean configured source checkout whose tracked remote is
`github.com/blakepiper/blarchy`. It does not fetch or merge Omarchy. See
[the update model](./docs/update-process.md) for details.

## Working with upstream

Omarchy remains a useful source of ideas. A developer may keep it as a separate
remote and inspect changes manually:

```bash
git fetch upstream
git log --oneline upstream/quattro
```

Port or cherry-pick a useful change only after reviewing it against BLARCHY's
ownership model. This optional development workflow is never part of
`yay -Syu`, `blarchy update`, installation, login, or migration execution.

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
