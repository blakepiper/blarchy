#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

for script in \
  "$ROOT/install.sh" \
  "$ROOT/install/standalone/system.sh" \
  "$ROOT/install/standalone/user.sh"; do
  bash -n "$script" || fail "standalone installer scripts parse" "$script"
done
pass "standalone installer scripts parse"

installer_sources=$(printf '%s\n' \
  "$ROOT/install.sh" \
  "$ROOT/install/standalone/system.sh" \
  "$ROOT/install/standalone/user.sh")

if xargs rg -n '(^|[;&|])[[:space:]]*(sudo[[:space:]]+)?(fdisk|parted|mkfs|mount|grub-install|bootctl|limine-install|efibootmgr|mkinitcpio)([[:space:]]|$)' \
  <<<"$installer_sources"; then
  fail "standalone installer never invokes disk or boot tooling"
fi
if xargs rg -n '/boot(/|[[:space:]])' <<<"$installer_sources"; then
  fail "standalone installer never writes under /boot"
fi
pass "standalone installer has no disk, bootloader, EFI, or initramfs operations"

grep -Fq 'build_prerequisites=(base-devel git)' "$ROOT/install.sh" ||
  fail "standalone installer updates Arch and installs build prerequisites"
if grep -Fxq git "$ROOT/install/omarchy-base.packages"; then
  fail "standalone manifest duplicates the required Git prerequisite"
fi
pass "Git remains an installer prerequisite rather than a bundled default"
grep -Fq 'pacman -S --needed --noconfirm "${repo_packages[@]}"' "$ROOT/install.sh" ||
  fail "standalone installer installs repository packages before AUR builds"
grep -Fq 'yay -S --needed --noconfirm "${aur_packages[@]}"' "$ROOT/install.sh" ||
  fail "standalone installer installs AUR packages idempotently"
grep -Fq 'build_prerequisites+=(rustup)' "$ROOT/install.sh" ||
  fail "standalone installer uses rustup as its fresh-install AUR toolchain"
grep -Fq 'native_rust_installed' "$ROOT/install.sh" ||
  fail "standalone installer handles an existing Arch Rust provider"
grep -Fq 'pacman_options=(--needed --noconfirm)' "$ROOT/install.sh" ||
  fail "standalone installer uses pacman's supported transaction options"
for provider in rust rustup cargo rustfmt; do
  if grep -Fxq "$provider" "$ROOT/install/omarchy-base.packages"; then
    fail "package manifest duplicates the installer-owned Rust provider" "$provider"
  fi
done
grep -Fq 'yay -Y --devel --save' "$ROOT/install.sh" ||
  fail "standalone installer enables VCS package updates for plain yay -Syu"
grep -Fq 'Retry AUR package:' "$ROOT/install.sh" ||
  fail "standalone installer retries failed AUR packages individually"
grep -Fq 'tee "$aur_log_dir/' "$ROOT/install.sh" ||
  fail "standalone installer records per-package AUR logs"
grep -Fq 'blarchy-migrate' "$ROOT/install.sh" ||
  fail "explicit BLARCHY source upgrades apply pending migrations"
if grep -Fq 'xdg-settings set' "$ROOT/bin/blarchy-finalize-user"; then
  fail "console finalization does not require a live desktop session"
fi
grep -Fq 'OMARCHY_PRESERVE_USER_CONFIG' "$ROOT/bin/blarchy-finalize-user" ||
  fail "normal finalization preserves existing application preferences"
grep -Fq '! -s $HOME/.config/xdg-terminals.list' "$ROOT/bin/blarchy-finalize-user" ||
  fail "normal finalization keeps an existing terminal preference"
grep -Fq '! -s $HOME/.local/state/omarchy/defaults/editor' "$ROOT/bin/blarchy-finalize-user" ||
  fail "normal finalization keeps an existing editor preference"
for default_command in omarchy-default-terminal omarchy-default-editor; do
  grep -Eq 'omarchy-notification-send .* \|\| true$' "$ROOT/bin/$default_command" ||
    fail "console finalization ignores unavailable desktop notifications" "$default_command"
done
for package_name in blesh ttf-jetbrains-mono-nerd hyprland-preview-share-picker-git; do
  grep -Fxq "$package_name" "$ROOT/install/omarchy-base.packages" ||
    fail "standalone manifest uses the public package name" "$package_name"
done
for package_name in cliamp kdenlive libreoffice-fresh moonlight-qt neovim obs-studio obsidian pinta xournalpp; do
  if grep -Fxq "$package_name" "$ROOT/install/omarchy-base.packages"; then
    fail "standalone manifest excludes removed desktop bloat" "$package_name"
  fi
done
pass "standalone manifest excludes removed desktop bloat"
for package_name in asdcontrol omacut omawrite omarchy-nvim tobi-try; do
  if grep -Fxq "$package_name" "$ROOT/install/omarchy-base.packages"; then
    fail "standalone manifest includes an Omarchy-repository-only package" "$package_name"
  fi
done
pass "standalone installer resolves packages and finalizes without a desktop session"

grep -Fq 'source -- /usr/share/blesh/ble.sh --attach=none' "$ROOT/default/bash/rc" ||
  fail "BLARCHY loads predictive suggestions before shell initialization"
grep -Fq 'ble-attach' "$ROOT/default/bash/rc" ||
  fail "BLARCHY attaches predictive suggestions after shell initialization"
if rg -q 'ble-import -d|menu-complete-backward' \
  "$ROOT/default/bash/rc" "$ROOT/default/bash/init" "$ROOT/default/bash/inputrc"; then
  fail "Bash defaults use no interfaces unsupported by Arch blesh"
fi
grep -Fq '[[ -z ${BLE_VERSION:-}' "$ROOT/default/bash/init" ||
  fail "fzf Readline keybindings are skipped while blesh owns line editing"
pass "Alacritty Bash sessions enable predictive history suggestions"

for boot_package in limine limine-mkinitcpio-hook limine-snapper-sync plymouth snapper; do
  if grep -Fxq "$boot_package" "$ROOT/install/omarchy-base.packages"; then
    fail "standalone package manifest excludes boot-stack package" "$boot_package"
  fi
done
pass "standalone defaults install no bootloader, Plymouth, or snapshot stack"

test_home=$(mktemp -d)
test_root=$(mktemp -d)
migration_state=$(mktemp -d)
trap 'rm -rf -- "$test_home" "$test_root" "$migration_state"' EXIT

mkdir -p "$test_root/usr/bin"
printf '%s\n' '#!/usr/bin/env python3' >"$test_root/usr/bin/powerprofilesctl"

legacy_user_manager_dropin="$test_root/usr/lib/systemd/user@.service.d/faster-shutdown.conf"
mkdir -p "$(dirname "$legacy_user_manager_dropin")"
cp "$ROOT/default/systemd/user@.service.d/faster-shutdown.conf" \
  "$legacy_user_manager_dropin"

mkdir -p "$test_home/.config/hypr"
printf '%s\n' 'keep-my-binding' >"$test_home/.config/hypr/bindings.lua"
printf '%s\n' '# existing shell config' >"$test_home/.bashrc"

for _ in 1 2; do
  HOME="$test_home" BLARCHY_PATH="$ROOT" \
    bash "$ROOT/install/standalone/user.sh" preserve
done

grep -Fxq 'keep-my-binding' "$test_home/.config/hypr/bindings.lua" ||
  fail "normal install preserves existing user config"
(( $(grep -Fc '# >>> BLARCHY >>>' "$test_home/.bashrc") == 1 )) ||
  fail "normal install adds one shell integration block"
[[ -f $test_home/.config/alacritty/alacritty.toml ]] ||
  fail "normal install seeds missing user config"
[[ ! -e $test_home/.config/autostart/limine-snapper-notify.desktop ]] ||
  fail "normal install excludes the Limine snapshot notifier"
pass "user defaults are idempotent and preserve existing files"

grep -Fq '/usr/local/share/blarchy/default/bash/env-bootstrap' "$test_home/.bashrc" ||
  fail "new Bash integration loads the installed BLARCHY runtime"

HOME="$test_home" BLARCHY_PATH="$ROOT" \
  bash "$ROOT/install/standalone/user.sh" overwrite
grep -Fq 'Application launcher' "$test_home/.config/hypr/bindings.lua" ||
  fail "explicit config reset overwrites BLARCHY user defaults"
grep -Fxq '# existing shell config' "$test_home/.bashrc" ||
  fail "explicit config reset preserves unrelated bashrc content"
pass "explicit user reset remains scoped to BLARCHY-owned defaults"

for _ in 1 2; do
  BLARCHY_REPO_PATH="$ROOT" \
    BLARCHY_INSTALL_ROOT="$test_root" \
    BLARCHY_INSTALL_USER="$(id -un)" \
    BLARCHY_INSTALL_SKIP_SERVICES=1 \
    bash "$ROOT/install/standalone/system.sh"
done
printf '[Last]\nUser=%s\nSession=hyprland.desktop\n' "$(id -un)" \
  >"$test_root/var/lib/sddm/state.conf"
BLARCHY_REPO_PATH="$ROOT" \
  BLARCHY_INSTALL_ROOT="$test_root" \
  BLARCHY_INSTALL_USER="$(id -un)" \
  BLARCHY_INSTALL_SKIP_SERVICES=1 \
  bash "$ROOT/install/standalone/system.sh"

stale_checkout_command="$ROOT/bin/blarchy-stale-test"
stale_previous_command=/opt/previous-blarchy/bin/omarchy-previous-test
third_party_command=/opt/third-party/bin/omarchy-third-party-test
ln -s /usr/local/share/blarchy/bin/omarchy-stale-test \
  "$test_root/usr/local/bin/omarchy-stale-test"
ln -s "$stale_checkout_command" "$test_root/usr/local/bin/blarchy-stale-test"
ln -s "$stale_previous_command" "$test_root/usr/local/bin/omarchy-previous-test"
ln -s "$third_party_command" "$test_root/usr/local/bin/omarchy-third-party-test"
printf "export BLARCHY_SOURCE_PATH='/opt/previous-blarchy'\n" >>"$test_root/etc/blarchy.conf"
touch "$test_root/usr/local/bin/omarchy-user-command"

BLARCHY_REPO_PATH="$ROOT" \
  BLARCHY_INSTALL_ROOT="$test_root" \
  BLARCHY_INSTALL_SKIP_SERVICES=1 \
  bash "$ROOT/install/standalone/system.sh"

for stale_link in \
  "$test_root/usr/local/bin/omarchy-stale-test" \
  "$test_root/usr/local/bin/blarchy-stale-test" \
  "$test_root/usr/local/bin/omarchy-previous-test"; do
  [[ ! -L $stale_link ]] ||
    fail "system integration removes stale BLARCHY-owned command links" "$stale_link"
done
[[ $(readlink "$test_root/usr/local/bin/omarchy-third-party-test") == "$third_party_command" ]] ||
  fail "system integration preserves third-party command links"
[[ -f $test_root/usr/local/bin/omarchy-user-command && ! -L $test_root/usr/local/bin/omarchy-user-command ]] ||
  fail "system integration preserves non-symlink commands"

runtime="$test_root/usr/local/share/blarchy"
[[ -d $runtime && ! -L $runtime ]] ||
  fail "system integration installs a standalone runtime snapshot"
grep -Fxq '#!/bin/python3' "$test_root/usr/bin/powerprofilesctl" ||
  fail "standalone system integration pins powerprofilesctl to system Python"
pass "powerprofilesctl is safe with mise-enabled desktop PATHs"
[[ $(stat -c %a "$runtime") == "755" ]] ||
  fail "installed runtime is traversable by desktop users"
grep -Fq 'cp -a --no-preserve=ownership' "$ROOT/install/standalone/system.sh" ||
  fail "system integration does not preserve user ownership in system paths"
[[ -f $runtime/bin/omarchy && -f $runtime/bin/blarchy ]] ||
  fail "runtime snapshot includes compatibility and BLARCHY command surfaces"
[[ $(readlink "$test_root/usr/share/omarchy") == /usr/local/share/blarchy ]] ||
  fail "Omarchy compatibility path resolves to the installed BLARCHY runtime"
[[ $(readlink "$test_root/usr/local/bin/omarchy") == /usr/local/share/blarchy/bin/omarchy ]] ||
  fail "compatibility commands resolve through the installed runtime"
[[ $(readlink "$test_root/usr/local/bin/blarchy") == /usr/local/share/blarchy/bin/blarchy ]] ||
  fail "BLARCHY commands resolve through the installed runtime"
if find "$test_root/usr/local/bin" -type l -lname "$ROOT/*" -print -quit | grep -q .; then
  fail "installed commands do not link into the source checkout"
fi
[[ -f $test_root/usr/share/wayland-sessions/omarchy.desktop ]] ||
  fail "system integration installs the BLARCHY session"
grep -Fxq '[Users]' "$ROOT/etc/sddm.conf.d/20-login.conf" ||
  fail "SDDM login defaults use remembered-user mode"
if grep -Fq '[Autologin]' "$ROOT/etc/sddm.conf.d/20-login.conf"; then
  fail "SDDM login defaults do not enable autologin"
fi
grep -Fxq "User=$(id -un)" "$test_root/var/lib/sddm/state.conf" ||
  fail "system integration seeds the invoking SDDM user"
grep -Fxq 'Session=omarchy.desktop' "$test_root/var/lib/sddm/state.conf" ||
  fail "system integration seeds the installed BLARCHY session"
if rg -q 'Qt\.DisplayRole' "$ROOT/default/sddm/omarchy/Main.qml"; then
  fail "SDDM theme reads explicit user/session model roles"
fi
[[ -f $test_root/usr/share/pixmaps/omarchy.png ]] ||
  fail "system integration retains the compatibility logo asset"
[[ -f $test_root/usr/share/pixmaps/blarchy.png ]] ||
  fail "system integration installs the BLARCHY Fastfetch logo asset"
[[ -f $test_root/etc/firefox/policies/policies.json ]] ||
  fail "system integration installs the Firefox policy"
[[ -f $test_root/etc/pam.d/omarchy-lock-password ]] ||
  fail "system integration installs lock-screen authentication"
[[ -f $test_root/etc/systemd/system.conf.d/10-faster-shutdown.conf ]] ||
  fail "system integration installs the faster system shutdown timeout"
[[ -f $test_root/etc/systemd/logind.conf.d/30-omarchy-lid-handler.conf ]] ||
  fail "system integration installs the validated lid handler policy"
grep -Fxq 'HandleLidSwitch=ignore' \
  "$test_root/etc/systemd/logind.conf.d/30-omarchy-lid-handler.conf" ||
  fail "validated lid handler policy disables logind's direct lid action"
grep -Fxq 'DefaultTimeoutStopSec=5s' \
  "$test_root/etc/systemd/system.conf.d/10-faster-shutdown.conf" ||
  fail "system integration configures a five-second system shutdown timeout"
[[ -f $test_root/usr/lib/systemd/system/user@.service.d/faster-shutdown.conf ]] ||
  fail "system integration installs the faster user-manager shutdown timeout"
grep -Fxq 'TimeoutStopSec=5s' \
  "$test_root/usr/lib/systemd/system/user@.service.d/faster-shutdown.conf" ||
  fail "system integration configures a five-second user-manager shutdown timeout"
[[ ! -e $test_root/usr/lib/systemd/user@.service.d/faster-shutdown.conf ]] ||
  fail "system integration does not place the user-manager drop-in outside the system unit tree"
grep -Fxq "export BLARCHY_PATH='/usr/local/share/blarchy'" "$test_root/etc/blarchy.conf" ||
  fail "system integration records the installed runtime"
grep -Fxq "export BLARCHY_INSTALL='/usr/local/share/blarchy/install'" "$test_root/etc/blarchy.conf" ||
  fail "system integration records the installed setup path"
grep -Fxq "export BLARCHY_SOURCE_PATH='$ROOT'" "$test_root/etc/blarchy.conf" ||
  fail "system integration records the explicit update source"
grep -Fxq "export BLARCHY_INSTALL_MODE='standalone'" "$test_root/etc/blarchy.conf" ||
  fail "system integration records standalone ownership"
grep -Fxq "export BLARCHY_VERSION='$(<"$ROOT/version")'" "$test_root/etc/blarchy.conf" ||
  fail "system integration records the installed BLARCHY version"
grep -Fq 'export OMARCHY_PATH="${BLARCHY_PATH:-/usr/local/share/blarchy}"' \
  "$test_root/etc/omarchy.conf" ||
  fail "legacy environment is only a compatibility alias"
while IFS=' ' read -r unit command; do
  override="$test_root/etc/systemd/user/$unit.d/10-blarchy-standalone.conf"
  grep -Fxq "ExecStart=/usr/local/bin/$command" "$override" ||
    fail "standalone user service resolves its command" "$unit"
done <<'UNITS'
blarchy-migrate-notify.service blarchy-migrate-notify
omarchy-migrate-notify.service omarchy-migrate-notify
omarchy-recover-internal-monitor.service omarchy-hw-recover-internal-monitor
omarchy-sleep-lock.service omarchy-system-sleep-monitor
omarchy-tailscale-receive.service omarchy-tailscale-receive
UNITS
[[ ! -e $test_root/boot ]] ||
  fail "system integration creates no boot files"
pass "system integration is idempotent and bootloader-agnostic"

pending_migrations=$(
  BLARCHY_INSTALL_CONFIG="$test_root/etc/missing-blarchy.conf" \
    BLARCHY_INSTALL_MODE=standalone \
    BLARCHY_MIGRATION_STATE="$migration_state" \
    OMARCHY_MIGRATION_STATE="$migration_state" \
    BLARCHY_PATH="$runtime" \
    bash "$ROOT/bin/blarchy-migrate" --pending
)
if grep -Fq '1784917531.sh' <<<"$pending_migrations"; then
  fail "standalone migration checks include a boot-owned migration"
fi
grep -Fq '1781043107.sh' <<<"$pending_migrations" ||
  fail "standalone migration checks still include safe migrations"
pass "standalone mode excludes boot-owned migrations"

if grep -Fq 'omarchy-keyring' "$ROOT/bin/omarchy-update-keyring"; then
  fail "updates do not trust the Omarchy package keyring"
fi
if rg -q 'cp .*pacman\.(conf|d)|default/pacman/' "$ROOT/bin/omarchy-refresh-pacman"; then
  fail "pacman refresh does not replace user repository configuration"
fi
if rg -q 'omarchy-refresh-(limine|plymouth)' "$ROOT/bin/omarchy-reinstall-configs"; then
  fail "config reset does not alter boot configuration"
fi
pass "update and reset paths preserve user-owned package and boot configuration"

grep -Fq 'exec bash "$source_path/install.sh"' "$ROOT/bin/omarchy-reinstall-pkgs" ||
  fail "package reinstall does not reuse the standalone package resolver"
grep -Fxq 'exec yay -Syu "$@"' "$ROOT/bin/omarchy-update" ||
  fail "normal update path does not use yay directly"
if rg -q 'omarchy-update-dev|omarchy-snapshot|omarchy-migrate' "$ROOT/bin/omarchy-update"; then
  fail "normal package updates still trigger BLARCHY-owned state changes"
fi
pass "normal updates are standard Arch and AUR updates"
