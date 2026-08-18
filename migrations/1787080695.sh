echo "Bind Super+R to red-glasses color compensation in existing BLARCHY configs"

bindings_file="$HOME/.config/hypr/bindings.lua"

[[ -f $bindings_file ]] || exit 0
grep -Fq -- "-- BLARCHY's user-facing defaults live" "$bindings_file" || exit 0
grep -Fq 'o.bind("SUPER + I", "Invert screen colors"' "$bindings_file" || exit 0
grep -Fq 'o.bind("SUPER + R", "Red-glasses color compensation"' "$bindings_file" && exit 0

backup="$bindings_file.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$bindings_file" "$backup"

tmp=$(mktemp "$bindings_file.XXXXXX")
trap 'rm -f "$tmp"' EXIT

sed \
  -e '/^  "SUPER + SPACE".*"SUPER + I",/ s/"SUPER + I",/"SUPER + I", "SUPER + R",/' \
  -e '/^o\.bind("SUPER + I", "Invert screen colors"/a o.bind("SUPER + R", "Red-glasses color compensation", blarchy_bin .. "omarchy-toggle-red-glasses")' \
  "$bindings_file" >"$tmp"

grep -Fq '"SUPER + I", "SUPER + R",' "$tmp"
grep -Fq 'o.bind("SUPER + R", "Red-glasses color compensation"' "$tmp"
chmod --reference="$bindings_file" "$tmp"
mv -f -- "$tmp" "$bindings_file"
