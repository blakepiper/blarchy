# Setup default work directory (and tries)
mkdir -p "$HOME/Work"
mkdir -p "$HOME/Work/tries"

mise_config="$HOME/Work/.mise.toml"
if [[ ${OMARCHY_PRESERVE_USER_CONFIG:-0} != "1" || ! -e $mise_config ]]; then
  cat >"$mise_config" <<'EOF'
[env]
_.path = "{{ cwd }}/bin"
EOF
fi

mise trust "$mise_config"
