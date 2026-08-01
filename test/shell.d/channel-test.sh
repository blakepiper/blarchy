#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
mkdir -p "$stub_bin"

for command_name in git sudo pacman omarchy-refresh-pacman omarchy-update; do
  cat >"$stub_bin/$command_name" <<'SH'
#!/bin/bash
printf '%s\n' "$0 $*" >>"$BLARCHY_CHANNEL_TEST_LOG"
SH
  chmod +x "$stub_bin/$command_name"
done

for channel in stable rc edge dev; do
  log="$test_tmp/$channel.log"
  if BLARCHY_CHANNEL_TEST_LOG="$log" PATH="$stub_bin:$PATH" \
    "$ROOT/bin/omarchy-channel-set" "$channel" >"$test_tmp/$channel.out" 2>"$test_tmp/$channel.err"; then
    fail "BLARCHY refuses the Omarchy $channel package channel"
  fi

  grep -Fq 'BLARCHY does not use Omarchy package channels' "$test_tmp/$channel.err" ||
    fail "disabled channel command explains BLARCHY ownership" "$(cat "$test_tmp/$channel.err")"
  [[ ! -e $log ]] || fail "disabled channel command makes no external changes" "$(cat "$log")"
done

pass "BLARCHY disables all upstream Omarchy package channels without side effects"

grep -Fq 'https://github.com/basecamp/omarchy.git' "$ROOT/bin/omarchy-channel-set" &&
  fail "channel command contains no automatic Basecamp clone path"
pass "BLARCHY channel command cannot clone Basecamp/Omarchy"
