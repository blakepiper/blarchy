# Installation contract

Clone this repository on an already bootable minimal Arch Linux system and run
`./install.sh` as the intended desktop user.

The machine must already have working storage, networking, a kernel,
bootloader, firmware, and a non-root account with sudo access. The installer
does not partition, format, mount, write under `/boot`, create EFI entries,
configure a bootloader, or directly rebuild the initramfs.

## What the installer owns

- Arch and AUR packages listed in `install/packages`;
- `rustup` plus a stable toolchain for reproducible AUR builds;
- a copied runtime at `/usr/local/share/rice`;
- helper links in `/usr/local/bin`;
- the personal Hyprland session, SDDM theme, fonts, and user services;
- missing user configuration and application defaults.

Existing user files are preserved during a normal run. Existing network and
display managers are also preserved when configured. The installer enables
NetworkManager or SDDM only when the machine does not already use an
alternative.

## Rust provider

Arch packages `rust`, `cargo`, and `rustfmt` conflict with the `rustup`
provider. The installer requests `rustup` in the same pacman transaction as
its other build prerequisites. When a conflicting native provider is already
installed, that one transaction is interactive so pacman can ask to replace
it atomically; otherwise it remains non-interactive. The installer then
initializes the stable toolchain only when no default toolchain exists. The
provider remains installed; it is not removed between AUR builds.

## Reproducing and updating

Rerunning `./install.sh` is idempotent: packages use `--needed`, the runtime
is published atomically, fixed system paths are reused, and existing user files
are skipped.

Use `yay -Syu` for normal Arch and AUR updates. There is no repository updater,
release channel, version command, or migration framework. After changing or
pulling this repository, rerun `./install.sh` when you want to republish its
runtime or install newly declared packages.
