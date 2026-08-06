echo "Keep the desktop awake while a coding agent runs"

systemctl --user daemon-reload >/dev/null 2>&1 || true

unit=blarchy-agent-keep-awake.service
if systemctl --user cat "$unit" >/dev/null 2>&1; then
  if ! systemctl --user enable "$unit" >/dev/null 2>&1; then
    wants_dir="$HOME/.config/systemd/user/graphical-session.target.wants"
    mkdir -p "$wants_dir"
    ln -sfn /usr/lib/systemd/user/$unit "$wants_dir/$unit"
  fi

  if systemctl --user is-active --quiet graphical-session.target; then
    systemctl --user restart "$unit" >/dev/null 2>&1 || true
  fi
fi
