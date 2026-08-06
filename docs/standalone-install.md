# Standalone installation contract

BLARCHY installs onto an existing Arch Linux system. It is a desktop and
configuration layer, not an operating-system installer.

## User-owned prerequisites

Before running `./install.sh`, the user owns and validates partitioning,
filesystems, encryption, mounts, kernel, firmware, networking, bootloader, and
a non-root login with sudo access. BLARCHY does not inspect or repair those
choices.

## Installer-owned state

The installer may:

- enable Arch's standard multilib repository for Steam;
- install official Arch and AUR packages with pacman/yay;
- install a copied BLARCHY runtime at `/usr/local/share/blarchy`;
- expose BLARCHY commands through `/usr/local/bin`;
- install the BLARCHY UWSM session, SDDM theme, fonts, systemd user units, and
  environment integration;
- configure SDDM to remember the invoking user's login and the installed BLARCHY
  UWSM session without enabling autologin;
- install the Firefox policy and dedicated BLARCHY lock-screen PAM service;
- enable SDDM only when another display manager is not already selected;
- enable NetworkManager only when another network stack is not already enabled;
- seed missing user configuration and set BLARCHY application defaults.

The source checkout is not the live runtime. It may be moved, switched to a
development branch, or contain uncommitted work without changing the installed
desktop. Publishing an update still requires the configured source worktree to
be clean. Rerun the installer or `blarchy update` to deliberately publish source
changes into the installed runtime.

Initial user finalization is safe from the minimal Arch console. Graphical-only
setup is deferred to the first BLARCHY login.

## Explicit non-goals

The installer never partitions, formats, mounts, configures a bootloader,
writes EFI/NVRAM entries, writes under `/boot`, replaces pacman repositories or
the mirrorlist, or directly rebuilds the initramfs. It does not overwrite
existing user configuration during a normal installation.

Pacman may update an already-installed kernel and run its standard package
hooks, including an initramfs rebuild. That is normal Arch package ownership;
BLARCHY itself does not configure or invoke the boot chain.

## Idempotency and user configuration

Rerunning `./install.sh` converges rather than duplicates:

- pacman/yay receive `--needed`;
- the installed runtime is staged and refreshed at a fixed path;
- commands and system integration use fixed BLARCHY-owned paths;
- existing user files are skipped;
- the `.bashrc` integration block has stable markers;
- finalization, migrations, and graphical first-run steps use completion state.

`omarchy-reinstall-configs` remains an explicit destructive reset for shipped
user configuration and must preserve unrelated files. Migrations that declare
`# blarchy:standalone-safe=false` remain excluded so BLARCHY cannot take over a
user's boot or snapshot stack.

## Updates after installation

Use `yay -Syu` or `blarchy system update` for package-only updates. `blarchy
update` runs that full Arch/AUR package update and then updates the BLARCHY
environment from `blakepiper/blarchy`, refreshes the installed runtime, and
applies pending BLARCHY-owned migrations. Neither path downloads or merges
Basecamp/Omarchy.

## Package resolution

The BLARCHY package manifest is the canonical desired package list. Every entry
resolves through normal Arch repositories or the AUR. BLARCHY does not add or
trust an Omarchy package repository or keyring. In particular, the unattended
installer owns the `rustup` provider required by its AUR build set. If an
existing Arch `rust`, `cargo`, or `rustfmt` package is present, pacman replaces it
with `rustup` in the same transaction rather than leaving a broken intermediate
state.
