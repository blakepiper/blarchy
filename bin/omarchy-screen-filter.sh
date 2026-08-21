#!/bin/bash

screen_filter_toggle() {
  local mode="$1"
  local rice_path="${RICE_PATH:-${OMARCHY_PATH:-/usr/local/share/rice}}"
  local state_dir="${RICE_SCREEN_FILTER_STATE_DIR:-${RICE_INVERT_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/rice}}"
  local invert_shader="$rice_path/config/hypr/shaders/invert-colors.glsl"
  local red_glasses_shader="$rice_path/config/hypr/shaders/red-glasses-compensation.glsl"
  local requested_shader=""
  local enabled_message=""
  local disabled_message=""
  local damage_state="$state_dir/screen-filter-damage-tracking"
  local legacy_damage_state="$state_dir/invert-screen-damage-tracking"
  local previous_shader_state="$state_dir/screen-filter-previous-shader"
  local current_shader=""
  local current_damage=""
  local previous_damage=2
  local saved_damage=""
  local previous_shader=""
  local lua_shader_path=""

  case "$mode" in
  invert)
    requested_shader="$invert_shader"
    enabled_message="Monitor colors inverted"
    disabled_message="Monitor colors normal"
    ;;
  red-glasses)
    requested_shader="$red_glasses_shader"
    enabled_message="Red-glasses color compensation enabled"
    disabled_message="Monitor colors normal"
    ;;
  *)
    echo "Unknown screen filter: $mode" >&2
    return 2
    ;;
  esac

  if [[ ! -f $requested_shader ]]; then
    echo "Screen filter shader not found: $requested_shader" >&2
    return 1
  fi

  mkdir -p "$state_dir"
  exec {lock_fd}>"$state_dir/screen-filter.lock"
  flock "$lock_fd"

  current_shader=$(hyprctl getoption decoration:screen_shader -j | jq -r '.str')
  [[ $current_shader == "[[EMPTY]]" ]] && current_shader=""

  if [[ $current_shader == $requested_shader ]]; then
    if [[ -f $damage_state ]]; then
      saved_damage=$(<"$damage_state")
      if [[ $saved_damage =~ ^[012]$ ]]; then
        previous_damage=$saved_damage
      fi
    elif [[ -f $legacy_damage_state ]]; then
      saved_damage=$(<"$legacy_damage_state")
      if [[ $saved_damage =~ ^[012]$ ]]; then
        previous_damage=$saved_damage
      fi
    fi

    if [[ -f $previous_shader_state ]]; then
      previous_shader=$(<"$previous_shader_state")
    fi

    if [[ -n $previous_shader ]]; then
      lua_shader_path=${previous_shader//\\/\\\\}
      lua_shader_path=${lua_shader_path//\"/\\\"}
      hyprctl eval "hl.config({ decoration = { screen_shader = \"$lua_shader_path\" }, debug = { damage_tracking = $previous_damage } })" >/dev/null
    else
      hyprctl eval "hl.config({ decoration = { screen_shader = \"\" }, debug = { damage_tracking = $previous_damage } })" >/dev/null
    fi
    rm -f "$damage_state" "$legacy_damage_state" "$previous_shader_state"
    echo "$disabled_message"
    return 0
  fi

  if [[ $current_shader == $invert_shader || $current_shader == $red_glasses_shader ]]; then
    lua_shader_path=${requested_shader//\\/\\\\}
    lua_shader_path=${lua_shader_path//\"/\\\"}
    # Hyprland 0.56 can apply the final shader to stale partial-damage output
    # buffers. Disable damage tracking so every presented buffer is fully drawn.
    hyprctl eval "hl.config({ decoration = { screen_shader = \"$lua_shader_path\" }, debug = { damage_tracking = 0 } })" >/dev/null
    echo "$enabled_message"
    return 0
  fi

  current_damage=$(hyprctl getoption debug:damage_tracking -j | jq -r '.int')
  if [[ ! $current_damage =~ ^[012]$ ]]; then
    current_damage=2
  fi
  printf '%s\n' "$current_damage" >"$damage_state"
  printf '%s\n' "$current_shader" >"$previous_shader_state"

  lua_shader_path=${requested_shader//\\/\\\\}
  lua_shader_path=${lua_shader_path//\"/\\\"}
  # Hyprland 0.56 can apply the final shader to stale partial-damage output
  # buffers. Disable damage tracking so every presented buffer is fully drawn.
  hyprctl eval "hl.config({ decoration = { screen_shader = \"$lua_shader_path\" }, debug = { damage_tracking = 0 } })" >/dev/null
  echo "$enabled_message"
}
