#!/bin/bash

set -euo pipefail

repo_path=${BLARCHY_REPO_PATH:-}
root_prefix=${BLARCHY_INSTALL_ROOT:-}
skip_services=${BLARCHY_INSTALL_SKIP_SERVICES:-0}

if [[ -z $repo_path ]]; then
  echo "Error: BLARCHY_REPO_PATH is required." >&2
  exit 1
fi

if [[ ! -d $repo_path ]]; then
  echo "Error: BLARCHY checkout does not exist: $repo_path" >&2
  exit 1
fi
repo_path=$(cd -- "$repo_path" && pwd -P)
if (( EUID != 0 )) && [[ -z $root_prefix ]]; then
  echo "Error: standalone system integration must run as root." >&2
  exit 1
fi

target_path() {
  printf '%s%s' "$root_prefix" "$1"
}

install_file() {
  local source_file="$1"
  local destination="$2"
  local mode="${3:-0644}"
  local target

  target=$(target_path "$destination")
  mkdir -p "$(dirname "$target")"
  install -m "$mode" "$source_file" "$target"
}

copy_tree() {
  local source_dir="$1"
  local destination="$2"
  local target

  target=$(target_path "$destination")
  mkdir -p "$target"
  cp -a "$source_dir/." "$target/"
}

install_user_command_override() {
  local unit="$1"
  local command="$2"
  local target

  target=$(target_path "/etc/systemd/user/$unit.d/10-blarchy-standalone.conf")
  mkdir -p "$(dirname "$target")"
  printf '[Service]\nExecStart=\nExecStart=/usr/local/bin/%s\n' "$command" >"$target"
  chmod 0644 "$target"
}

runtime_link=$(target_path /usr/share/omarchy)
mkdir -p "$(dirname "$runtime_link")"
if [[ -e $runtime_link && ! -L $runtime_link ]]; then
  echo "Error: $runtime_link already exists and is not a symlink." >&2
  echo "Remove upstream Omarchy packages before installing BLARCHY." >&2
  exit 1
fi
ln -sfn "$repo_path" "$runtime_link"

conf_target=$(target_path /etc/omarchy.conf)
mkdir -p "$(dirname "$conf_target")"
escaped_repo=${repo_path//\\/\\\\}
escaped_repo=${escaped_repo//\"/\\\"}
escaped_repo=${escaped_repo//\$/\\\$}
escaped_repo=${escaped_repo//\`/\\\`}
printf 'export OMARCHY_PATH="%s"\n' "$escaped_repo" >"$conf_target"
chmod 0644 "$conf_target"

install_mode_target=$(target_path /etc/blarchy.conf)
printf 'BLARCHY_INSTALL_MODE=standalone\n' >"$install_mode_target"
chmod 0644 "$install_mode_target"

bin_dir=$(target_path /usr/local/bin)
mkdir -p "$bin_dir"
for source_file in "$repo_path"/bin/omarchy*; do
  [[ -f $source_file && -x $source_file ]] || continue
  destination="$bin_dir/$(basename "$source_file")"
  if [[ -e $destination && ! -L $destination ]]; then
    echo "Error: refusing to replace non-symlink command: $destination" >&2
    exit 1
  fi
  ln -sfn "$source_file" "$destination"
done

install_file "$repo_path/etc/profile.d/omarchy.sh" /etc/profile.d/omarchy.sh
install_file "$repo_path/default/uwsm/env.d/10-omarchy" /usr/share/uwsm/env.d/10-omarchy
install_file "$repo_path/default/wayland-sessions/omarchy.desktop" \
  /usr/share/wayland-sessions/omarchy.desktop
install_file "$repo_path/default/xdg-terminal-exec/hyprland-xdg-terminals.list" \
  /usr/share/xdg-terminal-exec/hyprland-xdg-terminals.list
install_file "$repo_path/default/environment.d/10-omarchy-fcitx.conf" \
  /usr/lib/environment.d/10-omarchy-fcitx.conf
install_file "$repo_path/default/firefox/policies.json" \
  /etc/firefox/policies/policies.json
install_file "$repo_path/default/pam/omarchy-lock-password" \
  /etc/pam.d/omarchy-lock-password

copy_tree "$repo_path/default/systemd/user" /usr/lib/systemd/user
copy_tree "$repo_path/default/systemd/user@.service.d" /usr/lib/systemd/user@.service.d

# The inherited units target package-owned commands in /usr/bin. Standalone
# installs intentionally expose the checkout through /usr/local/bin instead.
install_user_command_override omarchy-migrate-notify.service omarchy-migrate-notify
install_user_command_override omarchy-recover-internal-monitor.service omarchy-hw-recover-internal-monitor
install_user_command_override omarchy-sleep-lock.service omarchy-system-sleep-monitor
install_user_command_override omarchy-tailscale-receive.service omarchy-tailscale-receive

install_file "$repo_path/default/fonts/omarchy/omarchy.ttf" \
  /usr/share/fonts/omarchy/omarchy.ttf
install_file "$repo_path/default/fontconfig/conf.avail/50-omarchy.conf" \
  /usr/share/fontconfig/conf.avail/50-omarchy.conf

font_link=$(target_path /etc/fonts/conf.d/50-omarchy.conf)
mkdir -p "$(dirname "$font_link")"
ln -sfn /usr/share/fontconfig/conf.avail/50-omarchy.conf "$font_link"

copy_tree "$repo_path/default/sddm/omarchy" /usr/share/sddm/themes/omarchy
install_file "$repo_path/default/sddm/hyprland.lua" /usr/share/sddm/hyprland.lua
install_file "$repo_path/etc/sddm.conf.d/10-theme.conf" /etc/sddm.conf.d/90-blarchy-theme.conf
install_file "$repo_path/etc/sddm.conf.d/10-wayland.conf" /etc/sddm.conf.d/90-blarchy-wayland.conf

install_file "$repo_path/icon.png" /usr/share/pixmaps/omarchy.png
install_file "$repo_path/icon.png" /usr/share/icons/hicolor/256x256/apps/omarchy.png
install_file "$repo_path/applications/icons/imv.png" \
  /usr/share/icons/hicolor/256x256/apps/imv.png
install_file "$repo_path/applications/icons/Disk Usage.png" \
  /usr/share/icons/hicolor/256x256/apps/disk-usage.png

if [[ $skip_services == "1" ]]; then
  exit 0
fi

systemctl daemon-reload

enable_if_available() {
  local unit="$1"
  if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q "^$unit"; then
    systemctl enable "$unit"
  fi
}

for unit in \
  avahi-daemon.service \
  bluetooth.service \
  cups.service \
  cups-browsed.service \
  power-profiles-daemon.service; do
  enable_if_available "$unit"
done

display_manager=$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)
if [[ -z $display_manager || $display_manager == */sddm.service ]]; then
  enable_if_available sddm.service
else
  echo "Preserve existing display manager: $(basename "$display_manager")"
fi

alternate_network_enabled=0
for unit in systemd-networkd.service iwd.service dhcpcd.service; do
  if systemctl is-enabled "$unit" >/dev/null 2>&1; then
    alternate_network_enabled=1
    break
  fi
done

if systemctl is-enabled NetworkManager.service >/dev/null 2>&1; then
  :
elif (( alternate_network_enabled )); then
  echo "Preserve the existing network stack; BLARCHY's network panel requires NetworkManager for configuration."
else
  enable_if_available NetworkManager.service
fi

fc-cache -f >/dev/null
