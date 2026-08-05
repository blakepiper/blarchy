-- Keep the built-in list explicit. This file is evaluated during Hyprland's
-- Lua config reload, so discovering files with io.popen("find ...") adds
-- avoidable blocking work to the reload budget.
require("default.hypr.bindings.applications")
require("default.hypr.bindings.clipboard")
require("default.hypr.bindings.media")
require("default.hypr.bindings.tiling")
require("default.hypr.bindings.utilities")
require("default.hypr.bindings.voxtype")
