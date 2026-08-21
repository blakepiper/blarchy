#!/bin/bash

set -euo pipefail

repo_path=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
yay_build_dir=""
aur_log_dir=""

cleanup() {
  if [[ -n $yay_build_dir && -d $yay_build_dir ]]; then
    rm -rf -- "$yay_build_dir"
  fi
}

usage() {
  cat <<'USAGE'
Usage: ./install.sh

Reproduce this personal desktop on an existing minimal Arch Linux system.

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
  echo "Error: run ./install.sh as the user who will use this desktop, not as root." >&2
  exit 1
fi

install_user=$(id -un)
install_home=$(getent passwd "$install_user" | cut -d: -f6)
if [[ -z $install_home || ! -d $install_home ]]; then
  echo "Error: could not determine the home directory for $install_user." >&2
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

if [[ ! -d $repo_path/.git ]]; then
  echo "Error: clone this repository with Git before running the installer." >&2
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
  if [[ ! -e /etc/pacman.conf.rice-before-multilib ]]; then
    sudo cp -p /etc/pacman.conf /etc/pacman.conf.rice-before-multilib
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
  done <"$repo_path/install/packages"

  printf '%s\n' "${packages[@]}"
}

split_packages() {
  local package_name package_info

  repo_packages=()
  aur_packages=()
  for package_name in "${packages[@]}"; do
    if package_info=$(LC_ALL=C pacman -Si -- "$package_name" 2>&1); then
      repo_packages+=("$package_name")
    elif grep -Fq "error: package '$package_name' was not found" <<<"$package_info"; then
      aur_packages+=("$package_name")
    else
      echo "Error: could not determine the package source for $package_name." >&2
      printf '%s\n' "$package_info" >&2
      return 1
    fi
  done
}

validate_package_manifest() {
  local package_name

  for package_name in "${packages[@]}"; do
    case $package_name in
      cargo|rust|rustfmt|rustup)
        echo "Error: the package manifest must not contain a Rust provider: $package_name" >&2
        return 1
        ;;
    esac
  done
}

install_aur_packages() {
  local package_name log_name package_status batch_status
  local installed_packages
  local -a failed_packages=()
  local -A failed_status=()

  aur_log_dir=$(mktemp -d "${TMPDIR:-/tmp}/rice-aur.XXXXXX")
  if yay -S --needed --noconfirm --removemake --cleanafter "${aur_packages[@]}" \
    > >(tee "$aur_log_dir/batch.log") 2>&1; then
    rm -rf -- "$aur_log_dir"
    aur_log_dir=""
    return
  else
    batch_status=$?
  fi

  echo "The batch AUR install failed with exit status $batch_status; retrying each package individually." >&2
  echo "Batch output is recorded in $aur_log_dir/batch.log" >&2
  installed_packages=$(pacman -Qq)
  for package_name in "${aur_packages[@]}"; do
    if grep -Fxq "$package_name" <<<"$installed_packages"; then
      echo "AUR package already installed; skip retry: $package_name"
      continue
    fi
    log_name=${package_name//[^[:alnum:]._-]/_}
    echo "Retry AUR package: $package_name"
    if yay -S --needed --noconfirm --removemake --cleanafter "$package_name" \
      > >(tee "$aur_log_dir/$log_name.log") 2>&1; then
      continue
    else
      package_status=$?
    fi
    failed_packages+=("$package_name")
    failed_status["$package_name"]=$package_status
  done

  if (( ${#failed_packages[@]} )); then
    echo "Failed to install the following AUR packages:" >&2
    for package_name in "${failed_packages[@]}"; do
      log_name=${package_name//[^[:alnum:]._-]/_}
      echo "  $package_name (exit status ${failed_status[$package_name]}, log: $aur_log_dir/$log_name.log)" >&2
    done
    return 1
  fi

  rm -rf -- "$aur_log_dir"
  aur_log_dir=""
}

sudo -v
enable_multilib

echo "Update Arch and install build prerequisites"
# Use one persistent Rust provider. If an Arch Rust provider is already
# installed, leave this transaction interactive so pacman can ask permission
# to replace it with rustup atomically. --noconfirm answers that conflict prompt
# with its default "no" and causes the exact provider mismatch this avoids.
build_prerequisites=(base-devel git rustup)
rust_conflicts=()
if ! pacman -Qq rustup >/dev/null 2>&1; then
  for package_name in rust cargo rustfmt; do
    pacman -Qq "$package_name" >/dev/null 2>&1 && rust_conflicts+=("$package_name")
  done
fi
if (( ${#rust_conflicts[@]} )); then
  printf 'Replace conflicting Rust packages with rustup: %s\n' "${rust_conflicts[*]}"
  sudo pacman -Syu --needed "${build_prerequisites[@]}"
else
  sudo pacman -Syu --needed --noconfirm "${build_prerequisites[@]}"
fi

if ! rustup default >/dev/null 2>&1; then
  echo "Initialize the stable Rust toolchain for AUR builds"
  rustup default stable
fi

install_yay

mapfile -t packages < <(load_packages)
validate_package_manifest
split_packages

echo "Install repository packages"
sudo pacman -S --needed --noconfirm "${repo_packages[@]}"
if (( ${#aur_packages[@]} )); then
  echo "Build and install AUR packages"
  install_aur_packages
fi
yay -Y --devel --save

echo "Install system integration"
sudo env RICE_REPO_PATH="$repo_path" \
  RICE_INSTALL_USER="$install_user" \
  bash "$repo_path/install/standalone/system.sh"

echo "Seed user defaults without overwriting existing files"
export RICE_PATH=/usr/local/share/rice
export RICE_INSTALL="$RICE_PATH/install"
export RICE_PRESERVE_USER_CONFIG=1
export RICE_USER_NAME="$(git config --global user.name 2>/dev/null || true)"
export RICE_USER_EMAIL="$(git config --global user.email 2>/dev/null || true)"
export PATH="/usr/local/bin:$PATH"

HOME="$install_home" RICE_PATH="$RICE_PATH" \
  bash "$RICE_INSTALL/standalone/user.sh" preserve

# Compatibility for inherited desktop helpers.
export OMARCHY_PATH="$RICE_PATH"
export OMARCHY_INSTALL="$RICE_INSTALL"
export OMARCHY_PRESERVE_USER_CONFIG="$RICE_PRESERVE_USER_CONFIG"
export OMARCHY_USER_NAME="$RICE_USER_NAME"
export OMARCHY_USER_EMAIL="$RICE_USER_EMAIL"

bash "$RICE_INSTALL/standalone/finalize-user.sh"

cat <<'DONE'

Arch Linux desktop installation complete.

Reboot when convenient, then select "Hyprland" in your display
manager if it is not selected automatically. Your existing disk layout,
bootloader, EFI entries, and other operating systems were not changed.
DONE
