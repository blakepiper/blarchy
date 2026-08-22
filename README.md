<div align="center">
  <img src="./logo.svg" alt="BLARCHY" width="1095" style="display: block; max-width: 100%; height: auto;">
</div>

<p align="center">
  <strong>Blake's Arch + Hyprland Environment</strong><br>
  A reproducible, keyboard-first Arch desktop with Hyprland and XFCE.
</p>

<p align="center">
  <img alt="Arch Linux" src="https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white">
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-58E1FF?style=for-the-badge&logo=wayland&logoColor=111111">
  <a href="./LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-8bd450?style=for-the-badge&labelColor=111111"></a>
</p>

---

BLARCHY is the configuration and installer for Blake's Arch Linux desktop. It
turns an already bootable minimal Arch system into the same working environment:
Hyprland and XFCE sessions, an SDDM login screen, desktop applications, shell
tools, themes, keybindings, and user defaults.

It is not a Linux distribution or an operating-system installer. Arch owns the
base system and packages; this repository owns the desktop configuration layered
on top of it.

## Install

Start with a bootable Arch Linux system that already has:

- a kernel, firmware, filesystems, and a bootloader;
- working networking;
- a non-root user with `sudo` access.

Then clone the repository as the user who will use the desktop:

```bash
sudo pacman -S --needed git
git clone https://github.com/blakepiper/blarchy.git ~/blarchy
cd ~/blarchy
./install.sh
```

The installer:

- enables Arch multilib for Steam;
- installs `rustup` and initializes a stable Rust toolchain for AUR builds;
- bootstraps yay when it is missing;
- installs the Arch and AUR packages in [`install/packages`](./install/packages);
- publishes a copied runtime at `/usr/local/share/rice`;
- installs the Hyprland and XFCE session entries plus SDDM system integration;
- seeds missing user configuration without overwriting existing files;
- preserves an existing display manager or network stack when one is already
  configured.

Rerunning `./install.sh` is supported. Package installation uses `--needed`,
managed system files converge on the repository state, and normal runs preserve
existing user preferences.

The installer never partitions, formats, mounts, configures a bootloader, writes
EFI entries, writes under `/boot`, or directly rebuilds the initramfs. See the
[installation contract](./docs/standalone-install.md) for the exact boundary.

## Sessions and locking

SDDM's animated
[`hyprland_kath`](https://github.com/Keyitdev/sddm-astronaut-theme) greeter
offers exactly **Hyprland** (Wayland) and **Xfce Session** (X11). It remembers
the most recent selection.

In either desktop, <kbd>Super</kbd> + <kbd>L</kbd> locks the current session and
opens the SDDM greeter. Its session dropdown can select Hyprland or XFCE without
logging out of the locked session first. Hyprland also provides
<kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>L</kbd> when only a normal lock is wanted.

## Everyday updates

Arch repository and AUR packages are updated normally:

```bash
yay -Syu
```

Package updates do not modify the Git checkout. To copy newer repository
configuration onto a machine, update the checkout and rerun the installer:

```bash
cd ~/blarchy
git pull --ff-only
./install.sh
```

The checkout is source; `/usr/local/share/rice` is the installed runtime used by
the desktop.

## Default desktop

| Role | Default |
| --- | --- |
| Sessions | Hyprland and XFCE |
| Login and session switching | SDDM Astronaut `hyprland_kath` with a session dropdown |
| Shell | Quickshell top bar, launcher, menus, and notifications |
| Terminal | Alacritty |
| Browser | Firefox with uBlock Origin |
| File managers | Nautilus and Thunar |
| Editor | VSCodium |
| Dock | `nwg-dock-hyprland` |
| Audio | PipeWire and WirePlumber |
| Packages | pacman and yay |

## Main Hyprland shortcuts

| Shortcut | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Application launcher |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>Space</kbd> | Desktop menu |
| <kbd>Super</kbd> + <kbd>Enter</kbd> | Alacritty |
| <kbd>Super</kbd> + <kbd>C</kbd> | VSCodium |
| <kbd>Super</kbd> + <kbd>F</kbd> | Nautilus |
| <kbd>Super</kbd> + <kbd>B</kbd> | Firefox |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close the focused window |
| <kbd>Super</kbd> + <kbd>L</kbd> | Lock and open the session greeter |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Region screenshot |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>F</kbd> | Full screen |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Previous workspace |
| <kbd>Super</kbd> + arrow | Snap the focused window |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + arrow | Move focus in that direction |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + arrow | Move the window to another monitor |

Screenshots are saved under `~/Pictures/Screenshots` and copied to the
clipboard. Run `omarchy menu keybindings` to browse the complete active binding
set.

## Configuration and compatibility names

The installer seeds defaults into `~/.config` only when files are missing. The
main user-owned locations are:

```text
~/.config/hypr/                 Hyprland overrides
~/.config/omarchy/shell.json   Quickshell configuration
~/.config/omarchy/themes/      User themes
~/.config/alacritty/           Terminal configuration
```

The inherited `omarchy` command, `omarchy-*` helper names,
`~/.config/omarchy`, and `omarchy.*` plugin IDs remain compatibility interfaces.
The installed runtime itself uses `RICE_PATH=/usr/local/share/rice`.

## Repository map

```text
bin/          desktop commands and helpers
config/       user configuration defaults
default/      application and system-integration defaults
install/      package manifest plus system and per-user setup
shell/        Quickshell desktop
test/         CLI, shell, and graphical acceptance coverage
```
