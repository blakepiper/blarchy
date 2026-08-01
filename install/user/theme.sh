# Setup user theme folder and seed the default only when no theme exists yet.
mkdir -p ~/.config/omarchy/themes

if [[ ! -s $HOME/.local/state/omarchy/current/theme.name ]]; then
  if [[ ${OMARCHY_SETUP_CONTEXT:-runtime} == "iso-chroot" ]]; then
    # The retained context name also covers standalone console installation.
    OMARCHY_THEME_HEADLESS=1 omarchy-theme-set "Tokyo Night"
  else
    omarchy-theme-set "Tokyo Night"
  fi
fi
omarchy-theme-set-pi --activate

mkdir -p ~/.config/btop/themes
ln -snf "$HOME/.local/state/omarchy/current/theme/btop.theme" ~/.config/btop/themes/current.theme
