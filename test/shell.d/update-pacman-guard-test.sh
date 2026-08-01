#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

for command_line in \
  'pacman -Syu --noconfirm' \
  'pacman --sync --refresh --sysupgrade' \
  'pacman -S firefox'; do
  OMARCHY_PACMAN_CMDLINE="$command_line" \
    "$ROOT/bin/omarchy-update-pacman-guard" ||
    fail "compatibility guard blocks standard Arch package management" "$command_line"
done

if grep -q '^AbortOnFail$' "$ROOT/default/libalpm/hooks/00-omarchy-update-guard.hook"; then
  fail "legacy ALPM hook can abort a package transaction"
fi
pass "BLARCHY never blocks pacman or yay updates"
