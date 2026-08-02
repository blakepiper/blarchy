-- App-specific tweaks.
--
-- Keep the built-in list explicit. This file is loaded while Hyprland is
-- evaluating its Lua config, so discovering files with io.popen("find ...")
-- can exceed Hyprland's Lua execution budget on a cold start or reload.
-- User extensions can still be loaded by adding a require below.
require("default.hypr.apps.1password")
require("default.hypr.apps.battlenet")
require("default.hypr.apps.bitwarden")
require("default.hypr.apps.browser")
require("default.hypr.apps.davinci-resolve")
require("default.hypr.apps.geforce")
require("default.hypr.apps.jetbrains")
require("default.hypr.apps.localsend")
require("default.hypr.apps.omarchy-shell")
require("default.hypr.apps.pip")
require("default.hypr.apps.qemu")
require("default.hypr.apps.retroarch")
require("default.hypr.apps.screenshot-selection")
require("default.hypr.apps.steam")
require("default.hypr.apps.system")
require("default.hypr.apps.telegram")
require("default.hypr.apps.terminals")
require("default.hypr.apps.webcam-overlay")
