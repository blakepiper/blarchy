-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- RICE's bootstrap keeps path setup out of this user config. OMARCHY_PATH
-- remains a compatibility override for older installs and test harnesses.
local rice_path = os.getenv("RICE_PATH")
if not rice_path or rice_path == "" then
  rice_path = os.getenv("OMARCHY_PATH")
end
if not rice_path or rice_path == "" then
  rice_path = "/usr/local/share/rice"
end
dofile(rice_path .. "/default/hypr/bootstrap.lua")
package.path = rice_path .. "/?.lua;" .. package.path

-- Keep RICE's default bindings (including workspace number shortcuts).
-- Personal overrides in ~/.config/hypr/bindings.lua are loaded afterward.
omarchy_default_bindings = true
--
-- Or disable only bindings for RICE's preinstalled apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load RICE defaults through the retained module name.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after RICE's
-- defaults so source updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })
