#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

require_command lua

run_application_bindings() {
  local home="$1"
  local prelude="${2:-}"

  HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_STATE_HOME="$home/.local/state" OMARCHY_PATH="$ROOT" OMARCHY_BINDING_PRELUDE="$prelude" lua <<'LUA'
package.path = os.getenv("HOME") .. "/.config/?.lua;" .. os.getenv("OMARCHY_PATH") .. "/?.lua;" .. package.path

local prelude = os.getenv("OMARCHY_BINDING_PRELUDE") or ""
if prelude ~= "" then
  assert(load(prelude))()
end

hl = {
  dsp = {
    exec_cmd = function(command)
      return { kind = "exec", arg = command }
    end,
  },
  bind = function(keys, dispatcher, opts)
    opts = opts or {}
    if opts.description then
      print(keys .. "\t" .. opts.description)
    end
  end,
}

require("default.hypr.helpers")
require("default.hypr.bindings.applications")
LUA
}

run_omarchy_bindings() {
  local home="$1"
  local prelude="${2:-}"

  HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_STATE_HOME="$home/.local/state" OMARCHY_PATH="$ROOT" OMARCHY_BINDING_PRELUDE="$prelude" lua <<'LUA'
package.path = os.getenv("HOME") .. "/.config/?.lua;" .. os.getenv("OMARCHY_PATH") .. "/?.lua;" .. package.path

local function proxy()
  return setmetatable({}, {
    __index = function(self, key)
      local value = proxy()
      rawset(self, key, value)
      return value
    end,
    __call = function()
      return {}
    end,
  })
end

local prelude = os.getenv("OMARCHY_BINDING_PRELUDE") or ""
if prelude ~= "" then
  assert(load(prelude))()
end

hl = setmetatable({
  dsp = proxy(),
  bind = function(keys, dispatcher, opts)
    opts = opts or {}
    if opts.description then
      print(keys .. "\t" .. opts.description)
    end
  end,
  config = function() end,
  env = function() end,
  monitor = function() end,
  window_rule = function() end,
  workspace_rule = function() end,
  layer_rule = function() end,
  gesture = function() end,
  animation = function() end,
  curve = function() end,
  exec_cmd = function() end,
  dispatch = function() end,
  on = function() end,
  timer = function() end,
  get_config = function() return nil end,
  get_active_window = function() return nil end,
}, {
  __index = function()
    return function()
      return {}
    end
  end,
})

require("default.hypr.omarchy")
LUA
}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

fresh_home="$tmpdir/fresh-home"
mkdir -p "$fresh_home"
fresh_output=$(run_application_bindings "$fresh_home")
grep -Fq $'SUPER + RETURN	Terminal' <<<"$fresh_output" || fail "default application bindings include essentials"
grep -Fq $'SUPER + SHIFT + M	Music' <<<"$fresh_output" || fail "default application bindings include Spotify"
if grep -Fq 'ChatGPT' <<<"$fresh_output"; then
  fail "default application bindings exclude the removed ChatGPT web app"
fi
pass "default application bindings load from package defaults"

browser_rule_count=$(grep -c '^o\.window' "$ROOT/default/hypr/apps/browser.lua")
[[ $browser_rule_count -eq 1 ]] ||
  fail "browser window rules stay within Hyprland's Lua reload budget"
pass "browser window rules stay within Hyprland's Lua reload budget"
grep -Fq 'idle_inhibit = "focus"' "$ROOT/default/hypr/apps/browser.lua" ||
  fail "focused browsers inhibit idle screensaver"
pass "focused browsers inhibit idle screensaver"

unbind_block=$(sed -n '/for _, keys in ipairs({/,/}) do/p' "$ROOT/config/hypr/bindings.lua")
for direction in LEFT RIGHT UP DOWN; do
  grep -Fq "\"SUPER + CTRL + $direction\"" <<<"$unbind_block" ||
    fail "BLARCHY bindings unbind inherited SUPER + CTRL + $direction behavior"
done
grep -Fq 'o.bind("SUPER + CTRL + LEFT", "Focus window left", hl.dsp.focus({ direction = "l" }))' "$ROOT/config/hypr/bindings.lua" ||
  fail "BLARCHY bindings focus the window to the left"
grep -Fq 'o.bind("SUPER + CTRL + RIGHT", "Focus window right", hl.dsp.focus({ direction = "r" }))' "$ROOT/config/hypr/bindings.lua" ||
  fail "BLARCHY bindings focus the window to the right"
grep -Fq 'o.bind("SUPER + CTRL + UP", "Focus window above", hl.dsp.focus({ direction = "u" }))' "$ROOT/config/hypr/bindings.lua" ||
  fail "BLARCHY bindings focus the window above"
grep -Fq 'o.bind("SUPER + CTRL + DOWN", "Focus window below", hl.dsp.focus({ direction = "d" }))' "$ROOT/config/hypr/bindings.lua" ||
  fail "BLARCHY bindings focus the window below"
pass "BLARCHY directional focus bindings override inherited behavior"

grep -Fq '"SUPER + C"' <<<"$unbind_block" ||
  fail "BLARCHY bindings unbind inherited SUPER + C clipboard behavior"
grep -Fq 'o.bind("SUPER + C", "VSCodium", { launch = "codium" })' "$ROOT/config/hypr/bindings.lua" ||
  fail "BLARCHY bindings open VSCodium with SUPER + C"
pass "VSCodium opens with SUPER + C"

if grep -Fq 'o.bind("SUPER + ALT + SPACE"' "$ROOT/config/hypr/bindings.lua"; then
  fail "BLARCHY menu does not register both symbolic and physical Space bindings"
fi
grep -Fq 'o.bind("SUPER + ALT + code:65", "BLARCHY menu"' "$ROOT/config/hypr/bindings.lua" ||
  fail "BLARCHY menu keeps one physical Space binding"
if grep -Fq 'o.bind("SUPER + code:46", "Lock system (physical L key)"' "$ROOT/config/hypr/bindings.lua"; then
  fail "lock binding does not register a duplicate physical L fallback"
fi
pass "critical physical key bindings do not toggle twice"

grep -Fq 'o.bind("SUPER + SHIFT + F", "Full screen", hl.dsp.window.fullscreen({ mode = "maximized" }))' \
  "$ROOT/config/hypr/bindings.lua" ||
  fail "fullscreen binding preserves bar and outer padding"
pass "fullscreen binding preserves bar and outer padding"

grep -Fq 'hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto-left", scale = 1 })' \
  "$ROOT/config/hypr/monitors.lua" ||
  fail "HDMI defaults to an extended display layout"
pass "HDMI defaults to an extended display layout"
grep -Fq 'hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true })' \
  "$ROOT/config/hypr/monitors.lua" ||
  fail "HDMI defaults to workspace 1"
for workspace in 2 3 4; do
  grep -Fq "hl.workspace_rule({ workspace = tostring(workspace), monitor = \"HDMI-A-1\" })" \
    "$ROOT/config/hypr/monitors.lua" ||
    fail "HDMI owns workspace $workspace"
done
grep -Fq 'hl.workspace_rule({ workspace = "5", monitor = "eDP-1", default = true })' \
  "$ROOT/config/hypr/monitors.lua" ||
  fail "laptop display defaults to workspace 5"
pass "HDMI owns workspaces 1-4 and laptop owns workspace 5"
grep -Fq 'hl.dsp.workspace.move({ workspace = tostring(workspace), monitor = "HDMI-A-1" })' \
  "$ROOT/config/hypr/monitors.lua" ||
  fail "existing workspaces are reconciled onto HDMI"
grep -Fq 'hl.on("config.reloaded", arrange_workspaces)' "$ROOT/config/hypr/monitors.lua" ||
  fail "workspace placement is reapplied after config reload"
pass "existing workspaces are reconciled after monitor changes"

grep -F 'hl.dsp.send_key_state({ mods = mods, key = key, state = "down" })' "$ROOT/default/hypr/bindings/clipboard.lua" >/dev/null ||
  fail "universal clipboard shortcuts send explicit mods to the focused surface"
pass "universal clipboard shortcuts send explicit mods to the focused surface"

if grep -E 'send_key_state\(\{[^}]*window' "$ROOT/default/hypr/bindings/clipboard.lua" >/dev/null; then
  fail "universal clipboard shortcuts do not target only normal windows"
fi
pass "universal clipboard shortcuts do not exclude layer-shell fields"

if grep -F 'wtype -M' "$ROOT/default/hypr/bindings/clipboard.lua" >/dev/null; then
  fail "universal clipboard shortcuts avoid the virtual keyboard so held SUPER cannot merge in"
fi
pass "universal clipboard shortcuts avoid virtual keyboard modifier merging"

removed_home="$tmpdir/removed-home"
mkdir -p "$removed_home/.local/state/omarchy"
touch "$removed_home/.local/state/omarchy/preinstalls-removed"
removed_output=$(run_application_bindings "$removed_home")
grep -Fq $'SUPER + RETURN	Terminal' <<<"$removed_output" || fail "preinstall removal keeps essential bindings"
if grep -Fq $'SUPER + SHIFT + M	Music' <<<"$removed_output"; then
  fail "preinstall removal skips optional application bindings"
fi
pass "preinstall removal flag skips optional application bindings"

variable_home="$tmpdir/variable-home"
mkdir -p "$variable_home"
variable_output=$(run_application_bindings "$variable_home" 'omarchy_preinstalled_bindings = false')
grep -Fq $'SUPER + RETURN	Terminal' <<<"$variable_output" || fail "preinstalled binding variable keeps essential bindings"
if grep -Fq $'SUPER + SHIFT + M	Music' <<<"$variable_output"; then
  fail "preinstalled binding variable skips optional application bindings"
fi
pass "preinstalled binding variable skips optional application bindings"

no_bindings_home="$tmpdir/no-bindings-home"
mkdir -p "$no_bindings_home"
no_bindings_output=$(run_omarchy_bindings "$no_bindings_home" 'omarchy_default_bindings = false')
[[ -z $no_bindings_output ]] || fail "default binding variable disables all Omarchy bindings" "$no_bindings_output"
pass "default binding variable disables all Omarchy bindings"

voxtype_home="$tmpdir/voxtype-home"
voxtype_bin="$tmpdir/voxtype-bin"
mkdir -p "$voxtype_home" "$voxtype_bin"
touch "$voxtype_bin/voxtype"
chmod +x "$voxtype_bin/voxtype"
voxtype_output=$(PATH="$voxtype_bin:$PATH" run_omarchy_bindings "$voxtype_home")
grep -Fq $'SUPER + CTRL + X	Toggle dictation' <<<"$voxtype_output" ||
  fail "installed Voxtype enables its toggle binding"
grep -Fq $'F9	Start dictation (push-to-talk)' <<<"$voxtype_output" ||
  fail "installed Voxtype enables its push-to-talk binding"
grep -Fq $'F9	Stop dictation (push-to-talk)' <<<"$voxtype_output" ||
  fail "installed Voxtype enables its release binding"
pass "installed Voxtype conditionally enables dictation bindings"

voxtype_without_execute_output=$(PATH="$voxtype_bin:$PATH" run_omarchy_bindings \
  "$voxtype_home" 'os.execute = function() return nil, "No child processes", 10 end')
grep -Fq $'SUPER + CTRL + X	Toggle dictation' <<<"$voxtype_without_execute_output" ||
  fail "Voxtype detection does not require spawning a subprocess"
pass "installed Voxtype detection works without os.execute"

missing_bin="$tmpdir/missing-bin"
mkdir -p "$missing_bin"
ln -s "$(command -v lua)" "$missing_bin/lua"
ln -s "$(command -v lspci)" "$missing_bin/lspci"
ln -s "$(command -v sort)" "$missing_bin/sort"
missing_voxtype_output=$(PATH="$missing_bin" run_omarchy_bindings "$voxtype_home")
if grep -Fq $'SUPER + CTRL + X	Toggle dictation' <<<"$missing_voxtype_output"; then
  fail "missing Voxtype skips its bindings"
fi
pass "missing Voxtype skips dictation bindings"

migration=$(grep -rl 'Move stock Hyprland user overrides into package defaults' "$ROOT/migrations" | head -n 1 || true)
[[ -n $migration ]] || fail "Hyprland default config migration exists"

migration_home="$tmpdir/migration-home"
mkdir -p "$migration_home/.config/hypr"
cat >"$migration_home/.config/hypr/bindings.lua" <<'LUA'
require("default.hypr.bindings.media")
require("default.hypr.bindings.clipboard")
require("default.hypr.bindings.tiling")
require("default.hypr.bindings.utilities")

-- Application bindings without Omarchy's preinstalled web apps, TUIs, or desktop apps.
o.bind("SUPER + RETURN", "Terminal", { omarchy = "terminal" })
o.bind("SUPER + SHIFT + RETURN", "Browser", { omarchy = "browser" })
o.bind("SUPER + SHIFT + F", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { omarchy = "nautilus-cwd" })
o.bind("SUPER + SHIFT + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", { omarchy = "browser --private" })
o.bind("SUPER + SHIFT + N", "Editor", { omarchy = "editor" })
LUA
HOME="$migration_home" OMARCHY_PATH="$ROOT" bash -euo pipefail "$migration" >/dev/null
cmp -s "$ROOT/config/hypr/bindings.lua" "$migration_home/.config/hypr/bindings.lua" ||
  fail "plain legacy bindings migrate to the user override stub"
[[ -f $migration_home/.local/state/omarchy/preinstalls-removed ]] ||
  fail "plain legacy bindings preserve preinstall removal state"
pass "migration converts plain legacy bindings to package-owned defaults"

upgrade_script="$ROOT/bin/omarchy-upgrade-to-quattro"
grep -Fq 'touch "$state_dir/preinstalls-removed"' "$upgrade_script" ||
  fail "upgrade-to-quattro preserves preinstall removal state"

mark_line=$(awk '/^mark_removed_preinstalls_from_legacy_bindings$/ { print NR; exit }' "$upgrade_script")
copy_line=$(awk '/^copy_always_config_defaults$/ { print NR; exit }' "$upgrade_script")
[[ -n $mark_line && -n $copy_line ]] || fail "upgrade-to-quattro preinstall marker and config refresh calls exist"
(( mark_line < copy_line )) || fail "upgrade-to-quattro detects plain legacy bindings before overwriting Hyprland bindings"
pass "upgrade-to-quattro preserves preinstall removal before refreshing Hyprland bindings"
