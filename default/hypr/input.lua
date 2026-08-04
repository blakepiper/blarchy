-- https://wiki.hypr.land/Configuring/Basics/Variables/#input

-- Layouts that can't type Latin letters. Keep in sync with the list in
-- etc/mkinitcpio.conf.d/omarchy_hooks.conf.
local non_latin_layouts =
  " af am ara bd bg by et ge gr il in iq ir kg kh kz la lk mk mm mn mv np rs ru sy th tj ua "

-- UWSM reads vconsole.conf before Hyprland starts. Config reloads only consult
-- the session environment, because file I/O can exceed Hyprland's Lua budget.
local kb_layout = os.getenv("OMARCHY_XKB_LAYOUT") or "us"
local kb_variant = os.getenv("OMARCHY_XKB_VARIANT") or ""
-- CapsLock is the compose key. Keep the option set minimal: the former
-- shift:both_capslock_cancel option conflicts with the active XKB keymap on
-- some BLARCHY sessions and can break modifier chords globally.
local kb_options = "compose:caps"

-- Hyprland resolves keybindings against the first entry in kb_layout, not the
-- layout that's currently active, so BLARCHY's Latin-keysym bindings (SUPER + W
-- and friends) only fire when a Latin layout leads. Installing with a non-Latin
-- one would otherwise leave the desktop unusable.
if non_latin_layouts:find(" " .. kb_layout:match("^[^,]*") .. " ", 1, true) then
  kb_layout = "us," .. kb_layout
  kb_variant = "," .. kb_variant
  -- Reach the original layout with Left Alt + Right Alt.
  kb_options = kb_options .. ",grp:alts_toggle"
end

hl.config({
  input = {
    kb_layout = kb_layout,
    kb_variant = kb_variant,
    kb_model = "",
    kb_options = kb_options,
    kb_rules = "",
    follow_mouse = 1,
    sensitivity = 0,

    repeat_rate = 40,
    repeat_delay = 250,
    numlock_by_default = true,

    touchpad = {
      natural_scroll = true,
      clickfinger_behavior = true,
      scroll_factor = 0.4,
    },
  },

  misc = {
    key_press_enables_dpms = true,
    mouse_move_enables_dpms = true,
  },
})

-- Scroll nicely in the terminal.
o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })
