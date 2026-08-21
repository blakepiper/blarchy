#!/bin/bash

set -euo pipefail

if (( EUID == 0 )); then
  echo "Error: run finalize-user.sh as the user being configured, not as root." >&2
  exit 1
fi

if (( $# > 0 )); then
  echo "Usage: finalize-user.sh" >&2
  exit 1
fi

install_config="${RICE_INSTALL_CONFIG:-/etc/rice.conf}"
if [[ -r $install_config ]]; then
  source "$install_config"
fi
export RICE_PATH="${RICE_PATH:-${OMARCHY_PATH:-/usr/local/share/rice}}"
export RICE_INSTALL="${RICE_INSTALL:-$RICE_PATH/install}"
export OMARCHY_PATH="$RICE_PATH"
export OMARCHY_INSTALL="$RICE_INSTALL"
export OMARCHY_SETUP_CONTEXT="${OMARCHY_SETUP_CONTEXT:-runtime}"
export PATH="$RICE_PATH/bin:$PATH"

if [[ -n ${OMARCHY_INSTALL_LOG_FILE:-} && -f $RICE_INSTALL/helpers/logging.sh ]]; then
  source "$RICE_INSTALL/helpers/logging.sh"
else
  run_logged() {
    local script="$1"
    bash -eE -c 'source "$1"' bash "$script"
  }
fi

mkdir -p ~/.agents/skills ~/.claude/skills ~/.codex/skills ~/.pi/agent/skills
for skills_dir in ~/.agents/skills ~/.claude/skills ~/.codex/skills ~/.pi/agent/skills; do
  [[ -L $skills_dir/omarchy ]] && rm -f "$skills_dir/omarchy"
  ln -sfn "$RICE_PATH/default/rice" "$skills_dir/rice"
done

mkdir -p ~/Downloads ~/Pictures/Screenshots ~/Videos ~/.config/gtk-3.0
if [[ ${OMARCHY_PRESERVE_USER_CONFIG:-0} != "1" || ! -f $HOME/.config/user-dirs.dirs ]]; then
  xdg-user-dirs-update --set TEMPLATES "$HOME"
  xdg-user-dirs-update --set PUBLICSHARE "$HOME"
  xdg-user-dirs-update --set DESKTOP "$HOME"
  rmdir ~/Templates ~/Public ~/Desktop 2>/dev/null || true
fi
touch ~/.config/gtk-3.0/bookmarks
for dir in Downloads Projects Pictures Videos; do
  bookmark="file://$HOME/$dir $dir"
  grep -qxF "$bookmark" ~/.config/gtk-3.0/bookmarks || echo "$bookmark" >>~/.config/gtk-3.0/bookmarks
done

source "$RICE_INSTALL/user/all.sh"

omarchy-refresh-applications
if [[ ${OMARCHY_PRESERVE_USER_CONFIG:-0} != "1" ]]; then
  xdg-mime default firefox.desktop x-scheme-handler/http
  xdg-mime default firefox.desktop x-scheme-handler/https
  xdg-mime default org.gnome.Nautilus.desktop inode/directory
fi
if [[ ${OMARCHY_PRESERVE_USER_CONFIG:-0} != "1" || ! -s $HOME/.config/xdg-terminals.list ]]; then
  omarchy-default-terminal alacritty
fi
if [[ ${OMARCHY_PRESERVE_USER_CONFIG:-0} != "1" || ! -s $HOME/.local/state/omarchy/defaults/editor ]]; then
  omarchy-default-editor codium
fi

echo "User finalization complete."
