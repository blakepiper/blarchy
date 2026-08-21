#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

hypr_entry="$ROOT/config/hypr/hyprland.lua"
hypr_paths="$ROOT/default/hypr/paths.lua"
shell_root="$ROOT/shell/shell.qml"
fastfetch_config="$ROOT/etc/fastfetch/config.jsonc"
menu_config="$ROOT/default/omarchy/omarchy-menu.jsonc"

grep -Fq 'os.getenv("RICE_PATH")' "$hypr_entry" &&
  grep -Fq 'os.getenv("OMARCHY_PATH")' "$hypr_entry" &&
  grep -Fq 'rice_path = "/usr/local/share/rice"' "$hypr_entry" ||
  fail "Hyprland defaults to the installed RICE runtime"
grep -Fq 'Quickshell.env("RICE_PATH") || Quickshell.env("OMARCHY_PATH") || "/usr/local/share/rice"' "$shell_root" ||
  fail "Quickshell defaults to the installed RICE runtime"
grep -Fq 'quickshell -n -p $RICE_PATH/shell' "$ROOT/default/hypr/autostart.lua" ||
  fail "Hyprland launches the installed RICE shell"
pass "desktop startup prefers the installed RICE runtime"

default_path=$(env -u RICE_PATH -u OMARCHY_PATH lua -e \
  'local paths = assert(loadfile(arg[0]))(); print(paths.rice_path)' "$hypr_paths")
[[ $default_path == "/usr/local/share/rice" ]] ||
  fail "Hyprland runtime path is checkout-independent" "$default_path"

compat_path=$(env -u RICE_PATH OMARCHY_PATH=/tmp/legacy-runtime lua -e \
  'local paths = assert(loadfile(arg[0]))(); print(paths.rice_path)' "$hypr_paths")
[[ $compat_path == "/tmp/legacy-runtime" ]] ||
  fail "Hyprland preserves the OMARCHY_PATH compatibility override" "$compat_path"

native_path=$(RICE_PATH=/tmp/installed-runtime OMARCHY_PATH=/tmp/legacy-runtime lua -e \
  'local paths = assert(loadfile(arg[0]))(); print(paths.rice_path)' "$hypr_paths")
[[ $native_path == "/tmp/installed-runtime" ]] ||
  fail "RICE_PATH takes precedence over the compatibility override" "$native_path"
pass "desktop runtime path selection is deterministic"

jq -e '
  .logo.type == "builtin" and
  .logo.source == "arch" and
  any(.modules[]; type == "object" and .type == "os" and .key == " OS") and
  any(.modules[]; type == "object" and .type == "custom" and .format == "Personal Arch")
' "$fastfetch_config" >/dev/null || fail "Fastfetch reports the personal Arch environment"
pass "Fastfetch uses the default Arch logo and personal environment label"

grep -Fq "'yay -Syu'" "$menu_config" ||
  fail "menu exposes the Arch/AUR update route"
if rg -q 'basecamp/omarchy|pkgs\.omarchy\.org|mirror\.omarchy\.org' \
  "$hypr_entry" "$ROOT/default/hypr/autostart.lua" "$ROOT/shell/plugins/bar/widgets/SystemUpdate.qml" \
  "$fastfetch_config" "$menu_config"; then
  fail "active desktop behavior references Omarchy update infrastructure"
fi
pass "desktop update actions use normal Arch package sources"
