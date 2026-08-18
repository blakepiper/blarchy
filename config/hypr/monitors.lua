-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = "auto"

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Mirror the laptop display on the external monitor when it is connected.
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1, mirror = "eDP-1" })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Make the connected external monitor the focused/default monitor, and return
-- focus to the laptop display when it is disconnected.
local function focus_default_monitor()
  local external = hl.get_monitor("HDMI-A-1")

  if external ~= nil then
    hl.dispatch(hl.dsp.focus({ monitor = external }))
    return
  end

  local internal = hl.get_monitor("eDP-1")
  if internal ~= nil then
    hl.dispatch(hl.dsp.focus({ monitor = internal }))
  end
end

hl.on("hyprland.start", focus_default_monitor)
hl.on("monitor.added", function(monitor)
  if monitor.name == "HDMI-A-1" then
    focus_default_monitor()
  end
end)

hl.on("monitor.removed", function(monitor)
  if monitor.name == "HDMI-A-1" then
    focus_default_monitor()
  end
end)

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
