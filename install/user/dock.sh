dock_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
dock_pins="$dock_cache_dir/nwg-dock-pinned"

mkdir -p "$dock_cache_dir"
if [[ ! -e $dock_pins ]]; then
  cat >"$dock_pins" <<'PINS'
firefox
org.gnome.Nautilus
Alacritty
Spotify
steam
PINS
fi
