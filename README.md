<div align="center">
  <img src="./logo.svg" alt="BLARCHY" width="1095" style="display: block; max-width: 100%; height: auto;">
</div>

<p align="center">
  <strong>Blake's Arch + Niri Environment</strong><br>
  A minimal, reproducible, keyboard-first Arch desktop built on Niri.
</p>

---

Blarchy turns an already bootable minimal Arch system into a fully
configured Niri desktop: compositor, bar, launcher, notifications,
lock screen, terminal, applications, shell tools, keybindings, and
hardware-specific drivers.

It is not a Linux distribution or an OS installer. Arch owns the base
system and packages; this repository owns the desktop layered on top.

## Install

Start with Arch installed via the `archinstall` helper on the Arch ISO
(base system, no desktop environment). Boot into it, connect to wifi,
and as your normal user:

```bash
sudo pacman -S --needed git
# set up git credentials if you have not yet:
#   git config --global user.name "Your Name"
#   git config --global user.email "you@example.com"
git clone https://github.com/blakepiper/blarchy.git ~/blarchy
cd ~/blarchy
./install.sh
```

The installer:

- enables Arch multilib (Steam, NVIDIA lib32 drivers);
- installs `rustup` with a stable toolchain and bootstraps `yay`;
- investigates your hardware (CPU, GPU, laptop vs desktop, Bluetooth,
  VM guest, fingerprint reader, wifi) and adds exactly the drivers and
  tools it finds — see [docs/HARDWARE.md](./docs/HARDWARE.md);
- installs the pacman packages in [`install/packages`](./install/packages)
  plus the AUR packages in [`install/packages-aur`](./install/packages-aur);
- sets up `greetd` + `tuigreet` as the login screen (keeping an existing
  display manager if one is already enabled);
- enables NetworkManager, printing, and the hardware-appropriate
  Bluetooth and power services;
- seeds repository defaults into `~/.config` without overwriting your
  existing files.

Rerunning `./install.sh` is supported and safe.

The installer never partitions, formats, mounts, configures a
bootloader, writes EFI entries, or writes under `/boot`. On NVIDIA
machines it prints a reminder to add `nvidia-drm.modeset=1` to your
bootloader kernel parameters yourself.

## Everyday updates

Everything, including AUR packages like `prettymux-bin`, updates
normally:

```bash
yay -Syu
```

To pick up newer repository configuration, update the checkout and
rerun the installer:

```bash
cd ~/blarchy
git pull --ff-only
./install.sh
```

## Default desktop

| Role | Default |
| --- | --- |
| Compositor | Niri (scrollable tiling) |
| Login | greetd + tuigreet |
| Bar | Waybar (workspaces, AI usage, audio, network, battery, tray) |
| Launcher | fuzzel |
| Notifications | mako |
| Lock / idle | swaylock + swayidle (locks after 10 min) |
| Wallpaper | swaybg (solid color; point it at an image in `config/niri/config.kdl`) |
| Terminal | kitty |
| Multiplexer | prettymux (`Super` + `Shift` + `Enter`) and tmux |
| Browser | Firefox |
| File manager | Nautilus |
| Editor | VSCodium (`codium`) and Neovim |
| Audio | PipeWire and WirePlumber |
| AI usage widget | `ai-usage` in the bar (Claude Code, Codex, OpenCode Go) |
| Packages | pacman and yay |

## Main shortcuts

`Super` is the `Mod` key.

| Shortcut | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>Enter</kbd> | kitty |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Enter</kbd> | prettymux |
| <kbd>Super</kbd> + <kbd>Space</kbd> or <kbd>Super</kbd> + <kbd>D</kbd> | fuzzel launcher |
| <kbd>Super</kbd> + <kbd>C</kbd> | VSCodium |
| <kbd>Super</kbd> + <kbd>F</kbd> | Nautilus |
| <kbd>Super</kbd> + <kbd>B</kbd> | Firefox |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close window |
| <kbd>Super</kbd> + <kbd>O</kbd> | Overview |
| <kbd>Super</kbd> + <kbd>P</kbd> | Toggle floating |
| <kbd>Super</kbd> + <kbd>L</kbd> | Lock screen |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Region screenshot (saved to `~/Pictures/Screenshots` and copied to clipboard) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>F</kbd> | Fullscreen |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Previous workspace |
| <kbd>Super</kbd> + <kbd>1..9</kbd> | Go to workspace |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>1..9</kbd> | Send window to workspace |
| <kbd>Super</kbd> + arrows | Focus window/column |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + arrows | Move window/column |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + arrows | Focus monitor |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + arrows | Send window to monitor |
| <kbd>Super</kbd> + <kbd>-</kbd> / <kbd>=</kbd> | Shrink / grow column |
| <kbd>Super</kbd> + <kbd>,</kbd> / <kbd>.</kbd> | Consume / expel window |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>E</kbd> | Quit Niri |

Media, volume, and brightness keys work out of the box.

## AI usage widget

The bar's `AI %` module shows the remaining quota of your most-consumed
AI subscription window across Claude Code, Codex, and OpenCode Go, with
per-provider details and today's local token/prompt counts in the
tooltip. It refreshes every five minutes and caches under
`~/.cache/blarchy/ai-usage/`.

- Left-click opens the full breakdown in kitty.
- Right-click forces a refresh.
- `ai-usage details` and `ai-usage refresh` do the same from a terminal.

## Optional extras

```bash
yay -S steam spotify   # gaming and music, one command away (multilib is ready)
```

## Repository map

```text
bin/          ai-usage widget and its scanners
config/       user configuration defaults (niri, kitty, waybar, fuzzel, ...)
docs/         hardware detection notes
etc/          system files installed by the installer (greetd)
install/      package manifests, hardware detection, system/user setup
test/         smoke checks runnable on any machine
install.sh    the installer
```
