#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

command="$ROOT/bin/omarchy-xfce-nightlight"
setup="$ROOT/install/user/xfce-nightlight.sh"

[[ -x $command ]]
[[ -x $setup ]]
bash -n "$command"
bash -n "$setup"

[[ -f $ROOT/config/gammastep/config.ini ]]
rg -q '^adjustment-method=randr$' "$ROOT/config/gammastep/config.ini"
rg -q 'gammastep -O' "$command"
rg -q 'gammastep -x' "$command"
rg -q 'nightlight-xfce' "$command"
rg -q 'omarchy-xfce-nightlight' "$setup"
rg -q 'printf -v command_path' "$setup"
rg -q 'update-period.*-s 5000' "$setup"
rg -q '#fff' "$ROOT/default/omarchy/icons/nightlight-full-white.svg"
rg -q '#fff' "$ROOT/default/omarchy/icons/nightlight-empty-white.svg"

test_home=$(mktemp -d)
test_bin=$(mktemp -d)
trap 'rm -rf -- "$test_home" "$test_bin"' EXIT

printf '%s\n' '#!/bin/bash' 'printf "%s\\n" "$*" >>"$GAMMASTEP_LOG"' >"$test_bin/gammastep"
chmod 0755 "$test_bin/gammastep"

run_widget() {
  HOME="$test_home" \
  PATH="$test_bin:$PATH" \
  RICE_PATH="$ROOT" \
  GAMMASTEP_LOG="$test_home/gammastep.log" \
    "$command" "$@"
}

rendered=$(run_widget render)
[[ $rendered == *"$ROOT/default/omarchy/icons/nightlight-empty-white.svg"* ]]
[[ $rendered == *"<click>"*toggle*"</click>"* ]]

run_widget toggle
[[ -f $test_home/.local/state/omarchy/indicators/nightlight-xfce ]]
[[ $(<"$test_home/gammastep.log") == "-O 3500" ]]

rendered=$(run_widget render)
[[ $rendered == *"$ROOT/default/omarchy/icons/nightlight-full-white.svg"* ]]
[[ $rendered == *"Night Light: 3500K (click to turn off)"* ]]

run_widget toggle
[[ ! -e $test_home/.local/state/omarchy/indicators/nightlight-xfce ]]
[[ $(tail -n 1 "$test_home/gammastep.log") == "-x" ]]

pass "XFCE Gammastep nightlight widget is wired"
