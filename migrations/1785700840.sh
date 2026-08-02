echo "Move BLARCHY migration notifications to the BLARCHY-owned service"

systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user disable --now omarchy-migrate-notify.service >/dev/null 2>&1 || true

wants_dir="$HOME/.config/systemd/user/graphical-session.target.wants"
rm -f \
  "$wants_dir/omarchy-migrate-notify.service" \
  "$wants_dir/omarchy-update-user-notify.service" \
  "$wants_dir/omarchy-update-user-notify.path"

if systemctl --user cat blarchy-migrate-notify.service >/dev/null 2>&1; then
  if ! systemctl --user enable blarchy-migrate-notify.service >/dev/null 2>&1; then
    mkdir -p "$wants_dir"
    ln -sfn /usr/lib/systemd/user/blarchy-migrate-notify.service \
      "$wants_dir/blarchy-migrate-notify.service"
  fi
fi

# Replace only the exact v0.1 Arch-logo default. Any user-edited Fastfetch
# configuration has a different hash and remains untouched.
fastfetch_config="$HOME/.config/fastfetch/config.jsonc"
v01_fastfetch_hash=77d8b0ebe02a43f97d4a8c78bd0b7cc1f1f07d5039da17192b3d1702375f4e8d
if [[ -f $fastfetch_config ]] &&
  [[ $(sha256sum "$fastfetch_config" | cut -d' ' -f1) == "$v01_fastfetch_hash" ]]; then
  cp "$BLARCHY_PATH/etc/fastfetch/config.jsonc" "$fastfetch_config"
fi
