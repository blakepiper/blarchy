-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = "auto"

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Keep the external monitor to the left when it is connected.
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto-left", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Keep workspaces 1-4 on the external monitor and workspace 5 on the laptop.
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true })
for workspace = 2, 4 do
  hl.workspace_rule({ workspace = tostring(workspace), monitor = "HDMI-A-1" })
end
hl.workspace_rule({ workspace = "5", monitor = "eDP-1", default = true })

-- Workspace rules do not move workspaces that already exist, so reconcile
-- existing workspaces when a monitor is connected or the config is reloaded.
local function arrange_workspaces()
  if hl.get_monitor("HDMI-A-1") == nil then
    return
  end

  for workspace = 1, 4 do
    local current = hl.get_workspace(tostring(workspace))
    if current ~= nil then
      hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(workspace), monitor = "HDMI-A-1" }))
    end
  end

  if hl.get_monitor("eDP-1") ~= nil and hl.get_workspace("5") ~= nil then
    hl.dispatch(hl.dsp.workspace.move({ workspace = "5", monitor = "eDP-1" }))
  end
end

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

hl.on("hyprland.start", function()
  arrange_workspaces()
  focus_default_monitor()
end)
hl.on("monitor.added", function(monitor)
  if monitor.name == "HDMI-A-1" then
    arrange_workspaces()
    focus_default_monitor()
  end
end)

hl.on("monitor.removed", function(monitor)
  if monitor.name == "HDMI-A-1" then
    focus_default_monitor()
  end
end)
hl.on("config.reloaded", arrange_workspaces)

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
