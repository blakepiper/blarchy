-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- BLARCHY's bootstrap keeps path setup out of this user config. OMARCHY_PATH
-- remains a compatibility override for older installs and test harnesses.
local blarchy_path = os.getenv("BLARCHY_PATH")
if not blarchy_path or blarchy_path == "" then
  blarchy_path = os.getenv("OMARCHY_PATH")
end
if not blarchy_path or blarchy_path == "" then
  blarchy_path = "/usr/share/omarchy"
end
dofile(blarchy_path .. "/default/hypr/bootstrap.lua")
package.path = blarchy_path .. "/?.lua;" .. package.path

-- Disable all BLARCHY default bindings. Add your own in hypr/bindings.lua.
omarchy_default_bindings = false
--
-- Or disable only bindings for BLARCHY's preinstalled apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load BLARCHY defaults through the retained module name.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after BLARCHY's
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
