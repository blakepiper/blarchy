#!/bin/bash

set -euo pipefail

mode=${1:-preserve}
runtime_path=${RICE_PATH:-${OMARCHY_PATH:-}}

if [[ $mode != "preserve" && $mode != "overwrite" ]]; then
  echo "Usage: user.sh [preserve|overwrite]" >&2
  exit 1
fi

if [[ -z $runtime_path || ! -d $runtime_path/config ]]; then
  echo "Error: RICE_PATH must point to the installed desktop runtime." >&2
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

copy_tree "$runtime_path/config" "$HOME/.config"
copy_item "$runtime_path/default/applications/mimeapps.list" "$HOME/.config/mimeapps.list"
copy_tree "$runtime_path/default/nautilus-python/extensions" \
  "$HOME/.local/share/nautilus-python/extensions"
copy_item "$runtime_path/default/hypr/toggles/flags.lua" \
  "$HOME/.local/state/omarchy/toggles/hypr/flags.lua"
copy_item "$runtime_path/logo.txt" "$HOME/.config/omarchy/branding/about.txt"
copy_item "$runtime_path/logo.txt" "$HOME/.config/omarchy/branding/screensaver.txt"

if [[ $mode == "overwrite" ]]; then
  rm -f "$HOME/.config/autostart/limine-snapper-notify.desktop"
fi

bashrc="$HOME/.bashrc"
touch "$bashrc"
if grep -Eq '^# >>> .*ARCH RICE >>>$' "$bashrc"; then
  sed -i \
    -E \
    -e 's/^# >>> .*ARCH RICE >>>$/# >>> RICE >>>/' \
    -e 's/^# <<< .*ARCH RICE <<<$/# <<< RICE <<</' \
    "$bashrc"
fi
if ! grep -Fq '# >>> RICE >>>' "$bashrc"; then
  cat >>"$bashrc" <<'BASHRC'

# >>> RICE >>>
if [[ -r /usr/local/share/rice/default/bash/env-bootstrap ]]; then
  source /usr/local/share/rice/default/bash/env-bootstrap
  source "$RICE_PATH/default/bash/rc"
fi
# <<< RICE <<<
BASHRC
fi
