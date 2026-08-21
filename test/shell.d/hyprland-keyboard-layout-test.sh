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

base_options="compose:caps"
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
