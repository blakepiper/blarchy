# Rice file layout

The repository has three layers:

1. The Git checkout is the editable source of truth.
2. `./install.sh` publishes a root-owned runtime snapshot at
   `/usr/local/share/rice`.
3. User configuration and state live in normal XDG locations under `$HOME`.

The desktop never executes directly from the checkout. A failed edit, branch
switch, or incomplete pull therefore cannot leave the active session with a
partially updated runtime.

## Source tree

```text
install.sh                 package and setup orchestrator
install/packages           desired Arch and AUR package set
install/standalone/**      system and per-user installation
install/user/**            idempotent per-user setup
bin/**                     desktop helper commands
config/**                  defaults copied into ~/.config
default/**                 shared runtime and system defaults
shell/**                   Quickshell desktop
themes/**                  bundled themes
```

## Installed runtime

```text
/usr/local/share/rice/**      copied runtime and defaults
/usr/local/bin/omarchy*       retained desktop helper namespace
/usr/local/bin/*              small generic helper commands
/etc/rice.conf                runtime environment
/usr/share/wayland-sessions   personal Hyprland session entry
/usr/lib/systemd/user         desktop user units
```

`RICE_PATH=/usr/local/share/rice` is canonical. `OMARCHY_PATH` remains an
internal compatibility alias because inherited helper, config, IPC, and plugin
namespaces still use `omarchy`; it does not provide an updater or a dependency
on an Omarchy installation.

Normal installs seed only missing files. `omarchy-reinstall-configs` is the
explicit destructive reset path. Package updates use `yay -Syu`. To publish
new repository changes, pull or edit the checkout and rerun `./install.sh`.
