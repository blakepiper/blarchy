#!/bin/bash

set -euo pipefail

repo_path=${RICE_REPO_PATH:-}
root_prefix=${RICE_INSTALL_ROOT:-}
skip_services=${RICE_INSTALL_SKIP_SERVICES:-0}
runtime_path=/usr/local/share/rice
install_user=${RICE_INSTALL_USER:-${SUDO_USER:-}}

if [[ -z $repo_path ]]; then
  echo "Error: RICE_REPO_PATH is required." >&2
  exit 1
fi

if [[ ! -d $repo_path ]]; then
  echo "Error: RICE checkout does not exist: $repo_path" >&2
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

restore_powerprofilesctl_shebang() {
  local target

  target=$(target_path /usr/bin/powerprofilesctl)
  [[ -f $target ]] || return 0
  # Older RICE releases changed this package-owned shebang. Restore only the
  # exact legacy edit; the RICE-owned wrapper below now selects system Python.
  sed -i '1s|^#!/bin/python3$|#!/usr/bin/env python3|' "$target"
}

copy_tree() {
  local source_dir="$1"
  local destination="$2"
  local target

  target=$(target_path "$destination")
  mkdir -p "$target"
  # The source checkout is user-owned. Files published under system paths must
  # be owned by the account running this root-scoped installer (root in normal
  # installs), not retain checkout ownership.
  cp -a --no-preserve=ownership "$source_dir/." "$target/"
}

shell_quote() {
  local value="$1"

  printf "'%s'" "${value//\'/\'\\\'\'}"
}

cleanup_runtime_install() {
  [[ -z ${runtime_stage:-} ]] || rm -rf -- "$runtime_stage"

  if [[ -n ${runtime_previous:-} && ( -e $runtime_previous || -L $runtime_previous ) ]]; then
    if [[ -n ${runtime_target:-} && ! -e $runtime_target && ! -L $runtime_target ]]; then
      mv "$runtime_previous" "$runtime_target"
    else
      rm -rf -- "$runtime_previous"
    fi
  fi
}

install_runtime_snapshot() {
  local runtime_parent runtime_target runtime_stage runtime_previous
  local runtime_item
  local runtime_items=(
    applications
    bin
    config
    default
    docs
    etc
    etc-overrides
    install
    shell
    themes
    LICENSE
    README.md
    logo.svg
    logo.txt
  )

  runtime_parent=$(target_path /usr/local/share)
  runtime_target=$(target_path "$runtime_path")
  mkdir -p "$runtime_parent"
  runtime_stage=$(mktemp -d "$runtime_parent/.rice-runtime.XXXXXX")
  runtime_previous="$runtime_parent/.rice-runtime.previous.$$"
  trap cleanup_runtime_install RETURN

  for runtime_item in "${runtime_items[@]}"; do
    [[ -e $repo_path/$runtime_item ]] || continue
    cp -a --no-preserve=ownership "$repo_path/$runtime_item" "$runtime_stage/"
  done
  chmod 0755 "$runtime_stage"

  if [[ -e $runtime_target || -L $runtime_target ]]; then
    mv "$runtime_target" "$runtime_previous"
  fi
  if ! mv "$runtime_stage" "$runtime_target"; then
    [[ ! -e $runtime_previous && ! -L $runtime_previous ]] ||
      mv "$runtime_previous" "$runtime_target"
    return 1
  fi
  [[ ! -e $runtime_previous && ! -L $runtime_previous ]] ||
    rm -rf -- "$runtime_previous"
  runtime_stage=""
  runtime_previous=""
  runtime_target=""
  trap - RETURN
}

install_user_command_override() {
  local unit="$1"
  local command="$2"
  local target

  target=$(target_path "/etc/systemd/user/$unit.d/10-rice-standalone.conf")
  mkdir -p "$(dirname "$target")"
  printf '[Service]\nExecStart=\nExecStart=/usr/local/bin/%s\n' "$command" >"$target"
  chmod 0644 "$target"
}

install_sddm_state() {
  local state_target state_dir session_dir selected_session session_file
  local state_user state_session state_tmp

  if [[ -z $install_user || $install_user == "root" ]]; then
    echo "Warning: no invoking user was supplied; preserving SDDM's existing remembered login state." >&2
    return
  fi
  if ! getent passwd "$install_user" >/dev/null 2>&1; then
    echo "Error: invoking user does not exist: $install_user" >&2
    return 1
  fi

  state_dir=$(target_path /var/lib/sddm)
  state_target="$state_dir/state.conf"
  session_dir=$(target_path /usr/share/wayland-sessions)
  selected_session=""
  for session_file in "$session_dir"/*.desktop; do
    [[ -f $session_file ]] || continue
    if grep -Fxq 'Exec=uwsm start -g -1 -e -D Hyprland hyprland.desktop' "$session_file"; then
      selected_session=$(basename "$session_file")
      break
    fi
  done
  if [[ -z $selected_session ]]; then
    echo "Error: could not find the installed personal Hyprland session." >&2
    return 1
  fi

  state_user=""
  state_session=$selected_session
  if [[ -f $state_target ]]; then
    state_user=$(awk -F= '
      /^\[Last\]$/ { in_last=1; next }
      /^\[/ { in_last=0 }
      in_last && $1 == "User" { print substr($0, index($0, "=") + 1); exit }
    ' "$state_target")
  fi

  if [[ -z $state_user ]] || ! getent passwd "$state_user" >/dev/null 2>&1; then
    state_user=$install_user
  fi
  mkdir -p "$state_dir"
  state_tmp=$(mktemp "$state_target.XXXXXX")
  {
    printf '[Last]\n'
    printf 'User=%s\n' "$state_user"
    printf 'Session=%s\n' "$state_session"
  } >"$state_tmp"
  chmod 0600 "$state_tmp"
  if (( EUID == 0 )) && getent passwd sddm >/dev/null 2>&1 &&
    getent group sddm >/dev/null 2>&1; then
    chown sddm:sddm "$state_tmp"
  fi
  mv -f "$state_tmp" "$state_target"
}

install_runtime_snapshot
restore_powerprofilesctl_shebang

conf_target=$(target_path /etc/rice.conf)
mkdir -p "$(dirname "$conf_target")"
{
  printf 'export RICE_PATH=%s\n' "$(shell_quote "$runtime_path")"
  printf 'export RICE_INSTALL=%s\n' "$(shell_quote "$runtime_path/install")"
} >"$conf_target"
chmod 0644 "$conf_target"

bin_dir=$(target_path /usr/local/bin)
mkdir -p "$bin_dir"
shopt -s nullglob
for destination in \
  "$bin_dir"/agent-keep-awake \
  "$bin_dir"/lock-and-switch-session \
  "$bin_dir"/omarchy* \
  "$bin_dir"/powerprofilesctl-wrapper; do
  [[ -L $destination ]] || continue
  command_name=$(basename "$destination")
  [[ ! -e $(target_path "$runtime_path/bin/$command_name") ]] || continue

  link_target=$(readlink "$destination")
  runtime_command="$runtime_path/bin/$command_name"
  source_command="$repo_path/bin/$command_name"
  if [[ $link_target == $runtime_command || $link_target == $source_command ]]; then
    rm -- "$destination"
  fi
done
for source_file in \
  "$(target_path "$runtime_path")"/bin/agent-keep-awake \
  "$(target_path "$runtime_path")"/bin/lock-and-switch-session \
  "$(target_path "$runtime_path")"/bin/powerprofilesctl-wrapper \
  "$(target_path "$runtime_path")"/bin/omarchy*; do
  [[ -f $source_file && -x $source_file ]] || continue
  destination="$bin_dir/$(basename "$source_file")"
  if [[ -e $destination && ! -L $destination ]]; then
    echo "Error: refusing to replace non-symlink command: $destination" >&2
    exit 1
  fi
  ln -sfn "$runtime_path/bin/$(basename "$source_file")" "$destination"
done
shopt -u nullglob

powerprofilesctl_link="$bin_dir/powerprofilesctl"
powerprofilesctl_target="$runtime_path/bin/powerprofilesctl-wrapper"
if [[ ! -e $powerprofilesctl_link && ! -L $powerprofilesctl_link ]]; then
  ln -s "$powerprofilesctl_target" "$powerprofilesctl_link"
elif [[ -L $powerprofilesctl_link ]] &&
  [[ $(readlink "$powerprofilesctl_link") == "$powerprofilesctl_target" ]]; then
  ln -sfn "$powerprofilesctl_target" "$powerprofilesctl_link"
else
  echo "Preserve existing command: $powerprofilesctl_link"
fi

install_file "$repo_path/etc/profile.d/rice.sh" /etc/profile.d/rice.sh
install_file "$repo_path/default/uwsm/env.d/10-rice" /usr/share/uwsm/env.d/10-rice
install_file "$repo_path/default/wayland-sessions/rice.desktop" \
  /usr/share/wayland-sessions/rice.desktop
install_file "$repo_path/default/xdg-terminal-exec/hyprland-xdg-terminals.list" \
  /usr/share/xdg-terminal-exec/hyprland-xdg-terminals.list
install_file "$repo_path/default/environment.d/10-omarchy-fcitx.conf" \
  /usr/lib/environment.d/10-omarchy-fcitx.conf
firefox_policy=$(target_path /etc/firefox/policies/policies.json)
firefox_policy_marker=$(target_path /etc/rice/managed/firefox-policy)
if [[ ! -e $firefox_policy || -f $firefox_policy_marker ]]; then
  install_file "$repo_path/default/firefox/policies.json" \
    /etc/firefox/policies/policies.json
  mkdir -p "$(dirname "$firefox_policy_marker")"
  touch "$firefox_policy_marker"
elif cmp -s "$repo_path/default/firefox/policies.json" "$firefox_policy"; then
  mkdir -p "$(dirname "$firefox_policy_marker")"
  touch "$firefox_policy_marker"
else
  echo "Preserve existing Firefox enterprise policy: $firefox_policy"
fi
install_file "$repo_path/default/pam/omarchy-lock-password" \
  /etc/pam.d/omarchy-lock-password
install_file "$repo_path/etc/systemd/system.conf.d/10-faster-shutdown.conf" \
  /etc/systemd/system.conf.d/10-faster-shutdown.conf
install_file "$repo_path/etc/systemd/logind.conf.d/30-omarchy-lid-handler.conf" \
  /etc/systemd/logind.conf.d/30-omarchy-lid-handler.conf

copy_tree "$repo_path/default/systemd/user" /usr/lib/systemd/user
copy_tree "$repo_path/default/systemd/user@.service.d" /usr/lib/systemd/system/user@.service.d

# Older standalone installs placed this system-unit drop-in outside systemd's
# unit search path. Remove only the exact RICE-owned copy while migrating it
# to the correct location; preserve anything else a user may have put there.
legacy_user_manager_dropin=$(target_path /usr/lib/systemd/user@.service.d/faster-shutdown.conf)
if [[ -f $legacy_user_manager_dropin ]] &&
  cmp -s "$repo_path/default/systemd/user@.service.d/faster-shutdown.conf" \
    "$legacy_user_manager_dropin"; then
  rm -- "$legacy_user_manager_dropin"
fi

# The inherited units target package-owned commands in /usr/bin. Standalone
# installs expose commands from the installed runtime through /usr/local/bin.
install_user_command_override omarchy-recover-internal-monitor.service omarchy-hw-recover-internal-monitor
install_user_command_override omarchy-sleep-lock.service omarchy-system-sleep-monitor
install_user_command_override omarchy-tailscale-receive.service omarchy-tailscale-receive

agent_keep_awake_override=$(target_path "/etc/systemd/user/agent-keep-awake.service.d/10-rice-standalone.conf")
mkdir -p "$(dirname "$agent_keep_awake_override")"
cat >"$agent_keep_awake_override" <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/local/bin/agent-keep-awake
ExecStopPost=
ExecStopPost=/usr/local/bin/agent-keep-awake --clear
EOF
chmod 0644 "$agent_keep_awake_override"

install_file "$repo_path/default/fonts/omarchy/omarchy.ttf" \
  /usr/share/fonts/omarchy/omarchy.ttf
install_file "$repo_path/default/fontconfig/conf.avail/50-omarchy.conf" \
  /usr/share/fontconfig/conf.avail/50-omarchy.conf

font_link=$(target_path /etc/fonts/conf.d/50-omarchy.conf)
mkdir -p "$(dirname "$font_link")"
ln -sfn /usr/share/fontconfig/conf.avail/50-omarchy.conf "$font_link"

install_file "$repo_path/default/sddm/hyprland.lua" /usr/share/sddm/hyprland.lua
install_file "$repo_path/etc/sddm.conf.d/10-theme.conf" /etc/sddm.conf.d/90-rice-theme.conf
install_file "$repo_path/etc/sddm.conf.d/10-wayland.conf" /etc/sddm.conf.d/90-rice-wayland.conf
install_file "$repo_path/etc/sddm.conf.d/20-login.conf" /etc/sddm.conf.d/99-rice-login.conf
install_sddm_state

install_file /usr/share/pixmaps/archlinux-logo.png /usr/share/pixmaps/omarchy.png
install_file /usr/share/pixmaps/archlinux-logo.png /usr/share/pixmaps/rice.png
install_file /usr/share/pixmaps/archlinux-logo.png /usr/share/icons/hicolor/256x256/apps/omarchy.png
install_file /usr/share/pixmaps/archlinux-logo.png /usr/share/icons/hicolor/256x256/apps/rice.png
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
  power-profiles-daemon.service \
  systemd-oomd.service; do
  enable_if_available "$unit"
done

display_manager_link=/etc/systemd/system/display-manager.service
if [[ -e $display_manager_link || -L $display_manager_link ]]; then
  display_manager=$(readlink -f "$display_manager_link" 2>/dev/null || true)
else
  display_manager=""
fi
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
  echo "Preserve the existing network stack; RICE's network panel requires NetworkManager for configuration."
else
  enable_if_available NetworkManager.service
fi

fc-cache -f >/dev/null
