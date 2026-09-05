#!/bin/bash
# Per-user setup. Run as the desktop user (not root). Seeds repository
# defaults into $HOME without overwriting existing files, then ensures
# the shell is usable. Idempotent: safe to rerun.

set -euo pipefail

repo=${BLARCHY_REPO:-}
if [[ -z $repo || ! -d $repo/config ]]; then
  echo "Error: BLARCHY_REPO must point to the repository checkout." >&2
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
  temporary=$(mktemp "$(dirname "$destination")/.blarchy-seed.XXXXXX")
  # Publish only complete files so an interrupted copy can be retried.
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

# Screenshots land here (matches the Niri screenshot-path setting).
mkdir -p "$HOME/Pictures/Screenshots"

# Interactive Bash: autosuggestions, Starship prompt, and local bin on PATH.
bashrc="$HOME/.bashrc"
touch "$bashrc"
if ! grep -Fq '# >>> blarchy >>>' "$bashrc"; then
  cat >>"$bashrc" <<'BASHRC'

# >>> blarchy >>>
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
if [[ $- == *i* ]]; then
  # Load before Starship so it uses ble.sh's prompt hooks; attach last.
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
# <<< blarchy <<<
BASHRC
fi

# Desktop configs call these helpers by absolute path, independent of
# login-shell PATH. These are managed files: always refresh them on rerun.
mkdir -p "$HOME/.local/bin"
cp -a "$repo/bin/ai-usage" "$HOME/.local/bin/ai-usage"
mkdir -p "$HOME/.local/bin/ai-usage-scanners"
cp -a "$repo/bin/ai-usage-scanners/"*.py "$HOME/.local/bin/ai-usage-scanners/"
cp -a "$repo/bin/night-mode" "$HOME/.local/bin/night-mode"
cp -a "$repo/bin/displays" "$HOME/.local/bin/displays"
cp -a "$repo/bin/clipboard-history" "$HOME/.local/bin/clipboard-history"

echo "User setup complete"
