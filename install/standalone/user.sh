#!/bin/bash

set -euo pipefail

mode=${1:-preserve}
repo_path=${OMARCHY_PATH:-}

if [[ $mode != "preserve" && $mode != "overwrite" ]]; then
  echo "Usage: user.sh [preserve|overwrite]" >&2
  exit 1
fi

if [[ -z $repo_path || ! -d $repo_path/config ]]; then
  echo "Error: OMARCHY_PATH must point to the BLARCHY checkout." >&2
  exit 1
fi

copy_item() {
  local source_file="$1"
  local destination="$2"

  if [[ $mode == "preserve" && ( -e $destination || -L $destination ) ]]; then
    return
  fi

  mkdir -p "$(dirname "$destination")"
  cp -a "$source_file" "$destination"
}

copy_tree() {
  local source_dir="$1"
  local destination="$2"
  local source_file relative

  while IFS= read -r -d '' source_file; do
    relative=${source_file#"$source_dir"/}
    if [[ $relative == "autostart/limine-snapper-notify.desktop" ]]; then
      continue
    fi
    copy_item "$source_file" "$destination/$relative"
  done < <(find "$source_dir" \( -type f -o -type l \) -print0)
}

copy_tree "$repo_path/config" "$HOME/.config"
copy_item "$repo_path/etc/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
copy_item "$repo_path/default/applications/mimeapps.list" "$HOME/.config/mimeapps.list"
copy_tree "$repo_path/default/nautilus-python/extensions" \
  "$HOME/.local/share/nautilus-python/extensions"
copy_item "$repo_path/default/hypr/toggles/flags.lua" \
  "$HOME/.local/state/omarchy/toggles/hypr/flags.lua"
copy_item "$repo_path/icon.txt" "$HOME/.config/omarchy/branding/about.txt"
copy_item "$repo_path/logo.txt" "$HOME/.config/omarchy/branding/screensaver.txt"

if [[ $mode == "overwrite" ]]; then
  rm -f "$HOME/.config/autostart/limine-snapper-notify.desktop"
fi

bashrc="$HOME/.bashrc"
touch "$bashrc"
if ! grep -Fq '# >>> BLARCHY >>>' "$bashrc"; then
  cat >>"$bashrc" <<'BASHRC'

# >>> BLARCHY >>>
if [[ -r /usr/share/omarchy/default/bash/env-bootstrap ]]; then
  source /usr/share/omarchy/default/bash/env-bootstrap
  source "$OMARCHY_PATH/default/bash/rc"
fi
# <<< BLARCHY <<<
BASHRC
fi
