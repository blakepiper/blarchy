#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

require_command lua

resolved_input() {
  local -a environment

  if (( $# )); then
    environment=(env OMARCHY_PATH="$ROOT" OMARCHY_XKB_LAYOUT="$1" OMARCHY_XKB_VARIANT="${2-}")
  else
    environment=(env -u OMARCHY_XKB_LAYOUT -u OMARCHY_XKB_VARIANT OMARCHY_PATH="$ROOT")
  fi

  "${environment[@]}" lua <<'LUA'
package.path = os.getenv("OMARCHY_PATH") .. "/?.lua;" .. package.path

hl = {
  config = function(config)
    local input = config.input
    print(("[%s] [%s] [%s]"):format(input.kb_layout, input.kb_variant, input.kb_options))
  end,
}

o = { window = function() end }

require("default.hypr.input")
LUA
}

assert_input() {
  local description="$1"
  local expected="$2"
  local actual

  if (( $# > 2 )); then
    actual=$(resolved_input "$3" "${4-}")
  else
    actual=$(resolved_input)
  fi

  [[ $actual == "$expected" ]] ||
    fail "$description" "expected: $expected"$'\n'"actual:   $actual"
  pass "$description"
}

base_options="compose:caps,shift:both_capslock_cancel"
toggle_options="$base_options,grp:alts_toggle"

assert_input "missing keyboard environment falls back to us" "[us] [] [$base_options]"
assert_input "us layout passes through" "[us] [intl] [$base_options]" us intl
assert_input "latin layouts are left alone" "[de] [nodeadkeys] [$base_options]" de nodeadkeys
assert_input "non-latin layout gains us in front" "[us,ara] [,] [$toggle_options]" ara
assert_input "prepended us keeps variants aligned" "[us,ru] [,phonetic] [$toggle_options]" ru phonetic
assert_input "non-latin layout in front gains us even when us trails" "[us,il,us] [,] [$toggle_options]" il,us

if rg -q 'io\.(open|popen)|os\.execute' "$ROOT/default/hypr/input.lua"; then
  fail "Hyprland input defaults perform no blocking I/O during config reload"
fi
pass "Hyprland input defaults perform no blocking I/O during config reload"

hooks_conf="$ROOT/etc/mkinitcpio.conf.d/omarchy_hooks.conf"
input_lua="$ROOT/default/hypr/input.lua"

hooks_layouts=$(awk -F')' '/\) ;;$/ { gsub(/[[:space:]|]+/, "\n", $1); print $1 }' "$hooks_conf" | grep '^[a-z]\+$' | sort)
lua_layouts=$(sed -n '/^local non_latin_layouts =/,+1p' "$input_lua" | grep -o '"[^"]*"' | tr -d '"' | tr ' ' '\n' | grep '^[a-z]\+$' | sort)

[[ -n $hooks_layouts ]] || fail "non-latin layout list is readable from omarchy_hooks.conf"
[[ $hooks_layouts == "$lua_layouts" ]] ||
  fail "non-latin layout lists stay in sync" "$(diff <(echo "$hooks_layouts") <(echo "$lua_layouts"))"
pass "non-latin layout lists stay in sync with the initramfs hook"
