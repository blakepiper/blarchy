-- Hyprland bootstrap for RICE's retained Lua module path.

local home = os.getenv("HOME")
local reload_prefixes = {
  "default.hypr",
  "hypr",
  "omarchy.current.theme",
}

local function should_reload_module(module)
  for _, prefix in ipairs(reload_prefixes) do
    if module == prefix or module:sub(1, #prefix + 1) == prefix .. "." then
      return true
    end
  end

  return false
end

local modules_to_reload = {}
for module in pairs(package.loaded) do
  if should_reload_module(module) then
    table.insert(modules_to_reload, module)
  end
end

for _, module in ipairs(modules_to_reload) do
  package.loaded[module] = nil
end

-- Load generated state from ~/.local/state, user modules from ~/.config, and
-- RICE defaults from the installed runtime. OMARCHY_PATH remains a
-- compatibility override for older installs and test harnesses.
local rice_path = os.getenv("RICE_PATH") or os.getenv("OMARCHY_PATH") or "/usr/local/share/rice"
package.path = home
  .. "/.local/state/?.lua;"
  .. home
  .. "/.config/?.lua;"
  .. rice_path
  .. "/?.lua;"
  .. package.path
