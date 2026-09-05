#!/bin/bash

# Blarchy: turn a minimal Arch system into a configured Niri desktop.
#
# Expected starting point: Arch installed with archinstall (base system,
# no desktop), booted, connected to wifi, with git installed and a
# non-root user that has sudo access:
#
#   sudo pacman -S --needed git
#   git clone https://github.com/blakepiper/blarchy.git ~/blarchy
#   cd ~/blarchy
#   ./install.sh
#
# Retry a failed install by rerunning ./install.sh. Package installation uses
# --needed, system integration converges on this repository, and user
# configuration files are never overwritten.

set -euo pipefail
trap 'echo "Installation failed. Resolve the error above, then retry ./install.sh." >&2' ERR

repo_path=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
yay_build_dir=""

cleanup() {
  if [[ -n $yay_build_dir && -d $yay_build_dir ]]; then
    rm -rf -- "$yay_build_dir"
  fi
}

usage() {
  cat <<'USAGE'
Usage: ./install.sh

Install the blarchy Arch + Niri desktop on this machine.

Requires: Arch Linux, working networking, and a non-root user with
sudo access. Run as the user who will use the desktop, not as root.
USAGE
}

if (( $# > 0 )); then
  if [[ $1 == "-h" || $1 == "--help" ]]; then
    usage
    exit 0
  fi
  usage >&2
  exit 1
fi

if (( EUID == 0 )); then
  echo "Error: run ./install.sh as the user who will use this desktop, not as root." >&2
  exit 1
fi

if [[ ! -f /etc/arch-release ]]; then
  echo "Error: this installer supports Arch Linux only." >&2
  exit 1
fi

for command_name in git pacman sudo; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: required command is missing: $command_name" >&2
    exit 1
  fi
done

if ! git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: clone this repository with Git before running the installer." >&2
  exit 1
fi

install_user=$(id -un)

load_package_list() {
  local list_file="$1"
  local line

  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    line=${line//[[:space:]]/}
    [[ -n $line ]] || continue
    printf '%s\n' "$line"
  done <"$list_file"
}

install_yay() {
  command -v yay >/dev/null 2>&1 && return

  yay_build_dir=$(mktemp -d)
  trap cleanup EXIT

  echo "Bootstrap yay from the AUR"
  git clone --quiet https://aur.archlinux.org/yay.git "$yay_build_dir/yay"
  (
    cd "$yay_build_dir/yay"
    makepkg -si --needed --noconfirm
  )

  cleanup
  yay_build_dir=""
  trap - EXIT
}

sudo -v

# Multilib provides 32-bit libraries (Steam, NVIDIA lib32 drivers).
if ! pacman-conf --repo-list 2>/dev/null | grep -qx 'multilib'; then
  if grep -q '^#\[multilib\]$' /etc/pacman.conf; then
    echo "Enable Arch multilib"
    if [[ ! -e /etc/pacman.conf.blarchy-before-multilib ]]; then
      sudo cp -p /etc/pacman.conf /etc/pacman.conf.blarchy-before-multilib
    fi
    sudo sed -i \
      '/^#\[multilib\]$/,/^#Include = \/etc\/pacman.d\/mirrorlist$/ s/^#//' \
      /etc/pacman.conf
  else
    echo "Error: enable the standard Arch multilib repository in /etc/pacman.conf, then retry." >&2
    exit 1
  fi
fi

echo "Update Arch and install build prerequisites"
# makepkg installs declared build dependencies, including Go for yay.
sudo pacman -Syu --needed --noconfirm base-devel git curl pciutils usbutils

install_yay

# shellcheck source=install/hardware.sh
export BLARCHY_REPO="$repo_path"
source "$repo_path/install/hardware.sh"
blarchy_detect_hardware

mapfile -t repo_packages < <(load_package_list "$repo_path/install/packages")
mapfile -t aur_packages < <(load_package_list "$repo_path/install/packages-aur")

echo "Install repository packages (${#repo_packages[@]} base + ${#BLARCHY_HW_PACKAGES[@]} hardware-detected)"
sudo pacman -S --needed --noconfirm "${repo_packages[@]}" "${BLARCHY_HW_PACKAGES[@]}"

if (( ${#aur_packages[@]} )); then
  echo "Build and install AUR packages: ${aur_packages[*]}"
  yay -Syu --needed --noconfirm --removemake --cleanafter "${aur_packages[@]}"
fi

echo "Validate desktop configuration"
niri validate --config "$repo_path/config/niri/config.kdl"

echo "Install system integration"
sudo env BLARCHY_REPO="$repo_path" \
  BLARCHY_USER="$install_user" \
  BLARCHY_ENABLE_BLUETOOTH="$BLARCHY_HAS_BLUETOOTH" \
  BLARCHY_ENABLE_PPD="$BLARCHY_IS_LAPTOP" \
  bash "$repo_path/install/system.sh"

echo "Seed user configuration"
BLARCHY_REPO="$repo_path" bash "$repo_path/install/user.sh"

cat <<'DONE'

Blarchy installation complete.

Reboot when convenient, then log in through the greetd prompt into
Niri. Your disk layout, bootloader, and other operating systems were
not changed.

The firewall denies incoming connections after reboot. Before rebooting,
add any rules you need (for example: sudo ufw allow 22/tcp for SSH).
Keep packages current with yay -Syu; no repository update is needed.
DONE
