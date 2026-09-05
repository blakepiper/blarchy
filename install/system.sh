#!/bin/bash
# Root-scoped system integration. Run through install.sh, which invokes
# this script with sudo. Requires BLARCHY_REPO, BLARCHY_USER,
# BLARCHY_ENABLE_BLUETOOTH, BLARCHY_ENABLE_PPD in the environment.

set -euo pipefail

repo=${BLARCHY_REPO:-}
install_user=${BLARCHY_USER:-}
enable_bluetooth=${BLARCHY_ENABLE_BLUETOOTH:-0}
enable_ppd=${BLARCHY_ENABLE_PPD:-0}

if [[ -z $repo || ! -d $repo ]]; then
  echo "Error: BLARCHY_REPO must point to the repository checkout." >&2
  exit 1
fi
if [[ -z $install_user ]] || ! getent passwd "$install_user" >/dev/null 2>&1; then
  echo "Error: BLARCHY_USER must name the desktop user." >&2
  exit 1
fi
if (( EUID != 0 )); then
  echo "Error: system integration must run as root." >&2
  exit 1
fi

# Login screen: greetd + tuigreet launching the Niri session.
mkdir -p /etc/greetd
install -m 0644 "$repo/etc/greetd/config.toml" /etc/greetd/config.toml

# Make sure a Niri Wayland session exists for tuigreet to offer.
# The niri package normally ships this file; only fall back when missing.
if [[ ! -f /usr/share/wayland-sessions/niri.desktop ]]; then
  mkdir -p /usr/share/wayland-sessions
  cat >/usr/share/wayland-sessions/niri.desktop <<'DESKTOP'
[Desktop Entry]
Name=Niri
Comment=Scrollable-tiling Wayland compositor
Exec=niri-session
Type=Application
DesktopNames=niri
DESKTOP
  chmod 0644 /usr/share/wayland-sessions/niri.desktop
fi

systemctl daemon-reload

enable_if_available() {
  local unit="$1"
  if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q "^$unit"; then
    systemctl enable "$unit"
  fi
}

# Core services every machine gets.
for unit in NetworkManager.service cups.service avahi-daemon.service systemd-oomd.service; do
  enable_if_available "$unit"
done
if command -v ufw >/dev/null 2>&1; then
  ufw --force enable >/dev/null 2>&1 || true
fi

# Hardware-conditional services.
if (( enable_bluetooth == 1 )); then
  enable_if_available bluetooth.service
fi
if (( enable_ppd == 1 )); then
  enable_if_available power-profiles-daemon.service
fi

# Display manager: keep whatever is already enabled, otherwise use greetd.
display_manager=""
if [[ -e /etc/systemd/system/display-manager.service || -L /etc/systemd/system/display-manager.service ]]; then
  display_manager=$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)
fi
if [[ -n $display_manager && $display_manager != *greetd.service ]]; then
  echo "Preserve existing display manager: $(basename "$display_manager")"
else
  enable_if_available greetd.service
fi

fc-cache -f >/dev/null
echo "System integration complete"
