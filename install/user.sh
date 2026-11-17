#!/bin/bash
# Seed user defaults without replacing existing files.

set -euo pipefail

repo=${INSTALL_REPO:-}
if [[ -z $repo || ! -d $repo/config ]]; then
  echo 'Error: INSTALL_REPO must point to the repository checkout.' >&2
  exit 1
fi

seed_file() {
  local source_file="$1"
  local destination="$2"
  local temporary

  if [[ -e $destination || -L $destination ]]; then
    return
  fi
  mkdir -p "$(dirname "$destination")"
  temporary=$(mktemp "$(dirname "$destination")/.seed.XXXXXX")
  if ! cp -a "$source_file" "$temporary" || ! mv -n "$temporary" "$destination"; then
    rm -f -- "$temporary"
    return 1
  fi
  rm -f -- "$temporary"
}

seed_tree() {
  local source_dir="$1"
  local destination="$2"
  local source_file relative

  while IFS= read -r -d '' source_file; do
    relative=${source_file#"$source_dir"/}
    seed_file "$source_file" "$destination/$relative"
  done < <(find "$source_dir" \( -type f -o -type l \) -print0)
}

seed_tree "$repo/config" "$HOME/.config"
if [[ -d $repo/share ]]; then
  seed_tree "$repo/share" "$HOME/.local/share"
fi
mkdir -p "$HOME/Pictures/Screenshots"

# Interactive Bash: ble.sh, Starship, and local helper commands.
bashrc="$HOME/.bashrc"
touch "$bashrc"
if ! grep -Fq '# >>> desktop setup >>>' "$bashrc"; then
  cat >>"$bashrc" <<'BASHRC'

# >>> desktop setup >>>
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
if [[ $- == *i* ]]; then
  if [[ -z ${BLE_VERSION-} && -r /usr/share/blesh/ble.sh ]]; then
    source /usr/share/blesh/ble.sh --attach=none
  fi
  if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
  fi
  if [[ -n ${BLE_VERSION-} ]]; then
    ble-attach
  fi
fi
# <<< desktop setup <<<
BASHRC
fi

mkdir -p "$HOME/.local/bin" "$HOME/.local/bin/ai-usage-scanners"
for helper in ai-usage clipboard-history control-menu desktop-session \
  desktop-settings desktop-settings-apply \
  desktop-status dev displays keep-awake screenshot \
  session-controls settings-menu system-info; do
  cp -a "$repo/bin/$helper" "$HOME/.local/bin/$helper"
done
cp -a "$repo/bin/ai-usage-scanners/codex_usage_scanner.py" \
  "$HOME/.local/bin/ai-usage-scanners/codex_usage_scanner.py"

echo 'User setup complete'
