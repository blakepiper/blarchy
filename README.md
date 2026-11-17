<div align="center">
  <img src="./logo.svg" alt="Blarchy" width="700" style="display: block; max-width: 100%; height: auto;">
</div>

# Blarchy

Blarchy configures a fresh Arch Linux installation with Hyprland,
Quickshell, Wofi, Ghostty, and a small set of desktop applications. It does not
install Arch, partition disks, or configure a bootloader.

## Install

Install Arch with `archinstall` using a base profile without a desktop. Create
a regular user with sudo access, configure networking, reboot, and log in at
the TTY. Then clone this repository and run the installer as that user:

```bash
sudo pacman -Syu --needed git
git clone https://github.com/blakepiper/blarchy.git ~/blarchy
cd ~/blarchy
./install.sh
```

The installer updates Arch, installs official packages from
[`install/packages`](install/packages), resolves hardware-specific drivers,
installs the small AUR set in [`install/packages-aur`](install/packages-aur),
and configures system and user defaults. It does not start a display manager.
After installation, reboot, log in at the TTY, and run:

```bash
start-hyprland
```

Run `./install.sh` again to retry a failed installation. Existing files under
`~/.config` are preserved; repository defaults only fill missing files.
The installer targets fresh Arch systems, not desktop conversions.

## Packages and updates

Official Arch packages are installed and updated with pacman. Codex is
installed from the official repositories. The AUR list is limited to
`blesh-git`, `tamsyn-font`, and `terminus-font-ttf`; yay is bootstrapped only
to manage those exceptions.

```bash
sudo pacman -Syu
yay -Syu
```

No package versions are pinned, and there is no repository self-updater.

## Desktop

| Role | Program |
| --- | --- |
| Compositor | Hyprland |
| Bar and controls | Quickshell |
| Launcher and menus | Wofi |
| Notifications | mako |
| Terminal | Ghostty |
| Shell prompt | Starship |
| Lock and idle | hyprlock and hypridle |
| Wallpaper | swaybg with a solid dark background |
| Editor | vanilla Neovim with an empty `init.lua` |
| Project workspace | tmux through `dev` |
| System information | fastfetch |

The Ghostty defaults are in [`config/ghostty/config`](config/ghostty/config).
The Starship prompt is configured in [`config/starship.toml`](config/starship.toml).
Neovim starts without a plugin manager or repository-provided settings.

HyprGlass materials are optional. Build the plugin for the installed Hyprland
version and set `HYPRGLASS_PLUGIN` to its absolute library path before starting
Hyprland to enable the configured glass presets. The regular layer blur and
opacity rules work without the plugin.

## Keyboard controls

| Shortcut | Action |
| --- | --- |
| Super + Enter | Ghostty |
| Super + Space or Super + D | Application launcher |
| Super + Shift + Space | Lock, suspend, reboot, logout, monitor, and power controls |
| Super + S | Audio, network, Bluetooth, power, and display settings |
| Super + F / Super + B | File manager / Firefox |
| Super + Q / Super + Shift + Q | Close window / exit Hyprland |
| Super + arrows | Focus windows |
| Super + Shift + arrows | Move windows |
| Super + Ctrl + Left/Right | Focus another monitor |
| Super + 1–9 | Select workspace |
| Super + Shift + 1–9 | Move window to workspace |
| Super + L | Lock |
| Super + Shift + S / Print | Select screenshot / capture all displays |
| Super + V | Clipboard history |
| Super + N | Cycle night-light strength |

The external USB keyboard rule swaps its Command and Alt/Windows positions so
Command acts as Super. Built-in and Bluetooth keyboards keep their own mappings.

## Displays and dock behavior

Hyprland handles display hotplug. When an internal laptop panel and an external
display are connected, the monitor config mirrors the panel to the first
external output at 8-bit depth for dock compatibility. It debounces duplicate
connector events and releases the mirror source before applying a new mirror
direction. Systems without an internal panel keep Hyprland's normal display
layout. `displays` reports active Hyprland outputs or connected DRM connectors
from a TTY.

The older XRandR-only dock workarounds are not installed into this Wayland
session. They depended on XRandR mode setting and do not apply to Hyprland.

## Hardware and system setup

[`install/hardware.sh`](install/hardware.sh) detects CPU, GPU, laptop, Bluetooth,
virtual-machine, fingerprint-reader, and display information. It adds only the
matching firmware, graphics drivers, guest tools, Bluetooth tools, and laptop
power packages. It does not write under `/boot` or alter disk layout.

System integration is in [`install/system.sh`](install/system.sh); per-user
defaults and helper installation are in [`install/user.sh`](install/user.sh).
Desktop helpers in `bin/` are copied to `~/.local/bin` and referenced by their
full path from the compositor configuration.

## Verification

Run the offline smoke checks with:

```bash
./test/smoke
```

Graphical acceptance requires a disposable Arch VM installed through the
current `./install.sh`.
