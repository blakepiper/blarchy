-- BLARCHY's user-facing defaults live in this small override layer so the
-- inherited default bindings can continue to receive upstream improvements.
for _, keys in ipairs({
  "SUPER + SPACE", "SUPER + RETURN", "SUPER + F", "SUPER + B", "SUPER + G",
  "SUPER + Q", "SUPER + L", "SUPER + SHIFT + S", "SUPER + SHIFT + F", "SUPER + TAB",
  "SUPER + LEFT", "SUPER + RIGHT", "SUPER + UP", "SUPER + DOWN",
  "SUPER + CTRL + LEFT", "SUPER + CTRL + RIGHT", "SUPER + CTRL + UP", "SUPER + CTRL + DOWN",
  "SUPER + SHIFT + LEFT", "SUPER + SHIFT + RIGHT", "SUPER + SHIFT + UP", "SUPER + SHIFT + DOWN",
}) do hl.unbind(keys) end
o.bind("SUPER + SPACE", "Application launcher", "omarchy-menu toggle apps")
o.bind("SUPER + RETURN", "Terminal", { omarchy = "terminal" })
o.bind("SUPER + F", "Files", { omarchy = "nautilus" })
o.bind("SUPER + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + G", "Steam", { launch = "steam" })
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())
o.bind("SUPER + SHIFT + S", "Region screenshot", "omarchy-capture-screenshot region")
o.bind("SUPER + SHIFT + F", "Full screen", hl.dsp.window.fullscreen({ mode = "maximized" }))
o.bind("SUPER + TAB", "Former workspace", hl.dsp.focus({ workspace = "previous" }))

-- Resolve critical shell actions from the active BLARCHY checkout. Hyprland
-- can retain an older PATH after the Omarchy -> BLARCHY migration.
local blarchy_path = os.getenv("BLARCHY_PATH") or os.getenv("OMARCHY_PATH") or "/home/przvl/blarchy"
local blarchy_bin = blarchy_path .. "/bin/"
o.bind("SUPER + ALT + SPACE", "BLARCHY menu", blarchy_bin .. "omarchy-menu toggle root")
o.bind("SUPER + L", "Lock system", blarchy_bin .. "omarchy-system-lock")
o.bind("SUPER + ALT + code:65", "BLARCHY menu (physical Space key)", blarchy_bin .. "omarchy-menu toggle root")
o.bind("SUPER + code:46", "Lock system (physical L key)", blarchy_bin .. "omarchy-system-lock")

o.bind("SUPER + LEFT", "Snap window left", "omarchy-hyprland-window-snap left")
o.bind("SUPER + RIGHT", "Snap window right", "omarchy-hyprland-window-snap right")
o.bind("SUPER + UP", "Snap window up", "omarchy-hyprland-window-snap up")
o.bind("SUPER + DOWN", "Snap window down", "omarchy-hyprland-window-snap down")
o.bind("SUPER + CTRL + LEFT", "Focus window left", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + CTRL + RIGHT", "Focus window right", hl.dsp.focus({ direction = "r" }))
o.bind("SUPER + CTRL + UP", "Focus window above", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + CTRL + DOWN", "Focus window below", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + SHIFT + LEFT", "Move window to left monitor", hl.dsp.window.move({ monitor = "l" }))
o.bind("SUPER + SHIFT + RIGHT", "Move window to right monitor", hl.dsp.window.move({ monitor = "r" }))
o.bind("SUPER + SHIFT + UP", "Move window to upper monitor", hl.dsp.window.move({ monitor = "u" }))
o.bind("SUPER + SHIFT + DOWN", "Move window to lower monitor", hl.dsp.window.move({ monitor = "d" }))
