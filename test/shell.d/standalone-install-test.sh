#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

for script in \
  "$ROOT/install.sh" \
  "$ROOT/install/standalone/system.sh" \
  "$ROOT/install/standalone/user.sh" \
  "$ROOT/install/standalone/finalize-user.sh" \
  "$ROOT/bin/lock-and-switch-session"; do
  bash -n "$script" || fail "installer scripts parse" "$script"
done
pass "installer scripts parse"

installer_sources=$(printf '%s\n' \
  "$ROOT/install.sh" \
  "$ROOT/install/standalone/system.sh" \
  "$ROOT/install/standalone/user.sh")

if xargs rg -n '(^|[;&|])[[:space:]]*(sudo[[:space:]]+)?(fdisk|parted|mkfs|mount|grub-install|bootctl|limine-install|efibootmgr|mkinitcpio)([[:space:]]|$)' \
  <<<"$installer_sources"; then
  fail "installer never invokes disk or boot tooling"
fi
if xargs rg -n '/boot(/|[[:space:]])' <<<"$installer_sources"; then
  fail "installer never writes under /boot"
fi
pass "installer preserves disk and boot ownership"

grep -Fq 'build_prerequisites=(base-devel git rustup)' "$ROOT/install.sh" ||
  fail "installer standardizes AUR builds on rustup"
grep -Fq 'rustup default stable' "$ROOT/install.sh" ||
  fail "installer initializes a Rust toolchain"
grep -Fq 'if (( ${#rust_conflicts[@]} )); then' "$ROOT/install.sh" ||
  fail "installer detects an existing conflicting Rust provider"
grep -Fq 'sudo pacman -Syu --needed "${build_prerequisites[@]}"' "$ROOT/install.sh" ||
  fail "installer lets pacman confirm an atomic Rust provider replacement"
if rg -q 'temporary_rust|pacman -R.*rust' "$ROOT/install.sh"; then
  fail "installer temporarily installs or removes a conflicting Rust provider"
fi
grep -Fq 'yay -S --needed --noconfirm --removemake --cleanafter' "$ROOT/install.sh" ||
  fail "installer uses yay for AUR packages"
grep -Fq 'yay -Y --devel --save' "$ROOT/install.sh" ||
  fail "installer includes VCS packages in normal yay updates"
pass "installer uses one durable Rust provider and normal yay updates"

for provider in rust rustup cargo rustfmt; do
  if grep -Fxq "$provider" "$ROOT/install/packages"; then
    fail "package manifest duplicates installer-owned Rust provider" "$provider"
  fi
done

for package_name in \
  hyprland quickshell-git qt6-multimedia-ffmpeg qt6-virtualkeyboard sddm steam \
  xfce4-session xfce4-panel xfce4-screensaver xfwm4; do
  grep -Fxq "$package_name" "$ROOT/install/packages" ||
    fail "personal package manifest includes $package_name"
done
pass "package manifest includes both desktop environments"

for removed_path in \
  "$ROOT/migrations" \
  "$ROOT/bin/rice" \
  "$ROOT/bin/rice-update" \
  "$ROOT/bin/omarchy-update" \
  "$ROOT/bin/omarchy-version"; do
  [[ ! -e $removed_path ]] || fail "removed lifecycle path is absent" "$removed_path"
done
pass "repository has no self-update, version, or migration lifecycle"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT
test_home="$test_tmp/home"
test_root="$test_tmp/root"
mkdir -p "$test_home" "$test_root"

HOME="$test_home" RICE_PATH="$ROOT" bash "$ROOT/install/standalone/user.sh" preserve
[[ -f $test_home/.config/hypr/hyprland.lua ]] ||
  fail "user seeding installs Hyprland config"
[[ -f $test_home/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml ]] ||
  fail "user seeding installs XFCE shortcut config"
[[ -f $test_home/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml ]] ||
  fail "user seeding installs XFCE desktop config"
[[ -f $test_home/.config/xfce4/xfconf/xfce-perchannel-xml/pointers.xml ]] ||
  fail "user seeding installs XFCE pointer config"
grep -Fq 'name="libinput_Click_Method_Enabled"' \
  "$test_home/.config/xfce4/xfconf/xfce-perchannel-xml/pointers.xml" ||
  fail "XFCE pointer config enables touchpad clickfinger settings"
grep -Fq 'value="workspace_4_key"' \
  "$test_home/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml" ||
  fail "XFCE shortcut config includes workspace bindings"
grep -Fq 'value="exo-open --launch TerminalEmulator"' \
  "$test_home/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml" ||
  fail "XFCE shortcut config uses the preferred terminal"
printf 'keep\n' >"$test_home/.config/hypr/input.lua"
HOME="$test_home" RICE_PATH="$ROOT" bash "$ROOT/install/standalone/user.sh" preserve
[[ $(<"$test_home/.config/hypr/input.lua") == "keep" ]] ||
  fail "normal user seeding preserves existing config"
pass "user defaults seed idempotently"

RICE_REPO_PATH="$ROOT" \
  RICE_INSTALL_ROOT="$test_root" \
  RICE_INSTALL_USER="$(id -un)" \
  RICE_INSTALL_SKIP_SDDM_THEME=1 \
  RICE_INSTALL_SKIP_SERVICES=1 \
  bash "$ROOT/install/standalone/system.sh"

runtime="$test_root/usr/local/share/rice"
[[ -d $runtime && ! -L $runtime ]] || fail "runtime is a copied directory"
[[ -x $runtime/bin/omarchy && -x $runtime/bin/lock-and-switch-session ]] ||
  fail "runtime publishes desktop commands"
[[ ! -e $runtime/migrations ]] || fail "runtime excludes migration machinery"
[[ $(readlink "$test_root/usr/local/bin/lock-and-switch-session") == /usr/local/share/rice/bin/lock-and-switch-session ]] ||
  fail "generic lock helper points at the installed runtime"
[[ $(readlink "$test_root/usr/local/bin/powerprofilesctl") == /usr/local/share/rice/bin/powerprofilesctl-wrapper ]] ||
  fail "powerprofilesctl wrapper points at the installed runtime"
grep -Fxq "export RICE_PATH='/usr/local/share/rice'" "$test_root/etc/rice.conf" ||
  fail "runtime environment exports RICE_PATH"
grep -Fxq "export RICE_INSTALL='/usr/local/share/rice/install'" "$test_root/etc/rice.conf" ||
  fail "runtime environment exports RICE_INSTALL"
[[ -f $test_root/usr/share/wayland-sessions/rice.desktop ]] ||
  fail "personal Hyprland session is installed"
[[ -f $test_root/usr/share/rice-sessions/wayland/rice.desktop ]] ||
  fail "SDDM chooser has the managed Hyprland Wayland session"
[[ -f $test_root/usr/share/rice-sessions/x11/xfce.desktop ]] ||
  fail "SDDM chooser has the managed XFCE X11 session"
grep -Fxq 'Current=sddm-astronaut-theme' "$test_root/etc/sddm.conf.d/90-rice-theme.conf" ||
  fail "SDDM uses the Astronaut theme"
grep -Fxq 'SessionDir=/usr/share/rice-sessions/wayland' "$test_root/etc/sddm.conf.d/90-rice-wayland.conf" ||
  fail "SDDM limits Wayland sessions to the managed chooser directory"
grep -Fxq 'SessionDir=/usr/share/rice-sessions/x11' "$test_root/etc/sddm.conf.d/90-rice-wayland.conf" ||
  fail "SDDM limits X11 sessions to the managed chooser directory"
pass "system integration publishes the desktop runtime"

RICE_REPO_PATH="$ROOT" \
  RICE_INSTALL_ROOT="$test_root" \
  RICE_INSTALL_USER="$(id -un)" \
  RICE_INSTALL_SKIP_SDDM_THEME=1 \
  RICE_INSTALL_SKIP_SERVICES=1 \
  bash "$ROOT/install/standalone/system.sh"
[[ -d $runtime && ! -L $runtime ]] || fail "runtime survives an idempotent rerun"
pass "system integration is idempotent"
