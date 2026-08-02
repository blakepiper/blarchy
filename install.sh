#!/bin/bash

set -euo pipefail

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

Install BLARCHY on an existing minimal Arch Linux system.

The system must already boot, have working networking, and have a non-root
user with sudo access. This installer does not partition, format, mount,
configure a bootloader, write EFI entries, or directly rebuild an initramfs.
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
  echo "Error: run ./install.sh as the user who will run BLARCHY, not as root." >&2
  exit 1
fi

if [[ ! -f /etc/arch-release ]]; then
  echo "Error: BLARCHY's standalone installer supports Arch Linux only." >&2
  exit 1
fi

for command_name in git pacman sudo; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: required command is missing: $command_name" >&2
    exit 1
  fi
done

if [[ ! -d $repo_path/.git ]]; then
  echo "Error: clone BLARCHY with Git before running the installer." >&2
  exit 1
fi

enable_multilib() {
  if pacman-conf --repo-list | grep -qx 'multilib'; then
    return
  fi

  if ! grep -q '^#\[multilib\]$' /etc/pacman.conf; then
    echo "Error: enable Arch's multilib repository in /etc/pacman.conf, then rerun the installer." >&2
    exit 1
  fi

  echo "Enable Arch multilib for Steam"
  if [[ ! -e /etc/pacman.conf.blarchy-before-multilib ]]; then
    sudo cp -p /etc/pacman.conf /etc/pacman.conf.blarchy-before-multilib
  fi
  sudo sed -i \
    '/^#\[multilib\]$/,/^#Include = \/etc\/pacman.d\/mirrorlist$/ s/^#//' \
    /etc/pacman.conf
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

load_packages() {
  local package_name
  local packages=()

  while IFS= read -r package_name; do
    package_name=${package_name%%#*}
    package_name=${package_name//[[:space:]]/}
    [[ -n $package_name ]] || continue
    packages+=("$package_name")
  done <"$repo_path/install/omarchy-base.packages"

  printf '%s\n' "${packages[@]}"
}

split_packages() {
  local package_name

  repo_packages=()
  aur_packages=()
  for package_name in "${packages[@]}"; do
    if pacman -Si -- "$package_name" >/dev/null 2>&1; then
      repo_packages+=("$package_name")
    else
      aur_packages+=("$package_name")
    fi
  done
}

sudo -v
enable_multilib

echo "Update Arch and install build prerequisites"
if pacman -Q rustup >/dev/null 2>&1; then
  if ! rustup default >/dev/null 2>&1; then
    echo "Initialize the installed rustup provider for AUR builds"
    rustup default stable
  fi
  sudo pacman -Syu --needed --noconfirm base-devel git
else
  sudo pacman -Syu --needed --noconfirm base-devel git rust
fi
install_yay

mapfile -t packages < <(load_packages)
split_packages

echo "Install BLARCHY repository packages"
sudo pacman -S --needed --noconfirm "${repo_packages[@]}"
if (( ${#aur_packages[@]} )); then
  echo "Build and install BLARCHY AUR packages"
  yay -S --needed --noconfirm "${aur_packages[@]}"
fi
yay -Y --devel --save

echo "Install BLARCHY system integration"
sudo env BLARCHY_REPO_PATH="$repo_path" \
  bash "$repo_path/install/standalone/system.sh"

echo "Seed BLARCHY user defaults without overwriting existing files"
HOME="$HOME" OMARCHY_PATH="$repo_path" \
  bash "$repo_path/install/standalone/user.sh" preserve

export OMARCHY_PATH="$repo_path"
export OMARCHY_INSTALL="$repo_path/install"
export OMARCHY_PRESERVE_USER_CONFIG=1
export OMARCHY_USER_NAME="$(git config --global user.name 2>/dev/null || true)"
export OMARCHY_USER_EMAIL="$(git config --global user.email 2>/dev/null || true)"
export PATH="$repo_path/bin:$PATH"

if omarchy-done check finalize-user; then
  omarchy-finalize-user
  omarchy-migrate
else
  omarchy-finalize-user --first-install
fi

cat <<'DONE'

BLARCHY installation complete.

Reboot when convenient, then select "BLARCHY (Hyprland uwsm)" in your display
manager if it is not selected automatically. Your existing disk layout,
bootloader, EFI entries, and other operating systems were not changed.
DONE
