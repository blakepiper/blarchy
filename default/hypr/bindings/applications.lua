-- Essential application bindings.
o.bind("SUPER + RETURN", "Terminal", { omarchy = "terminal" })
o.bind("SUPER + SHIFT + RETURN", "Browser", { omarchy = "browser" })
o.bind("SUPER + SHIFT + F", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { omarchy = "nautilus-cwd" })
o.bind("SUPER + SHIFT + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", { omarchy = "browser --private" })
o.bind("SUPER + SHIFT + N", "Editor", { omarchy = "editor" })
if o.preinstalled_bindings_enabled() then
  -- Bindings inherited for optional applications and TUIs.
  o.bind("SUPER + ALT + RETURN", "Tmux", { omarchy = "terminal-tmux" })
  o.bind("SUPER + SHIFT + M", "Music", { omarchy = "spotify" })
  o.bind("SUPER + SHIFT + G", "Signal", { omarchy = "signal" })
  o.bind("SUPER + SHIFT + SLASH", "Passwords", { omarchy = "1password" })

  o.bind("SUPER + SHIFT + ALT + A", "Grok", { webapp = "https://grok.com" })
end
