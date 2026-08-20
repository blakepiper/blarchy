echo "Point retained user configuration at the BLARCHY runtime"

for config_file in \
  "$HOME/.config/chromium-flags.conf" \
  "$HOME/.config/hypr/hyprland.lua" \
  "$HOME/.XCompose" \
  "$HOME/.bashrc"; do
  [[ -f $config_file ]] || continue
  grep -Fq '/usr/share/omarchy' "$config_file" || continue

  backup="$config_file.blarchy-before-runtime-path"
  [[ -e $backup ]] || cp -a "$config_file" "$backup"
  sed -i 's#/usr/share/omarchy#/usr/local/share/blarchy#g' "$config_file"
done
