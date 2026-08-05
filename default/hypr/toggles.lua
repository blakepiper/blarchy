local paths = require("default.hypr.paths")
local require_optional = require("default.hypr.require_optional")

local toggles_dir = paths.state_home .. "/omarchy/toggles/hypr"
package.path = toggles_dir .. "/?.lua;" .. package.path

-- These are the built-in toggle names. Use optional requires so missing
-- user-state files do not require a directory scan during config reload.
for _, toggle in ipairs({
  "flags",
  "internal-monitor-clamshell",
  "internal-monitor-disable",
  "internal-monitor-mirror",
  "single-window-aspect-ratio",
  "touchpad-disabled",
  "touchscreen-disabled",
  "voxtype",
  "window-no-gaps",
}) do
  package.loaded[toggle] = nil
  require_optional.module(toggle)
end

require("default.hypr.workspace-layouts")
