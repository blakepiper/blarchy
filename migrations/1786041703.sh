echo "Allow explicit suspend while coding agents run"

systemctl --user daemon-reload >/dev/null 2>&1 || true

if systemctl --user cat blarchy-agent-keep-awake.service >/dev/null 2>&1 &&
  systemctl --user is-active --quiet blarchy-agent-keep-awake.service; then
  systemctl --user restart blarchy-agent-keep-awake.service >/dev/null 2>&1 || true
fi
