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
- installs build prerequisites and bootstraps `yay` for AUR packages;
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
| Bar | Waybar (workspaces, night mode, caffeinate, AI usage, audio, network, battery, tray) |
| Launcher | fuzzel |
| Notifications | mako |
| Lock / idle | swaylock + swayidle (locks after 10 min) |
| Wallpaper | swaybg (bundled Ubuntu wallpaper at `~/.config/swaybg/wallpaper.jpg`) |
| Terminal | kitty (Ubuntu aubergine theme) |
| Multiplexer | prettymux (`Super` + `Shift` + `Enter`) and tmux |
| Browser | Firefox |
| File manager | Nautilus |
| Editor | VSCodium (`codium`) and Neovim |
| Audio | PipeWire and WirePlumber |
| AI usage widget | `ai-usage` in the bar (Claude Code, Codex, OpenCode Go) |
| AI coding agents | Claude Code (`claude`), Codex (`codex`), pi (`pi`), OpenCode (`opencode`) |
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
| <kbd>Super</kbd> + <kbd>N</kbd> | Cycle night mode off → night → night-plus |
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

## Night mode and caffeinate

Two toggles sit in the center of the bar, next to the clock:

- **Night mode** (sun/moon icon) warms the screen through `gammastep`.
  Click it — or press <kbd>Super</kbd> + <kbd>N</kbd> — to cycle
  off → night (3500 K) → night-plus (2200 K). The mode lasts for the
  login session; a fresh boot starts with it off.
- **Caffeinate** (coffee icon) inhibits idle sleep while active, so the
  screen neither locks nor powers off. Click again to release it.

Both reflect their state in the bar immediately.

## External monitors

Niri hotplugs displays automatically: plugging in a monitor just works,
with no installer step or reboot. The installer's hardware check reports
every connected output it sees, using the same connector names Niri uses.

Run `displays` any time to list connector names, preferred modes, and a
ready-to-paste `output` block:

```sh
displays
```

Then pin arrangement details in `~/.config/niri/config.kdl` — for
example, forcing a high-refresh mode on a 1440p panel to the right of
the laptop screen:

```kdl
output "HDMI-A-1" {
    mode "2560x1440@143.912"
    position x=0 y=0
}
```

Niri applies config changes on save. Common notes:

- 1440p panels are happiest at the default scale `1.0`; 4K panels
  usually want `scale 2.0`.
- `position` uses logical pixels after scaling, so neighbors of a
  scaled panel must account for its logical (not physical) width.
- Unsure of a name or mode? `displays` lists exactly what Niri sees.

## Optional extras

```bash
yay -S steam spotify   # gaming and music, one command away (multilib is ready)
```

## Repository map

```text
bin/          desktop helpers (ai-usage, night-mode, displays)
config/       user configuration defaults (niri, kitty, waybar, fuzzel, ...)
docs/         hardware detection notes
etc/          system files installed by the installer (greetd)
install/      package manifests, hardware detection, system/user setup
test/         smoke checks runnable on any machine
install.sh    the installer
```
