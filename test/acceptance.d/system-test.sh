#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

status=0

verify_core_packages() {
  local package
  local -a missing=()

  while IFS= read -r package; do
    [[ -z $package || $package == \#* ]] && continue
    pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
  done <"$OMARCHY_PATH/install/packages"

  (( ${#missing[@]} == 0 )) || fail "all personal packages are installed" "missing packages: ${missing[*]}"
  pass "all personal packages are installed (${#missing[@]} missing)"
}

verify_defaults() {
  [[ $(omarchy-default-browser) == "firefox" ]] || fail "Firefox is the default browser"
  pass "Firefox is the default browser"

  [[ $(omarchy-default-terminal) == "alacritty" ]] || fail "Alacritty is the default terminal"
  pass "Alacritty is the default terminal"

  [[ $(omarchy-default-editor) == "codium" ]] || fail "VSCodium is the default editor"
  pass "VSCodium is the default editor"

  [[ $(omarchy-theme-current) != "Unknown" ]] || fail "a current theme is configured"
  pass "a current theme is configured"

  [[ $(omarchy-theme-bg-current) != "Unknown" ]] || fail "a current background is configured"
  pass "a current background is configured"

  [[ -n $(omarchy-font-current) ]] || fail "a monospace font is configured"
  pass "a monospace font is configured"

  [[ $(xdg-mime query default x-scheme-handler/http) == "firefox.desktop" ]] || fail "HTTP MIME handling uses Firefox"
  [[ $(xdg-mime query default inode/directory) == "org.gnome.Nautilus.desktop" ]] || fail "directory MIME handling uses Nautilus"
  pass "desktop MIME handlers are configured"
}

verify_services() {
  local unit

  for unit in \
    avahi-daemon.service cups.service cups-browsed.service \
    NetworkManager.service power-profiles-daemon.service sddm.service \
    systemd-resolved.service ufw.service; do
    systemctl is-enabled --quiet "$unit" || fail "core system services are enabled" "$unit is not enabled"
  done
  pass "core system services are enabled"

  for unit in NetworkManager.service systemd-resolved.service ufw.service; do
    systemctl is-active --quiet "$unit" || fail "critical system services are running" "$unit is not active"
  done
  pass "critical system services are running"

  systemctl --user is-active --quiet pipewire.service pipewire-pulse.service wireplumber.service ||
    fail "user audio services are running"
  pass "user audio services are running"
}

verify_runtime_tools() {
  timeout 10 fastfetch --pipe false >/dev/null 2>&1 || fail "Fastfetch can read system information"
  pass "Fastfetch can read system information"

  local command
  for command in alacritty firefox gimp git nautilus node npm pip python codium codex claude omp spotify steam; do
    command -v "$command" >/dev/null || fail "RICE default commands are installed" "$command is missing"
  done
  tmux -V >/dev/null || fail "Tmux is installed and runnable"
  mise --version >/dev/null || fail "Mise is installed and runnable"
  pass "RICE default commands are installed and core terminal tools are runnable"
}

verify_user_setup() {
  local directory

  for directory in DESKTOP DOCUMENTS DOWNLOAD PICTURES; do
    [[ -d $(xdg-user-dir "$directory") ]] || fail "XDG user directories exist" "$directory is missing"
  done
  pass "XDG user directories exist"

  [[ -e $HOME/.local/state/omarchy/current/theme ]] || fail "current theme state exists"
  [[ -e $HOME/.local/state/omarchy/current/background ]] || fail "current background state exists"
  [[ -s $HOME/.config/omarchy/shell.json ]] || fail "shell configuration exists"
  jq empty "$HOME/.config/omarchy/shell.json" || fail "shell configuration is valid JSON"
  pass "RICE user state and shell configuration exist"
}

for check in verify_core_packages verify_defaults verify_services verify_runtime_tools verify_user_setup; do
  if ! ("$check"); then
    status=1
  fi
done

exit $status
