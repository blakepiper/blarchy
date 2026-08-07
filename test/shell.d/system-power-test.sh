#!/bin/bash

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
call_log="$test_tmp/calls.log"
mkdir -p "$mock_bin"

cat >"$mock_bin/systemd-run" <<'SH'
#!/bin/bash

printf 'systemd-run %s\n' "$*" >>"$CALL_LOG"
[[ ${FAIL_SYSTEMD_RUN:-false} == "true" ]] && exit 1
exit 0
SH

for command in pkexec sudo; do
  cat >"$mock_bin/$command" <<'SH'
#!/bin/bash

printf '%s %s\n' "$(basename "$0")" "$*" >>"$CALL_LOG"
command_name=${1##*/}
shift
"$MOCK_BIN/$command_name" "$@"
SH
done

for command in omarchy-state omarchy-hyprland-window-close-all sleep; do
  cat >"$mock_bin/$command" <<'SH'
#!/bin/bash

printf '%s %s\n' "$(basename "$0")" "$*" >>"$CALL_LOG"
SH
done
chmod +x "$mock_bin"/*

run_power_command() {
  local action="$1"

  : >"$call_log"
  PATH="$mock_bin:$PATH" CALL_LOG="$call_log" MOCK_BIN="$mock_bin" "$ROOT/bin/omarchy-system-$action"
}

assert_power_calls() {
  local action="$1"
  local systemctl_action="$2"
  local expected_log="$test_tmp/$action-expected.log"

  cat >"$expected_log" <<EOF
pkexec systemd-run --system --collect --quiet --on-active=2s --timer-property=AccuracySec=100ms systemctl $systemctl_action --no-wall
systemd-run --system --collect --quiet --on-active=2s --timer-property=AccuracySec=100ms systemctl $systemctl_action --no-wall
omarchy-state clear re*-required
omarchy-hyprland-window-close-all 
sleep 1
EOF

  diff -u "$expected_log" "$call_log" || fail "$action runs after being scheduled outside the terminal scope"
  pass "$action runs after being scheduled outside the terminal scope"
}

run_power_command reboot
assert_power_calls reboot reboot

run_power_command shutdown
assert_power_calls shutdown poweroff

for action in reboot shutdown; do
  : >"$call_log"
  if PATH="$mock_bin:$PATH" CALL_LOG="$call_log" MOCK_BIN="$mock_bin" FAIL_SYSTEMD_RUN=true "$ROOT/bin/omarchy-system-$action"; then
    fail "$action aborts when scheduling fails"
  fi

  if (( $(wc -l <"$call_log") != 2 )); then
    fail "$action leaves state and windows alone when scheduling fails"
  fi
  pass "$action leaves state and windows alone when scheduling fails"
done

for action in reboot shutdown; do
  : >"$call_log"
  script -qefc "PATH='$mock_bin:$PATH' CALL_LOG='$call_log' MOCK_BIN='$mock_bin' '$ROOT/bin/omarchy-system-$action'" /dev/null >/dev/null

  expected_log="$test_tmp/$action-terminal-expected.log"
  systemctl_action=poweroff
  [[ $action == "reboot" ]] && systemctl_action=reboot
  {
    printf '%s\n' \
      "sudo systemd-run --system --collect --quiet --on-active=2s --timer-property=AccuracySec=100ms systemctl $systemctl_action --no-wall" \
      "systemd-run --system --collect --quiet --on-active=2s --timer-property=AccuracySec=100ms systemctl $systemctl_action --no-wall" \
      'omarchy-state clear re*-required' \
      'omarchy-hyprland-window-close-all ' \
      'sleep 1'
  } >"$expected_log"

  diff -u "$expected_log" "$call_log" || fail "$action uses terminal sudo when launched from a terminal"
  pass "$action uses terminal sudo when launched from a terminal"
done
