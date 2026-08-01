(
  if [[ -n $(omarchy-notification-send -u critical -g  "Welcome to BLARCHY" "Blake's Arch + Hyprland Environment\n\nSuper + K for shortcuts.\nSuper + Space for applications.\nSuper + Alt + Space for the BLARCHY menu." -a) ]]; then
    omarchy-menu-keybindings
  fi
) >/dev/null 2>&1 &
