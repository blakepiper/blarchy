# Standalone installation contract

BLARCHY installs onto an existing Arch Linux system. It is a desktop and
configuration layer, not an operating-system installer.

## User-owned prerequisites

Before running `./install.sh`, the user owns and validates:

- partitioning, formatting, encryption, and mounts;
- the kernel, initramfs strategy, and firmware needed to boot;
- GRUB, systemd-boot, rEFInd, Limine, or another bootloader;
- dual-boot detection and boot-menu policy;
- a working network connection;
- a non-root login with sudo access.

BLARCHY does not inspect or "repair" those choices.

## Installer-owned state

The installer may:

- enable Arch's standard multilib repository for Steam;
- install official Arch and AUR packages with pacman/yay;
- create `/usr/share/omarchy` as a symlink to the cloned checkout;
- write `/etc/omarchy.conf` with the checkout path;
- record the standalone ownership model in `/etc/blarchy.conf`;
- expose `omarchy-*` commands through `/usr/local/bin` symlinks;
- install the BLARCHY UWSM session, SDDM theme, fonts, systemd user units, and
  environment integration;
- install the Firefox policy and dedicated BLARCHY lock-screen PAM service;
- enable SDDM only when another display manager is not already selected;
- enable NetworkManager only when another network stack is not already enabled;
- seed missing user configuration and set BLARCHY application defaults.

Initial user finalization is safe from the minimal Arch console: it writes XDG
MIME/default files directly and does not require a running desktop notification
service. Graphical-only setup is deferred to the first BLARCHY login.

The checkout should remain at a stable path after installation. Moving it is
supported by rerunning `./install.sh` from the new location.

When multilib is initially disabled in the stock Arch form, the installer
saves `/etc/pacman.conf.blarchy-before-multilib` before uncommenting that one
repository block. Existing custom repositories and mirror selection are left
alone.

## Explicit non-goals

The installer never:

- runs `fdisk`, `parted`, `mkfs`, or mount operations;
- changes a partition table or filesystem;
- installs or configures a bootloader;
- writes EFI/NVRAM boot entries;
- writes under `/boot`;
- calls `grub-install`, `bootctl`, `limine-install`, or `efibootmgr`;
- changes mkinitcpio hooks or directly rebuilds the initramfs;
- replaces `/etc/pacman.conf` or the user's mirrorlist;
- overwrites existing user configuration on a normal install.

Boot and disk utilities retained from upstream are not exposed through the
default BLARCHY menu and are not called by the standalone installer.

Pacman may update an already-installed kernel and run its standard package
hooks, including an initramfs rebuild. That is normal Arch package ownership;
BLARCHY itself does not configure or invoke the boot chain.

## Idempotency

Rerunning `./install.sh` converges rather than duplicates:

- pacman/yay receive `--needed`;
- system integration is installed at fixed BLARCHY-owned paths;
- command and runtime links are replaced atomically with the same targets;
- existing user files are skipped;
- the `.bashrc` integration block has stable start/end markers;
- finalization and graphical first-run steps use state markers.

`omarchy-reinstall-configs` remains an explicit destructive reset for
BLARCHY-owned user configuration. It no longer modifies Limine, Plymouth,
EFI, or initramfs state.

Migrations that declare `# blarchy:standalone-safe=false` are excluded on a
standalone installation. This keeps retained ISO-era hardware and Limine
repairs available to their original path without allowing the normal BLARCHY
update to take ownership of the user's boot stack.

## Updates after installation

Use ordinary Arch tooling:

```bash
yay -Syu
```

This updates official and AUR packages without invoking a BLARCHY-specific
pipeline. Yay's development-package checks are enabled during installation so
installed `*-git` packages participate. The BLARCHY Git checkout remains pinned
until the user explicitly pulls it and reruns `./install.sh`; rerunning applies
pending standalone-safe migrations.

## Package resolution

`install/omarchy-base.packages` is the canonical desired package list. Every
entry resolves through the normal Arch repositories or the AUR. Omarchy-only
packages with no public package source are omitted, and public equivalents use
their actual Arch/AUR names (`neovim`, `ttf-jetbrains-mono-nerd`, and
`hyprland-preview-share-picker-git`). BLARCHY does not add or trust the Omarchy
package repository or keyring.
