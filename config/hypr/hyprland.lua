-- Load before configuring the plugin. Whitelist the glass-enabled app and layer surfaces.
local glassPlugin = os.getenv("HYPRGLASS_PLUGIN")
if glassPlugin and glassPlugin ~= "" then hl.plugin.load(glassPlugin) end
if hl.plugin.hyprglass then
  local hg = hl.plugin.hyprglass
  hg.config({
    enabled = false,
    default_theme = "dark",
    default_preset = "desktop-glass",
    layers = { enabled = true },
  })
  hg.preset("desktop-glass", {
    inherits = "pomme",
    blur_strength = 0.7,
    edge_thickness_px = 18,
    edge_height = 24,
    refraction_strength = 0.8,
    chromatic_aberration = 0.12,
    dark = {
      tint_color = 0x10182738,
      brightness = 0.85,
      contrast = 1.05,
      saturation = 1.0,
      adaptive_dim = 0.25,
    },
  })
  -- Clearer material for the small topbar panes; keep popup glass richer.
  hg.preset("desktop-bar-glass", {
    inherits = "desktop-glass",
    blur_strength = 0.25,
    edge_thickness_px = 5,
    edge_height = 8,
    refraction_strength = 0.25,
    chromatic_aberration = 0.02,
    dark = {
      tint_color = 0x10182718,
      brightness = 1.0,
      contrast = 1.0,
      saturation = 1.0,
      adaptive_dim = 0.08,
    },
  })
  for _, namespace in ipairs({ "desktop-workspace-glass", "desktop-clock-glass", "desktop-controls-glass" }) do
    hg.layer(namespace, {
      preset = "desktop-bar-glass",
      mask_mode = "contour",
      mask_threshold = 0.05,
      mask_feather = 0.03,
    })
  end
  -- Alpha masks follow rounded cards and exclude transparent layer margins.
  for _, namespace in ipairs({ "wofi" }) do
    hg.layer(namespace, {
      preset = "desktop-glass",
      mask_mode = "contour",
      mask_threshold = 0.05,
      mask_feather = 0.03,
    })
  end
end
hl.window_rule({
  name = "ghostty-glass",
  match = { class = "^org[.]local[.]GhosttyGlass$" },
  tag = "+hyprglass_enabled",
  -- Ghostty supplies background alpha; preserve opaque, readable glyphs.
  opacity = "1.0 override 1.0 override 1.0 override",
})

local home = os.getenv("HOME") or ""
local exec = hl.dsp.exec_cmd

hl.config({
  general = {
    layout = "dwindle",
    gaps_out = { top = 4, right = 10, bottom = 10, left = 10 },
  },
  decoration = {
    active_opacity = 0.85,
    inactive_opacity = 0.80,
    rounding = 10,
  },
  dwindle = { force_split = 2 },
  input = {
    natural_scroll = true,
    touchpad = { natural_scroll = true },
    repeat_delay = 250,
    repeat_rate = 45,
  },
})

hl.layer_rule({
  name = "wofi-glass",
  match = { namespace = "^wofi$" },
  blur = true,
  ignore_alpha = 0.0,
})
for _, namespace in ipairs({ "desktop-workspace-glass", "desktop-clock-glass", "desktop-controls-glass" }) do
  hl.layer_rule({
    name = namespace,
    match = { namespace = "^" .. namespace .. "$" },
    blur = true,
    ignore_alpha = 0.0,
  })
end

dofile(home .. "/.config/hypr/monitors.lua")

hl.window_rule({
  name = "opaque-firefox-video",
  match = { class = "^firefox$", title = "^\\[firefox-video\\] " },
  opacity = "1.0 override 1.0 override 1.0 override",
})
hl.window_rule({
  name = "opaque-steam-games",
  match = { class = "^steam_app_.*$" },
  opacity = "1.0 override 1.0 override 1.0 override",
})

local launcher = "wofi --show drun --allow-images --prompt 'Search applications'"
hl.bind("SUPER + Return", exec("ghostty"))
hl.bind("SUPER + Space", exec(launcher))
hl.bind("SUPER + D", exec(launcher))
hl.bind("SUPER + SHIFT + Space", exec(home .. "/.local/bin/control-menu"))
hl.bind("SUPER + S", exec(home .. "/.local/bin/desktop-settings"),
  { description = "Open settings menu" })
hl.bind("SUPER + F", exec("nautilus"))
hl.bind("SUPER + B", exec("firefox"))
hl.bind("SUPER + SHIFT + B", exec("firefox --private-window"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + Q", hl.dsp.exit())
hl.bind("SUPER + P", hl.dsp.window.float())
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + Tab", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + V", exec(home .. "/.local/bin/clipboard-history"))
hl.bind("SUPER + N", exec(home .. "/.local/bin/session-controls nightlight-cycle"))
hl.bind("SUPER + L", exec("loginctl lock-session"))
hl.bind("SUPER + SHIFT + S", exec(home .. "/.local/bin/screenshot"))
hl.bind("Print", exec(home .. "/.local/bin/screenshot --full"))

for _, pair in ipairs({ { "Left", "left" }, { "Right", "right" },
                        { "Up", "up" }, { "Down", "down" } }) do
  hl.bind("SUPER + " .. pair[1], hl.dsp.focus({ direction = pair[2] }))
  hl.bind("SUPER + SHIFT + " .. pair[1], hl.dsp.window.swap({ direction = pair[2] }))
end
for _, pair in ipairs({ { "Left", "-1" }, { "Right", "+1" } }) do
  hl.bind("SUPER + CTRL + " .. pair[1], hl.dsp.focus({ monitor = pair[2] }))
  hl.bind("SUPER + CTRL + SHIFT + " .. pair[1], hl.dsp.window.move({ monitor = pair[2] }))
end
for i = 1, 9 do
  hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("XF86AudioRaiseVolume", exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
  { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
  { repeating = true, locked = true })
hl.bind("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", exec("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", exec("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", exec("playerctl previous"), { locked = true })
hl.bind("XF86MonBrightnessUp", exec("brightnessctl --class=backlight set 5%+"),
  { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", exec("brightnessctl --class=backlight set 5%-"),
  { repeating = true, locked = true })

hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE && systemctl --user start desktop-session.service hypridle.service hyprsunset.service")
  hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
end)

hl.on("hyprland.shutdown", function()
  os.execute("systemctl --user stop desktop-session.service hypridle.service hyprsunset.service")
end)
