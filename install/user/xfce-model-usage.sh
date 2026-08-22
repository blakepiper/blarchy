#!/bin/bash

set -euo pipefail

panel_channel=xfce4-panel
panel_id=1
plugin_id=22
command_path="$RICE_PATH/bin/omarchy-model-usage-xfce"
existing_plugin=false

if ! xfconf-query -c "$panel_channel" -p /configver >/dev/null 2>&1; then
  exit 0
fi

mapfile -t panel_plugins < <(
  xfconf-query -c "$panel_channel" -p "/panels/panel-$panel_id/plugin-ids" -a |
    sed -n '3,$p'
)

for candidate in "${panel_plugins[@]}"; do
  [[ $candidate == "" ]] && continue
  plugin_type=$(xfconf-query -c "$panel_channel" -p "/plugins/plugin-$candidate" 2>/dev/null || true)
  if [[ $plugin_type == "genmon" ]]; then
    plugin_command=$(xfconf-query -c "$panel_channel" -p "/plugins/plugin-$candidate/command" 2>/dev/null || true)
    if [[ $plugin_command == *omarchy-model-usage-xfce* ]]; then
      plugin_id=$candidate
      existing_plugin=true
      break
    fi
  fi
done

if [[ $existing_plugin == "false" ]]; then
  while :; do
    occupied=false
    for candidate in "${panel_plugins[@]}"; do
      if [[ $candidate == "$plugin_id" ]]; then
        occupied=true
        break
      fi
    done
    [[ $occupied == "false" ]] && break
    ((plugin_id++))
  done
fi

xfconf-query -c "$panel_channel" -p "/plugins/plugin-$plugin_id" -n -t string -s genmon 2>/dev/null || true
xfconf-query -c "$panel_channel" -p "/plugins/plugin-$plugin_id/command" -n -t string -s "$command_path"
xfconf-query -c "$panel_channel" -p "/plugins/plugin-$plugin_id/update-period" -n -t int -s 300
xfconf-query -c "$panel_channel" -p "/plugins/plugin-$plugin_id/use-label" -n -t bool -s false
xfconf-query -c "$panel_channel" -p "/plugins/plugin-$plugin_id/text" -n -t string -s ""
xfconf-query -c "$panel_channel" -p "/plugins/plugin-$plugin_id/enable-single-row" -n -t bool -s true

if [[ $existing_plugin == "false" ]]; then
  panel_args=(-c "$panel_channel" -p "/panels/panel-$panel_id/plugin-ids" -a)
  for candidate in "${panel_plugins[@]}"; do
    [[ $candidate == "" ]] && continue
    panel_args+=(-t int -s "$candidate")
  done
  panel_args+=(-t int -s "$plugin_id")
  xfconf-query "${panel_args[@]}"
fi
