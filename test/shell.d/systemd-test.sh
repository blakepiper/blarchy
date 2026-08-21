#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

service="$ROOT/default/systemd/user/bt-agent.service"

grep -Fx 'ExecCondition=/usr/bin/systemctl is-active --quiet bluetooth.service' "$service" >/dev/null
pass "bt-agent skips when bluetooth.service is inactive"

grep -Fx 'Restart=on-failure' "$service" >/dev/null
pass "bt-agent still restarts after runtime failures"

sleep_service="$ROOT/default/systemd/user/omarchy-sleep-lock.service"
grep -Fx 'ExecStart=/usr/bin/omarchy-system-sleep-monitor' "$sleep_service" >/dev/null
pass "sleep lock service uses the package-backed monitor path"

agent_keep_awake_service="$ROOT/default/systemd/user/agent-keep-awake.service"
grep -Fx 'ExecStart=/usr/bin/agent-keep-awake' "$agent_keep_awake_service" >/dev/null
grep -F 'inhibit_what="idle:handle-lid-switch:handle-suspend-key:handle-hibernate-key"' \
  "$ROOT/bin/agent-keep-awake" >/dev/null
grep -Fx 'WantedBy=graphical-session.target' "$agent_keep_awake_service" >/dev/null
pass "coding-agent service blocks idle and hardware sleep triggers while permitting explicit suspend"


first_run_units="$ROOT/install/user/first-run/enable-user-units.sh"
grep -Fx 'systemctl --user daemon-reload' "$first_run_units" >/dev/null
grep -F 'omarchy-sleep-lock.service' "$first_run_units" >/dev/null
grep -F 'agent-keep-awake.service' "$first_run_units" >/dev/null
pass "first-run reloads and enables the sleep lock service"


fcitx_service="$ROOT/default/systemd/user/omarchy-fcitx5.service"
grep -Fx 'ExecStart=/usr/bin/fcitx5 --disable notificationitem' "$fcitx_service" >/dev/null
grep -Fx 'Restart=always' "$fcitx_service" >/dev/null ||
  fail "fcitx5 exits 0 on a duplicate bus name, so on-failure would leave the user with no input method"
grep -Fx 'After=graphical-session.target' "$fcitx_service" >/dev/null ||
  fail "fcitx5 needs WAYLAND_DISPLAY, which uwsm imports before it reaches graphical-session.target"
grep -Fx 'PartOf=graphical-session.target' "$fcitx_service" >/dev/null ||
  fail "fcitx5 must stop with the compositor instead of lingering against a dead wayland socket"
grep -Fx 'WantedBy=graphical-session.target' "$fcitx_service" >/dev/null ||
  fail "fcitx5 is never pulled in at login without a WantedBy"
grep -Fx 'ConditionEnvironment=WAYLAND_DISPLAY' "$fcitx_service" >/dev/null ||
  fail "an update over SSH has a live user manager and no display; starting fcitx5 there wedges the unit active-but-blind, and Wants= will not replace it at graphical login"


grep -F 'pkill -x fcitx5' "$ROOT/bin/omarchy-restart-xcompose" >/dev/null ||
  fail "restart-xcompose cannot reload a fcitx5 running outside the unit, so it silently keeps serving the old table"

grep -F 'omarchy-fcitx5.service' "$first_run_units" >/dev/null ||
  fail "first-run does not enable the input method, so ~/.XCompose sequences never resolve"
grep -F 'fcitx5' "$ROOT/default/hypr/autostart.lua" >/dev/null &&
  fail "fcitx5 is autostarted from Hyprland; an unsupervised launch dies silently and takes every compose sequence with it"
pass "fcitx5 runs supervised, so a lost input method comes back instead of killing XCompose until logout"

oomd_slice="$ROOT/default/systemd/user/app.slice.d/10-oomd.conf"
grep -Fx 'ManagedOOMMemoryPressure=kill' "$oomd_slice" >/dev/null ||
  fail "nothing is a kill candidate, so systemd-oomd watches the machine thrash and never acts"
grep -Fx 'ManagedOOMSwap=kill' "$oomd_slice" >/dev/null ||
  fail "no swap backstop for the slower shape of the same failure"

# Hyprland lives in session.slice/wayland-wm@hyprland.desktop.service. Marking
# any ancestor of that as a kill candidate puts the compositor back in the
# victim pool, which is the crash this whole thing exists to prevent.
candidates=$(grep -rlE '^ManagedOOM(MemoryPressure|Swap)=kill' "$ROOT/default/systemd" "$ROOT/etc/systemd" 2>/dev/null || true)
[[ $candidates == "$oomd_slice" ]] ||
  fail "systemd-oomd kill candidacy is set outside app.slice, which can select the compositor: $candidates"
pass "only user app scopes are systemd-oomd kill candidates"

oomd_conf="$ROOT/etc/systemd/oomd.conf.d/10-omarchy.conf"
grep -Fx 'DefaultMemoryPressureLimit=50%' "$oomd_conf" >/dev/null ||
  fail "no pressure limit; the 60% default rides thrashing longer than a desktop stays usable"
grep -Fx 'DefaultMemoryPressureDurationSec=20s' "$oomd_conf" >/dev/null ||
  fail "no pressure duration set for the tightened limit"
pass "systemd-oomd acts on sustained memory stall"

grep -F 'systemd-oomd.service' "$ROOT/install/standalone/system.sh" >/dev/null ||
  fail "the standalone installer does not enable systemd-oomd"
pass "the standalone installer enables systemd-oomd"
