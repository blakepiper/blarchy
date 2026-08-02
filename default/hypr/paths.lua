-- Shared path constants for BLARCHY's retained Hyprland Lua modules.
-- Lua files loaded with require() have separate local scopes, so modules that
-- need these paths import this table instead of repeating os.getenv() lookups.

local home = os.getenv("HOME")
local blarchy_path = os.getenv("BLARCHY_PATH") or os.getenv("OMARCHY_PATH") or "/usr/local/share/blarchy"

return {
  home = home,
  config_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config"),
  state_home = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state"),
  blarchy_path = blarchy_path,
  -- Retained for inherited modules while BLARCHY_PATH is the canonical name.
  omarchy_path = blarchy_path,
}
