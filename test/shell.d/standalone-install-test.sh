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

grep -Fq 'pacman -Syu --needed --noconfirm base-devel git' "$ROOT/install.sh" ||
  fail "standalone installer updates Arch and installs build prerequisites"
if grep -Fxq git "$ROOT/install/omarchy-base.packages"; then
  fail "standalone manifest duplicates the required Git prerequisite"
fi
pass "Git remains an installer prerequisite rather than a bundled default"
grep -Fq 'pacman -S --needed --noconfirm "${repo_packages[@]}"' "$ROOT/install.sh" ||
  fail "standalone installer installs repository packages before AUR builds"
grep -Fq 'yay -S --needed --noconfirm "${aur_packages[@]}"' "$ROOT/install.sh" ||
  fail "standalone installer installs AUR packages idempotently"
grep -Fq 'base-devel git rust' "$ROOT/install.sh" ||
  fail "standalone installer uses Arch rust as its fresh-install AUR toolchain"
for provider in rust rustup cargo; do
  if grep -Fxq "$provider" "$ROOT/install/omarchy-base.packages"; then
    fail "package manifest duplicates the installer-owned Rust provider" "$provider"
  fi
done
grep -Fq 'yay -Y --devel --save' "$ROOT/install.sh" ||
  fail "standalone installer enables VCS package updates for plain yay -Syu"
grep -Fq 'omarchy-migrate' "$ROOT/install.sh" ||
  fail "explicit BLARCHY source upgrades apply pending migrations"
if grep -Fq 'xdg-settings set' "$ROOT/bin/omarchy-finalize-user"; then
  fail "console finalization does not require a live desktop session"
fi
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

mkdir -p "$test_home/.config/hypr"
printf '%s\n' 'keep-my-binding' >"$test_home/.config/hypr/bindings.lua"
printf '%s\n' '# existing shell config' >"$test_home/.bashrc"

for _ in 1 2; do
  HOME="$test_home" OMARCHY_PATH="$ROOT" \
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

HOME="$test_home" OMARCHY_PATH="$ROOT" \
  bash "$ROOT/install/standalone/user.sh" overwrite
grep -Fq 'Application launcher' "$test_home/.config/hypr/bindings.lua" ||
  fail "explicit config reset overwrites BLARCHY user defaults"
grep -Fxq '# existing shell config' "$test_home/.bashrc" ||
  fail "explicit config reset preserves unrelated bashrc content"
pass "explicit user reset remains scoped to BLARCHY-owned defaults"

for _ in 1 2; do
  BLARCHY_REPO_PATH="$ROOT" \
    BLARCHY_INSTALL_ROOT="$test_root" \
    BLARCHY_INSTALL_SKIP_SERVICES=1 \
    bash "$ROOT/install/standalone/system.sh"
done

[[ $(readlink "$test_root/usr/share/omarchy") == "$ROOT" ]] ||
  fail "system integration links the active checkout"
[[ $(readlink "$test_root/usr/local/bin/omarchy") == "$ROOT/bin/omarchy" ]] ||
  fail "system integration exposes BLARCHY commands"
[[ -f $test_root/usr/share/wayland-sessions/omarchy.desktop ]] ||
  fail "system integration installs the BLARCHY session"
[[ -f $test_root/usr/share/pixmaps/omarchy.png ]] ||
  fail "system integration installs the stable Fastfetch logo asset"
[[ -f $test_root/etc/firefox/policies/policies.json ]] ||
  fail "system integration installs the Firefox policy"
[[ -f $test_root/etc/pam.d/omarchy-lock-password ]] ||
  fail "system integration installs lock-screen authentication"
grep -Fxq 'BLARCHY_INSTALL_MODE=standalone' "$test_root/etc/blarchy.conf" ||
  fail "system integration records standalone ownership"
while IFS=' ' read -r unit command; do
  override="$test_root/etc/systemd/user/$unit.d/10-blarchy-standalone.conf"
  grep -Fxq "ExecStart=/usr/local/bin/$command" "$override" ||
    fail "standalone user service resolves its command" "$unit"
done <<'UNITS'
omarchy-migrate-notify.service omarchy-migrate-notify
omarchy-recover-internal-monitor.service omarchy-hw-recover-internal-monitor
omarchy-sleep-lock.service omarchy-system-sleep-monitor
omarchy-tailscale-receive.service omarchy-tailscale-receive
UNITS
[[ ! -e $test_root/boot ]] ||
  fail "system integration creates no boot files"
pass "system integration is idempotent and bootloader-agnostic"

migration_config="$test_root/etc/blarchy.conf"
pending_migrations=$(
  BLARCHY_INSTALL_CONFIG="$migration_config" \
    OMARCHY_MIGRATION_STATE="$migration_state" \
    OMARCHY_PATH="$ROOT" \
    bash "$ROOT/bin/omarchy-migrate" --pending
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

grep -Fq 'exec "$OMARCHY_PATH/install.sh"' "$ROOT/bin/omarchy-reinstall-pkgs" ||
  fail "package reinstall does not reuse the standalone package resolver"
grep -Fxq 'exec yay -Syu "$@"' "$ROOT/bin/omarchy-update" ||
  fail "normal update path does not use yay directly"
if rg -q 'omarchy-update-dev|omarchy-snapshot|omarchy-migrate' "$ROOT/bin/omarchy-update"; then
  fail "normal package updates still trigger BLARCHY-owned state changes"
fi
pass "normal updates are standard Arch and AUR updates"
