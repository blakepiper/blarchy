#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

hypr_entry="$ROOT/config/hypr/hyprland.lua"
hypr_paths="$ROOT/default/hypr/paths.lua"
shell_root="$ROOT/shell/shell.qml"
fastfetch_config="$ROOT/etc/fastfetch/config.jsonc"
menu_config="$ROOT/default/omarchy/omarchy-menu.jsonc"

grep -Fq 'os.getenv("BLARCHY_PATH") or os.getenv("OMARCHY_PATH") or "/usr/local/share/blarchy"' "$hypr_entry" ||
  fail "Hyprland defaults to the installed BLARCHY runtime"
grep -Fq 'Quickshell.env("BLARCHY_PATH") || Quickshell.env("OMARCHY_PATH") || "/usr/local/share/blarchy"' "$shell_root" ||
  fail "Quickshell defaults to the installed BLARCHY runtime"
grep -Fq 'quickshell -n -p $BLARCHY_PATH/shell' "$ROOT/default/hypr/autostart.lua" ||
  fail "Hyprland launches the installed BLARCHY shell"
pass "desktop startup prefers the installed BLARCHY runtime"

default_path=$(env -u BLARCHY_PATH -u OMARCHY_PATH lua -e \
  'local paths = assert(loadfile(arg[0]))(); print(paths.blarchy_path)' "$hypr_paths")
[[ $default_path == "/usr/local/share/blarchy" ]] ||
  fail "Hyprland runtime path is checkout-independent" "$default_path"

compat_path=$(env -u BLARCHY_PATH OMARCHY_PATH=/tmp/legacy-runtime lua -e \
  'local paths = assert(loadfile(arg[0]))(); print(paths.blarchy_path)' "$hypr_paths")
[[ $compat_path == "/tmp/legacy-runtime" ]] ||
  fail "Hyprland preserves the OMARCHY_PATH compatibility override" "$compat_path"

native_path=$(BLARCHY_PATH=/tmp/installed-runtime OMARCHY_PATH=/tmp/legacy-runtime lua -e \
  'local paths = assert(loadfile(arg[0]))(); print(paths.blarchy_path)' "$hypr_paths")
[[ $native_path == "/tmp/installed-runtime" ]] ||
  fail "BLARCHY_PATH takes precedence over the compatibility override" "$native_path"
pass "desktop runtime path selection is deterministic"

jq -e '
  .logo.type == "builtin" and
  .logo.source == "arch" and
  any(.modules[]; type == "object" and .type == "os" and .key == " OS") and
  any(.modules[]; type == "object" and .type == "custom" and .format == "BLARCHY") and
  any(.modules[]; type == "object" and .type == "command" and .text == "blarchy version") and
  all(.modules[]; type != "object" or ((.text // "") | contains("omarchy-version-channel") | not)) and
  all(.modules[]; type != "object" or ((.text // "") | contains("omarchy-version-branch") | not))
' "$fastfetch_config" >/dev/null || fail "Fastfetch reports Arch and BLARCHY from stable assets"
pass "Fastfetch uses the default Arch logo and native version command"

grep -Fq "'blarchy system update'" "$menu_config" ||
  fail "menu exposes the Arch/AUR update route"
grep -Fq "'blarchy update'" "$menu_config" ||
  fail "menu exposes the independent BLARCHY update route"
if rg -q 'basecamp/omarchy|pkgs\.omarchy\.org|mirror\.omarchy\.org' \
  "$hypr_entry" "$ROOT/default/hypr/autostart.lua" "$ROOT/shell/plugins/bar/widgets/SystemUpdate.qml" \
  "$fastfetch_config" "$menu_config"; then
  fail "active desktop behavior references Omarchy update infrastructure"
fi
pass "desktop update actions have no operational Omarchy source"
