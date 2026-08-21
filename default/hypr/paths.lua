-- Shared path constants for RICE's retained Hyprland Lua modules.
-- Lua files loaded with require() have separate local scopes, so modules that
-- need these paths import this table instead of repeating os.getenv() lookups.

local home = os.getenv("HOME")
local rice_path = os.getenv("RICE_PATH") or os.getenv("OMARCHY_PATH") or "/usr/local/share/rice"

return {
  home = home,
  config_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config"),
  state_home = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state"),
  rice_path = rice_path,
  -- Retained for inherited modules while RICE_PATH is the canonical name.
  omarchy_path = rice_path,
}
