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

  if [[ -e $destination || -L $destination ]]; then
    return
  fi
  mkdir -p "$(dirname "$destination")"
  cp -a "$source_file" "$destination"
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

# Minimal shell wiring: starship prompt plus local bin on PATH.
bashrc="$HOME/.bashrc"
touch "$bashrc"
if ! grep -Fq '# >>> blarchy >>>' "$bashrc"; then
  cat >>"$bashrc" <<'BASHRC'

# >>> blarchy >>>
export PATH="$HOME/.local/bin:$PATH"
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi
# <<< blarchy <<<
BASHRC
fi

# Waybar and terminals call the AI widget by absolute path, independent of
# login-shell PATH. These are managed files: always refresh them on rerun.
mkdir -p "$HOME/.local/bin"
cp -a "$repo/bin/ai-usage" "$HOME/.local/bin/ai-usage"
rm -rf "$HOME/.local/bin/ai-usage-scanners"
cp -a "$repo/bin/ai-usage-scanners" "$HOME/.local/bin/ai-usage-scanners"

echo "User setup complete"
