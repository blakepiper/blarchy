-- Browser styling.
--
-- Keep this to one rule: Hyprland evaluates every window rule through its Lua
-- config-reload budget, and the former tag-then-style sequence could time out
-- here on Hyprland 0.56 before the rest of the config finished loading.
-- Browsers do not consistently expose YouTube playback as a Wayland idle
-- inhibitor, so keep the focused browser awake while a video is playing.
o.window(
  "((google-)?[cC]hrom(e|ium)|[bB]rave-browser|[mM]icrosoft-edge|Vivaldi-stable|helium|[fF]irefox|zen|librewolf)",
  { tag = "-default-opacity", tile = true, opacity = "1.0 0.985", idle_inhibit = "focus" }
)
