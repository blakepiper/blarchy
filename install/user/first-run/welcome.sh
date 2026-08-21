(
  if [[ -n $(omarchy-notification-send -u critical -g  "Welcome to your Arch desktop" "Hyprland and XFCE are ready.\n\nSuper + K for shortcuts.\nSuper + Space for applications.\nSuper + Alt + Space for the desktop menu." -a) ]]; then
    omarchy-menu-keybindings
  fi
) >/dev/null 2>&1 &
