# BLARCHY file layout

This document describes the supported standalone installation from this
repository. Inherited Omarchy package/ISO files remain in the tree for upstream
merge compatibility, but they are not a second BLARCHY installation model.

## Mental model

BLARCHY has three layers:

1. **Arch and the AUR own packages.** `install/omarchy-base.packages` is the
   desired package list and `yay` resolves it through normal Arch/AUR sources.
2. **The user's Git clone owns BLARCHY source.** `./install.sh` links that clone
   into the runtime and installs stable system integration files.
3. **The user owns their home configuration.** A normal install copies only
   missing defaults. Explicit resync is destructive and separate.

The inherited `omarchy-*`, `$OMARCHY_PATH`, `~/.config/omarchy`, and
`omarchy.*` plugin namespaces are compatibility APIs. They do not mean the
machine is installed or updated as Omarchy.

## Standalone install map

```text
Git checkout
├── install.sh                         package + setup orchestrator
├── install/omarchy-base.packages      canonical package manifest
├── install/standalone/system.sh       root-owned system integration
├── install/standalone/user.sh         preserve/overwrite user seeding
├── bin/omarchy*                       retained command API
├── config/**                          user configuration defaults
├── default/**                         shared runtime/system defaults
├── shell/**                           BLARCHY Quickshell desktop
├── themes/**                          first-party themes
└── migrations/**                      per-user source migrations
```

`install/standalone/system.sh` creates or installs:

```text
/usr/share/omarchy -> <user's BLARCHY checkout>
/usr/local/bin/omarchy* -> <checkout>/bin/omarchy*
/etc/omarchy.conf                    OMARCHY_PATH compatibility environment
/etc/blarchy.conf                    standalone installation marker
/etc/profile.d/omarchy.sh            login environment bootstrap
/usr/share/uwsm/env.d/10-omarchy     graphical-session environment
/usr/share/wayland-sessions/omarchy.desktop
/usr/lib/systemd/user/**              BLARCHY user units
/usr/lib/firefox/distribution/policies.json
/etc/pam.d/omarchy-lock-password
/usr/share/{fonts,fontconfig,sddm,icons,pixmaps}/...
```

Those inherited filenames are stable runtime identifiers. User-visible labels
inside them should say BLARCHY.

The system leaf enables common desktop services when available, preserves an
existing display manager, and preserves an existing network stack. It does not
partition, mount, configure a bootloader, write EFI state or `/boot`, replace
pacman configuration, or directly rebuild an initramfs. See
[`standalone-install.md`](standalone-install.md) for the full ownership contract.

## User defaults and finalization

On a normal install, `install/standalone/user.sh preserve` copies only missing
files from:

```text
config/**                              -> ~/.config/**
etc/fastfetch/config.jsonc             -> ~/.config/fastfetch/config.jsonc
default/applications/mimeapps.list     -> ~/.config/mimeapps.list
default/nautilus-python/extensions/**  -> ~/.local/share/nautilus-python/extensions/**
default/hypr/toggles/flags.lua         -> ~/.local/state/omarchy/toggles/hypr/flags.lua
icon.txt and logo.txt                  -> ~/.config/omarchy/branding/**
```

It also appends one marker-delimited BLARCHY bootstrap block to `~/.bashrc`.
Rerunning the installer does not duplicate that block or overwrite existing
user files.

`bin/omarchy-finalize-user` then handles state that needs the live user,
including XDG directories and MIME defaults, application defaults, generated
launchers, skill links, dock pins, theme state, and per-user setup leaves under
`install/user/`.

`bin/omarchy-first-run` performs tasks that need a graphical session and a
working user systemd instance. Completion markers live under
`~/.local/state/omarchy/done/`.

`bin/omarchy-reinstall-configs` is the explicit destructive resync. It calls the
user seeder in `overwrite` mode and reruns finalization; it does not touch the
boot chain.

## Runtime environment

`default/bash/env-bootstrap` is the source of truth for `$OMARCHY_PATH`.
`/etc/omarchy.conf` points it at the user's clone; `/usr/share/omarchy` is a
compatibility symlink to the same checkout. The checkout's `bin/` is available
through `/usr/local/bin/omarchy*` links and may also be prepended while using a
development link.

The environment bootstrap is sourced by login shells, the bash configuration,
and the UWSM session. Runtime code should consume `$OMARCHY_PATH`; it should not
guess a checkout path from `$HOME`.

## Updates and migrations

Normal package updates are simply:

```bash
yay -Syu
```

They do not mutate the Git checkout. BLARCHY source changes are deliberate:

```bash
cd ~/blarchy
git pull --ff-only
./install.sh
```

The installer runs pending standalone-safe migrations after a source update.
Migration state is per-user under `~/.local/state/omarchy/migrations/`. See
[`migrations.md`](migrations.md).

## Where new work belongs

| Goal | Source location |
| --- | --- |
| Default package | `install/omarchy-base.packages` |
| Root-owned standalone integration | `install/standalone/system.sh` or a sourced standalone leaf |
| Default file under `~/.config` | `config/` |
| Per-user runtime setup | `install/user/` and `bin/omarchy-finalize-user` |
| First graphical-login setup | `install/user/first-run/` and `bin/omarchy-first-run` |
| User-facing command | `bin/omarchy-<group>-<verb>` |
| One-time repair after a source update | `migrations/<unix-timestamp>.sh` |
| Quickshell code | `shell/` |
| Stock theme | `themes/<name>/` and, when needed, `default/themed/` |
| System file copied by the standalone installer | `default/` or `etc/`, plus an explicit install line in `install/standalone/system.sh` |

Do not add a new dependency on `omarchy-pkgs`, `omarchy-settings`, a private
package repository, an ISO finalizer, or package-seeded `/etc/skel` state.

## Retained upstream-only code

The following areas came from Omarchy's ISO/package architecture and are not
called by BLARCHY's supported installer unless a standalone script explicitly
adopts an individual safe component:

- `bin/omarchy-setup-system`, `bin/omarchy-setup-hardware`, and
  `bin/omarchy-upgrade-to-quattro`;
- `install/config/`, `install/hardware/`, `install/login/`, and
  `install/post-install/`;
- `default/limine/`, `default/snapper/`, `default/plymouth/`, and inherited
  libalpm update machinery.

Keep this code isolated for practical upstream merges. Do not document it as a
BLARCHY release path, and do not route the standalone installer through it
without removing assumptions about an ISO chroot, private packages, Limine,
Snapper, `/etc/skel`, and boot ownership.
