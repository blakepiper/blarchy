echo "Bind Super+C to VSCodium in existing BLARCHY configs"

bindings_file="$HOME/.config/hypr/bindings.lua"

[[ -f $bindings_file ]] || exit 0
grep -Fq -- "-- BLARCHY's user-facing defaults live" "$bindings_file" || exit 0
grep -Fq 'o.bind("SUPER + RETURN", "Terminal"' "$bindings_file" || exit 0
grep -Fq 'o.bind("SUPER + C",' "$bindings_file" && exit 0

backup="$bindings_file.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$bindings_file" "$backup"

tmp=$(mktemp "$bindings_file.XXXXXX")
trap 'rm -f "$tmp"' EXIT

sed \
  -e 's/"SUPER + SPACE", "SUPER + RETURN", /"SUPER + SPACE", "SUPER + RETURN", "SUPER + C", /' \
  -e '/^o\.bind("SUPER + RETURN", "Terminal"/a o.bind("SUPER + C", "VSCodium", { launch = "codium" })' \
  "$bindings_file" >"$tmp"

grep -Fq '"SUPER + RETURN", "SUPER + C", "SUPER + F"' "$tmp"
grep -Fq 'o.bind("SUPER + C", "VSCodium", { launch = "codium" })' "$tmp"
chmod --reference="$bindings_file" "$tmp"
mv -f -- "$tmp" "$bindings_file"
