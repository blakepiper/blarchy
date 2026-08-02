echo "Use the BLARCHY image in an unchanged Fastfetch configuration"

config="$HOME/.config/fastfetch/config.jsonc"
old_default_hash=4db1d0f2dbd826719aea7e91ba588fef6cbccd920a2bb6d0a34f2f49812f6ec9

[[ -f $config ]] || exit 0
[[ $(sha256sum "$config" | cut -d' ' -f1) == "$old_default_hash" ]] || exit 0

cp "$OMARCHY_PATH/etc/fastfetch/config.jsonc" "$config"
