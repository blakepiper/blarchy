-- Mirror a laptop panel to a docked external display, with connector changes
-- debounced so duplicate dock notifications do not reapply monitor rules.
local previous_outputs = nil
local pending = false

local function internal_output(outputs)
  local configured = os.getenv("DESKTOP_PRIMARY_OUTPUT")
  if configured and configured ~= "" then
    for _, name in ipairs(outputs) do
      if name == configured then return configured end
    end
  end
  for _, name in ipairs(outputs) do
    if name:match("^eDP") or name:match("^LVDS") or name:match("^DSI") then
      return name
    end
  end
  return nil
end

local function apply_monitors()
  local outputs = {}
  for _, monitor in ipairs(hl.get_monitors({ all = true })) do
    table.insert(outputs, monitor.name)
  end
  table.sort(outputs)
  local signature = table.concat(outputs, "\n")
  if signature == previous_outputs then return end
  previous_outputs = signature

  local primary = internal_output(outputs)
  if not primary then return end

  local external = {}
  for _, name in ipairs(outputs) do
    if name ~= primary then table.insert(external, name) end
  end
  if #external == 0 then
    hl.monitor({ output = primary, mode = "preferred", position = "auto", scale = "auto", mirror = "" })
    return
  end

  local source = external[1]
  -- Release the selected source from mirror mode before pointing other
  -- connectors at it; this avoids a cycle when the dock is reconnected.
  hl.monitor({ output = source, mode = "preferred", position = "auto",
    scale = 1, mirror = "", bitdepth = 8 })
  hl.timer(function()
    if previous_outputs ~= signature then return end
    for _, name in ipairs(outputs) do
      if name ~= source then
        hl.monitor({ output = name, mode = "preferred", position = "auto",
          scale = name == primary and "auto" or 1, mirror = source, bitdepth = 8 })
      end
    end
  end, { timeout = 150, type = "oneshot" })
end

local function schedule_monitors()
  if pending then return end
  pending = true
  hl.timer(function()
    pending = false
    apply_monitors()
  end, { timeout = 150, type = "oneshot" })
end

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.on("monitor.added", schedule_monitors)
hl.on("monitor.removed", schedule_monitors)
hl.on("hyprland.start", schedule_monitors)
schedule_monitors()
