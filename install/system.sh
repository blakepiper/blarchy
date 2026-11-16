#!/bin/bash
# Root-scoped system integration. Run through install.sh with sudo.

set -euo pipefail

repo=${INSTALL_REPO:-}
install_user=${INSTALL_USER:-}
enable_bluetooth=${INSTALL_ENABLE_BLUETOOTH:-0}
enable_ppd=${INSTALL_ENABLE_PPD:-0}

if [[ -z $repo || ! -d $repo ]]; then
  echo 'Error: INSTALL_REPO must point to the repository checkout.' >&2
  exit 1
fi
if [[ -z $install_user ]] || ! getent passwd "$install_user" >/dev/null 2>&1; then
  echo 'Error: INSTALL_USER must name the desktop user.' >&2
  exit 1
fi
if (( EUID != 0 )); then
  echo 'Error: system integration must run as root.' >&2
  exit 1
fi

install -Dm 0644 "$repo/etc/udev/hwdb.d/90-external-keyboard.hwdb" \
  /etc/udev/hwdb.d/90-external-keyboard.hwdb
systemd-hwdb update
udevadm trigger --subsystem-match=input --action=change

install -Dm 0644 "$repo/etc/systemd/system/battery-charge-limit.service" \
  /etc/systemd/system/battery-charge-limit.service
install -Dm 0755 "$repo/etc/lib/battery-charge-limit" \
  /usr/local/lib/battery-charge-limit
install -Dm 0644 "$repo/etc/firefox/policies/policies.json" \
  /etc/firefox/policies/policies.json

# System dark defaults remain overridable by each user's dconf settings.
install -Dm 0644 "$repo/etc/dconf/db/desktop.d/00-interface" \
  /etc/dconf/db/desktop.d/00-interface
install -Dm 0644 "$repo/etc/dconf/db/desktop.d/10-bluetooth" \
  /etc/dconf/db/desktop.d/10-bluetooth
mkdir -p /etc/dconf/profile
if [[ ! -e /etc/dconf/profile/user ]]; then
  printf 'user-db:user\n' >/etc/dconf/profile/user
fi
if ! grep -qx 'system-db:desktop' /etc/dconf/profile/user; then
  printf '\nsystem-db:desktop\n' >>/etc/dconf/profile/user
fi
dconf update

# Unlock the keyring during a TTY login and keep it in sync after passwd.
# shellcheck source=install/pam.sh
source "$repo/install/pam.sh"
configure_keyring_pam /etc/pam.d

systemctl daemon-reload

enable_if_available() {
  local unit="$1"
  if systemctl list-unit-files "$unit" --no-legend 2>/dev/null | grep -q "^$unit"; then
    systemctl enable "$unit"
  fi
}

enable_if_available systemd-oomd.service

# Keep an existing network stack; use NetworkManager on a minimal install.
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
  echo 'Preserve the existing network stack instead of enabling NetworkManager.'
else
  enable_if_available NetworkManager.service
fi

# Apply the firewall on reboot so an SSH-based install stays connected.
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf
systemctl enable ufw.service

if (( enable_bluetooth == 1 )); then
  enable_if_available bluetooth.service
fi
if (( enable_ppd == 1 )); then
  enable_if_available power-profiles-daemon.service
  enable_if_available battery-charge-limit.service
  systemctl start battery-charge-limit.service
fi

fc-cache -f >/dev/null
echo 'System integration complete'
