#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

run_bootstrap() {
  local shell_bin="$1"
  local bootstrap="$2"
  local home="$3"
  local path_value="$4"

  HOME="$home" PATH="$path_value" "$shell_bin" -c '
    . "$1"
    printf "%s\n%s\n%s\n" "$BLARCHY_PATH" "$OMARCHY_PATH" "$PATH"
  ' sh "$bootstrap"
}

assert_path_first() {
  local path_value="$1"
  local entry="$2"
  local description="$3"

  [[ ${path_value%%:*} == "$entry" ]] || fail "$description" "expected first PATH entry: $entry\nactual PATH: $path_value"
  pass "$description"
}

assert_path_present() {
  local path_value="$1"
  local entry="$2"
  local description="$3"

  case ":$path_value:" in
    *":$entry:"*) pass "$description" ;;
    *) fail "$description" "PATH does not contain $entry in $path_value" ;;
  esac
}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

home="$tmpdir/home"
mkdir -p "$tmpdir/active/bin" "$tmpdir/unrelated/bin"

# Test against a copy so the test controls both installed and dev configuration.
bootstrap="$tmpdir/env-bootstrap"
sed \
  -e "s#/etc/blarchy.conf#$tmpdir/blarchy.conf#g" \
  -e "s#/etc/blarchy-dev.conf#$tmpdir/blarchy-dev.conf#g" \
  -e "s#/etc/omarchy.conf#$tmpdir/omarchy.conf#g" \
  "$ROOT/default/bash/env-bootstrap" >"$bootstrap"

printf 'export BLARCHY_PATH="/usr/local/share/blarchy"\n' >"$tmpdir/blarchy.conf"
mapfile -t default_result < <(run_bootstrap bash "$bootstrap" "$home" "$tmpdir/unrelated/bin:/usr/bin")
default_path=${default_result[2]}

[[ ${default_result[0]} == /usr/local/share/blarchy ]] || fail "env-bootstrap resolves installed BLARCHY_PATH" "actual: ${default_result[0]}"
[[ ${default_result[1]} == /usr/local/share/blarchy ]] || fail "env-bootstrap aliases OMARCHY_PATH to BLARCHY_PATH" "actual: ${default_result[1]}"
pass "env-bootstrap resolves installed BLARCHY runtime"
assert_path_present "$default_path" "$tmpdir/unrelated/bin" "env-bootstrap preserves PATH entries in default mode"

printf 'export BLARCHY_PATH="%s"\nexport OMARCHY_PATH="$BLARCHY_PATH"\n' "$tmpdir/active" >"$tmpdir/blarchy-dev.conf"
mapfile -t linked_result < <(run_bootstrap bash "$bootstrap" "$home" "$tmpdir/unrelated/bin:/usr/bin")
linked_path=${linked_result[2]}

[[ ${linked_result[0]} == "$tmpdir/active" ]] || fail "env-bootstrap resolves dev-linked BLARCHY_PATH" "actual: ${linked_result[0]}"
[[ ${linked_result[1]} == "$tmpdir/active" ]] || fail "env-bootstrap aliases OMARCHY_PATH in dev mode" "actual: ${linked_result[1]}"
pass "env-bootstrap resolves explicit dev runtime"
assert_path_first "$linked_path" "$tmpdir/active/bin" "env-bootstrap prepends active checkout bin in linked mode"
assert_path_present "$linked_path" "$tmpdir/unrelated/bin" "env-bootstrap preserves unrelated PATH entries in linked mode"

mapfile -t linked_duplicate_result < <(run_bootstrap bash "$bootstrap" "$home" "$tmpdir/active/bin:/usr/bin")
linked_duplicate_path=${linked_duplicate_result[2]}
[[ $linked_duplicate_path == "$tmpdir/active/bin:/usr/bin" ]] || fail "env-bootstrap does not duplicate active checkout bin" "actual PATH: $linked_duplicate_path"
pass "env-bootstrap does not duplicate active checkout bin"

if command -v zsh >/dev/null 2>&1; then
  mapfile -t zsh_result < <(run_bootstrap zsh "$bootstrap" "$home" "$tmpdir/unrelated/bin:/usr/bin")
  zsh_path=${zsh_result[2]}
  assert_path_first "$zsh_path" "$tmpdir/active/bin" "env-bootstrap works when sourced by zsh"
  assert_path_present "$zsh_path" "$tmpdir/unrelated/bin" "env-bootstrap zsh mode preserves unrelated PATH entries"
fi
