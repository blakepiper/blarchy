<div align="center">
  <img src="./logo.svg" alt="BLARCHY" width="1095" style="display: block; max-width: 100%; height: auto;">
</div>

<p align="center">
  <strong>Blake's Arch + Niri Environment</strong><br>
  A minimal, reproducible, keyboard-first Arch desktop built on Niri.
</p>

---

Blarchy turns a fresh, bootable minimal Arch installation into a fully
configured Niri desktop: compositor, bar, launcher, notifications,
lock screen, terminal, applications, shell tools, keybindings, and
hardware-specific drivers.

It is not a Linux distribution or an OS installer. Arch owns the base
system and packages; this repository owns the desktop layered on top.

## Install

### 1. Install the Arch base system

If you have not installed Arch yet, boot the
[Arch installation ISO](https://archlinux.org/download/), get online, and run
`archinstall`. The [archinstall guide](https://github.com/archlinux/archinstall)
covers the base installation. For Blarchy, choose:

- a minimal installation profile, with no desktop environment;
- a normal user account with a password and **sudo / superuser access**;
- NetworkManager in the network configuration settings, so you can connect
  after rebooting;
- your preferred language, keyboard layout, timezone, and disk setup.

Remember the username and password you create. When installation finishes,
reboot and remove the USB installer so the computer boots from its installed
drive. The remaining steps run on that installed system, not inside the ISO
or an `arch-chroot` session.

### 2. Log in and check sudo access

A text-only login prompt is expected: Blarchy will install the graphical
desktop. At `login:`, type the normal username you created, press Enter,
then enter its password. Linux does not display characters or asterisks
while you type a login or sudo password.

Check that you are using the right account and can run administrative commands:

```bash
whoami
sudo -v
```

`whoami` should print your username, not `root`. `sudo -v` may ask for your
user password; returning to the prompt without an error means it worked.
If you logged in as root, type `exit` and log in as your normal user instead.
If sudo is missing or says your user is not allowed to use it, resolve your
[sudo setup](https://wiki.archlinux.org/title/Sudo#Configuration) before continuing.

### 3. Connect to the internet

For Ethernet, plug in the cable. If your installation already remembered
your Wi-Fi connection, you may also be online already. Check with:

```bash
ping -c 3 archlinux.org
```

Replies confirm connectivity and name resolution. If it works, skip to
step 4. If it fails and you need Wi-Fi, use the NetworkManager installed
in step 1:

```bash
sudo systemctl enable --now NetworkManager
sudo nmcli radio wifi on
nmcli device wifi list
sudo nmcli --ask device wifi connect "Your Wi-Fi Name"
```

Replace `Your Wi-Fi Name` with the network name shown in the list, keeping
the quotes if it contains spaces. Enter the Wi-Fi password when prompted.
`--ask` keeps the password out of your shell history. Run the ping check
again once connected. More examples are in the
[NetworkManager documentation](https://networkmanager.dev/docs/api/latest/nmcli-examples.html).

<details>
<summary>Already installed Arch using “copy ISO network configuration” / iwd?</summary>

Use the networking you already installed; do not enable a second network
manager for the same interface. If your copied connection is not working,
start iwd and open its interactive prompt:

```bash
sudo systemctl start iwd
sudo iwctl
```

At the `[iwd]#` prompt, enter these commands one at a time. Replace `wlan0`
with the device name from `device list`, and replace the example network name:

```text
device list
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "Your Wi-Fi Name"
exit
```

Enter your Wi-Fi password when asked, then retry `ping -c 3 archlinux.org`
at the normal shell prompt. See the [iwctl manual](https://man.archlinux.org/man/iwctl.1)
for more details. Connecting to Wi-Fi also needs working IP and DNS setup;
archinstall's copied ISO network configuration supplies that setup.

</details>

If `nmcli` and `iwctl` are both missing and you have no connection, Blarchy
cannot download packages yet. Use a working wired connection, or boot the
Arch ISO to [repair the installed system's networking](https://wiki.archlinux.org/title/Installation_guide#Network_configuration).
Installing a Wi-Fi tool on the live ISO alone does not install it on your drive.

### 4. Download and run Blarchy

Install Git, then download this repository into your home directory:

```bash
sudo pacman -Syu --needed git
git clone https://github.com/blakepiper/blarchy.git ~/blarchy
cd ~/blarchy
./install.sh
```

Run these commands one at a time. Accept pacman's installation prompt when
asked. You do not need a GitHub account or Git author name/email to clone
this public repository.

Run `./install.sh` as your normal user, **without `sudo` in front of it**.
The installer asks for sudo access when needed. Keep the machine online
and, for a laptop, connected to power while it downloads and installs packages.

If you already cloned the repository during an earlier attempt, skip the
`git clone` command: run `cd ~/blarchy` and `./install.sh` to retry.

### 5. Reboot into the desktop

Wait for `Blarchy installation complete.` and read the final notes, including
the firewall reminder if you use SSH. Then run:

```bash
sudo reboot
```

Log in at the greetd prompt with the same username and password. Select Niri
if prompted for a session. Once the desktop appears, press **Super + Enter**
to open a terminal or **Super + Space** to launch an application. On most
keyboards, Super is the Windows-logo key.

### What the installer does

The installer:

- installs build prerequisites and bootstraps `yay` for AUR packages;
- investigates your hardware (CPU, GPU, laptop vs desktop, Bluetooth,
  VM guest, fingerprint reader, wifi) and adds exactly the drivers and
  tools it finds — see [docs/HARDWARE.md](./docs/HARDWARE.md);
- installs the pacman packages in [`install/packages`](./install/packages)
  plus the AUR packages in [`install/packages-aur`](./install/packages-aur);
- installs terminal-code from its upstream release because it is not in the
  AUR;
- sets up `greetd` + `tuigreet` as the login screen (keeping an existing
  display manager if one is already enabled);
- preserves archinstall networking or enables NetworkManager, plus the hardware-appropriate
  Bluetooth and power services;
- seeds repository defaults into `~/.config` without overwriting your
  existing files.

If an installation fails, fix the reported problem and rerun `./install.sh`.
Installed packages are reused, services are enabled idempotently, and shell
setup is added only once. Existing config files are preserved during retries.
Converting an existing desktop is outside the supported installation path.

The installer never partitions, formats, mounts, configures a
bootloader, writes EFI entries, or directly writes under `/boot`. Arch's
package hooks still perform normal kernel and initramfs updates.

The firewall takes effect after reboot with UFW's default incoming-deny,
outgoing-allow policy. If you need remote access, add a rule before rebooting
(for example, `sudo ufw allow 22/tcp` for standard SSH).

## Everyday updates

Everything, including AUR packages like `prettymux-bin`, updates
normally:

```bash
yay -Syu
```

Terminal-code is installed outside pacman and the AUR. Update it separately
with:

```bash
tode --upgrade
```

Package versions are not pinned: installation and retries fetch current Arch
and AUR metadata. You do not need to update this repository to get new app
versions. After installation, `yay -Syu` updates both Arch package sources;
use `tode --upgrade` for terminal-code.
The installer enables yay's development-package checks so `blesh-git`
also updates when its upstream source changes.

The repository supplies initial desktop defaults. Pulling changes and
rerunning does not replace existing files in `~/.config`; compare and merge
any desired configuration changes manually. There is no self-updater.

## Default desktop

| Role | Default |
| --- | --- |
| Compositor | Niri (scrollable tiling) |
| Login | greetd + tuigreet |
| Bar | Waybar (workspaces, CPU, memory, night mode, caffeinate, AI usage, audio, network, Bluetooth, battery, tray) |
| Launcher | fuzzel |
| Notifications | mako |
| Lock / idle | swaylock + swayidle (locks after 10 min) |
| Wallpaper | swaybg (bundled Ubuntu wallpaper at `~/.config/swaybg/wallpaper.jpg`) |
| Terminal | kitty (Ubuntu aubergine theme) |
| Multiplexer | prettymux (`Super` + `Shift` + `Enter`) |
| Browser | Firefox (uBlock Origin and Dark Reader pre-installed; sponsored content, recommended stories, and built-in AI disabled) |
| File manager | Nautilus |
| Editor | terminal-code (`tode`) and Neovim |
| Audio | PipeWire and WirePlumber |
| Battery | 80% charge limit on laptops with kernel charge-control support |
| AI usage widget | `ai-usage` in the bar (Claude Code, Codex, OpenCode Go) |
| AI coding agents | Claude Code (`claude`), Codex (`codex`), pi (`pi`), OpenCode (`opencode`) |
| Packages | pacman and yay |

## Application defaults and connections

GTK applications use Adwaita Dark, and applications that follow the desktop
color-scheme preference use dark mode. These are defaults, not locked settings;
individual application preferences can override them.

`~/.config/mimeapps.list` selects Firefox for web links, Papers for PDFs,
imv for common image formats, mpv for common video/audio formats, and Nautilus
for folders. Existing association files are preserved on retries.

Click the network indicator to open NetworkManager's `nmtui` menu in Kitty.
On installations using iwd instead, it opens `iwctl`; it never enables a
second network manager. Click the Bluetooth indicator to open Blueman for
pairing and managing devices. Bluetooth tools install only when an adapter
is detected, and the indicator is hidden when no controller is available.

The greetd password login unlocks the login keyring through optional PAM
hooks. Password changes through `passwd` also update the keyring password.
An existing keyring with a different password still needs to be unlocked
with its old password; the installer does not reset stored secrets.

## Terminal suggestions

Kitty opens Bash with [ble.sh](https://github.com/akinomyoga/ble.sh) enabled.
As you type, it shows a faint suggestion from your command history or shell
completion. At the end of the line, press **Right Arrow** to accept it,
then **Enter** to run the command. Keep typing to ignore the suggestion.
Suggestions run locally, without an AI service or account.

Settings live in `~/.config/blesh/init.sh`. Starship still provides the
prompt, and `yay -Syu` updates ble.sh through the `blesh-git` AUR package.

## Firefox defaults

uBlock Origin and Dark Reader install from Arch packages and update with
`yay -Syu`. Dark Reader can be toggled per site from its extension menu.

The installer places [Firefox policies](./etc/firefox/policies/policies.json)
in `/etc/firefox/policies/policies.json`. These disable sponsored shortcuts,
sponsored address-bar suggestions, and recommended stories. Firefox's
[AI controls](https://firefox-admin-docs.mozilla.org/reference/policies/aicontrols/)
block all covered AI features, including the chatbot, smart tab grouping,
link summaries, translations, and generated PDF alt text.

These settings are enforced while the policy file is installed. Restart
Firefox after changing it; `about:policies` shows active policies and errors.

## Main shortcuts

`Super` is the `Mod` key.

| Shortcut | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>Enter</kbd> | kitty |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Enter</kbd> | prettymux |
| <kbd>Super</kbd> + <kbd>Space</kbd> or <kbd>Super</kbd> + <kbd>D</kbd> | fuzzel launcher |
| <kbd>Super</kbd> + <kbd>C</kbd> | terminal-code |
| <kbd>Super</kbd> + <kbd>F</kbd> | Nautilus |
| <kbd>Super</kbd> + <kbd>B</kbd> | Firefox |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close window |
| <kbd>Super</kbd> + <kbd>O</kbd> | Overview |
| <kbd>Super</kbd> + <kbd>P</kbd> | Toggle floating |
| <kbd>Super</kbd> + <kbd>L</kbd> | Lock screen |
| <kbd>Super</kbd> + <kbd>N</kbd> | Cycle night mode off → night → night-plus |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Region screenshot (saved to `~/Pictures/Screenshots` and copied to clipboard) |
| <kbd>Super</kbd> + <kbd>V</kbd> | Clipboard history (choose an entry, then paste normally) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>F</kbd> | Maximize column |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Previous workspace |
| <kbd>Super</kbd> + <kbd>1..9</kbd> | Go to workspace |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>1..9</kbd> | Send column to workspace |
| <kbd>Super</kbd> + arrows | Focus window/column |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + arrows | Move window/column |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + arrows | Focus monitor |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + arrows | Send window to monitor |
| <kbd>Super</kbd> + <kbd>-</kbd> / <kbd>=</kbd> | Shrink / grow column |
| <kbd>Super</kbd> + <kbd>,</kbd> / <kbd>.</kbd> | Consume / expel window |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>E</kbd> | Quit Niri |

Media, volume, and brightness keys work out of the box.

For screenshots, select a region in Niri's screenshot interface and press
Enter to save and copy it, or Escape to cancel.

Clipboard history stores copied text and images. Press **Super + V**, search
or select an entry, and press Enter to copy it back to the clipboard. Paste
with the target application's usual shortcut. Escape leaves the clipboard
unchanged. To clear saved history, run `cliphist wipe`.

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
yay -S spotify   # optional music player
```

## Repository map

```text
bin/          desktop helpers (AI usage, night mode, displays, clipboard, network)
config/       user configuration defaults (niri, kitty, waybar, fuzzel, ...)
docs/         hardware detection notes
etc/          system defaults (greetd, Firefox policies, dark mode, battery limit)
install/      package manifests, hardware detection, system/user setup
test/         smoke checks runnable on any machine
install.sh    the installer
```
