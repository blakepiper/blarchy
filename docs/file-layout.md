# BLARCHY file layout

BLARCHY v0.2 separates source, installed runtime, and user-owned state. This is
the supported standalone installation model.

## Mental model

1. **Arch and the AUR own the operating system and packages.** Yay resolves the
   BLARCHY package manifest through normal public sources.
2. **The Git clone owns source.** It is where BLARCHY is reviewed and developed;
   the running desktop does not execute directly from it.
3. **The installed runtime owns shipped BLARCHY code and defaults.** The
   installer publishes a coherent copy under `/usr/local/share/blarchy`.
4. **The user owns their XDG configuration.** Normal installs seed only missing
   files; explicit reset and narrowly scoped migrations handle later changes.

The inherited `omarchy-*`, `$OMARCHY_PATH`, `~/.config/omarchy`, and
`omarchy.*` plugin namespaces remain compatibility APIs. They do not mean the
machine depends on or updates from Omarchy.

## Source tree

```text
Git checkout
├── install.sh                    package + setup orchestrator
├── install/**                    system and per-user setup
├── bin/**                        BLARCHY commands and compatibility routes
├── config/**                     user configuration defaults
├── default/**                    shared runtime/system defaults
├── shell/**                      BLARCHY Quickshell desktop
├── themes/**                     first-party themes
├── migrations/**                 BLARCHY migration source
└── version                       BLARCHY release version
```

## Installed runtime and integration

```text
/usr/local/share/blarchy/**       copied runtime, defaults, themes, migrations
/usr/local/bin/blarchy*           BLARCHY-native command surface
/usr/local/bin/omarchy*           retained compatibility command surface
/etc/blarchy.conf                 installed runtime/source metadata
/usr/share/uwsm/env.d/**          graphical-session environment
/usr/share/wayland-sessions/**    BLARCHY session entry
/usr/lib/systemd/user/**          BLARCHY user units
/usr/share/pixmaps/blarchy.png    stable BLARCHY image asset
```

`BLARCHY_PATH=/usr/local/share/blarchy` is the canonical runtime variable.
`OMARCHY_PATH` may be exported as a compatibility alias, but production code
must default to the installed BLARCHY runtime rather than a checkout or
`/usr/share/omarchy`. Explicit `omarchy dev link` workflows write
`/etc/blarchy-dev.conf`, which overrides `BLARCHY_PATH` without changing the
installed-runtime metadata in `/etc/blarchy.conf`.

The installer stages and copies this runtime so a failed source update cannot
leave a half-written live tree. Command paths and unit paths resolve within the
installed layer, never through symlinks into a mutable worktree. System-path
copies are root-owned even though the source checkout belongs to the user.

## User configuration and state

On a normal install, missing defaults are copied into standard XDG locations:

```text
~/.config/hypr/**                 Hyprland user layer
~/.config/alacritty/**            terminal configuration
~/.config/fastfetch/**            system-information presentation
~/.config/omarchy/shell.json      retained shell compatibility namespace
~/.config/omarchy/plugins/**      user-owned shell plugins
~/.local/state/blarchy/**         lifecycle and migration completion state
~/.local/state/omarchy/**         retained compatibility state
```

Existing files are preserved. BLARCHY-managed defaults stay in the installed
runtime, user files load after those defaults where supported, and migrations
change an existing file only when a specific transition requires it. Destructive
resync remains an explicit command and backs up or scopes changes appropriately.

The `omarchy` config/state names are intentionally retained in v0.2 to avoid a
large destructive migration and preserve plugin compatibility. They are local
BLARCHY data, not references to an external Omarchy installation.

## Updates and migrations

`yay -Syu` updates Arch and AUR packages. `blarchy update` requires a clean
configured worktree, updates source from
`blakepiper/blarchy`, republishes the installed runtime, installs newly required
packages, and invokes the BLARCHY-owned migration runner. Completion markers are
per-user; fresh installs establish a baseline so historical migrations are not
replayed unnecessarily.

Basecamp/Omarchy is never a runtime, update, or migration source. Developers may
inspect it separately and deliberately port useful changes.

## Retained upstream-only code

Some inherited ISO/package/boot code remains for project history and selective
manual review. Unless the standalone installer explicitly adopts a safe leaf,
it is not a supported BLARCHY installation path and must not be wired into
storage, bootloader, pacman-repository, `/etc/skel`, or private-package
ownership.
