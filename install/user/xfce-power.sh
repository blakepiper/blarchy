#!/bin/bash

set -u

power_channel=xfce4-power-manager
power_prefix=/xfce4-power-manager

set_property() {
  local property=$1
  local type=$2
  local value=$3

  xfconf-query \
    -c "$power_channel" \
    -p "$power_prefix/$property" \
    -n \
    -t "$type" \
    -s "$value" \
    >/dev/null 2>&1 ||
    xfconf-query \
      -c "$power_channel" \
      -p "$power_prefix/$property" \
      -s "$value" \
      >/dev/null 2>&1 || true
}

# logind leaves lid handling to the active desktop so Hyprland can reject
# transient firmware events. Configure XFCE to own its lid events and suspend
# on both AC and battery. XFCE forces lid-triggered sleep past presentation and
# application idle inhibitors, so the Coffee widget cannot suppress it.
set_property lid-action-on-ac uint 1
set_property lid-action-on-battery uint 1
set_property logind-handle-lid-switch bool false
