"""Offline behavior checks; all writable fixtures live in temporary directories."""

import datetime as dt
import configparser
import json
import os
from pathlib import Path
import runpy
import sqlite3
import subprocess
import tempfile
import unittest
from unittest.mock import patch


REPO = Path(__file__).resolve().parents[1]
AI = runpy.run_path(str(REPO / "bin/ai-usage"))
CLAUDE = runpy.run_path(str(REPO / "bin/ai-usage-scanners/claude_usage_scanner.py"))


class RegressionTests(unittest.TestCase):
  def setUp(self):
    self.temporary = tempfile.TemporaryDirectory(prefix="blarchy-test-")
    self.root = Path(self.temporary.name)
    self.addCleanup(self.temporary.cleanup)

  def bash(self, script, *args, **env):
    return subprocess.run(
      ["bash", "-eu", "-o", "pipefail", "-c", script, "test", *map(str, args)],
      cwd=REPO, env={**os.environ, **env}, text=True, capture_output=True,
    )

  def test_user_setup_retry(self):
    # This HOME belongs only to the child process, never the running user.
    env = {**os.environ, "HOME": str(self.root), "BLARCHY_REPO": str(REPO)}
    command = ["bash", str(REPO / "install/user.sh")]
    subprocess.run(command, env=env, check=True, capture_output=True)
    kitty = self.root / ".config/kitty/kitty.conf"
    kitty.write_text("user customization\n")
    blerc = self.root / ".config/blesh/init.sh"
    self.assertEqual(blerc.read_text(), (REPO / "config/blesh/init.sh").read_text())
    blerc.write_text("# custom suggestion settings\n")
    mimeapps = self.root / ".config/mimeapps.list"
    self.assertEqual(mimeapps.read_text(), (REPO / "config/mimeapps.list").read_text())
    mimeapps.write_text("[Default Applications]\ntext/html=custom.desktop;\n")
    subprocess.run(command, env=env, check=True, capture_output=True)
    self.assertEqual(kitty.read_text(), "user customization\n")
    self.assertEqual(blerc.read_text(), "# custom suggestion settings\n")
    self.assertIn("custom.desktop", mimeapps.read_text())
    bashrc = (self.root / ".bashrc").read_text()
    self.assertEqual(bashrc.count("# >>> blarchy >>>"), 1)
    self.assertEqual(bashrc.count("source /usr/share/blesh/ble.sh --attach=none"), 1)
    self.assertEqual(len(list(self.root.rglob(".blarchy-seed.*"))), 0)
    scanners = self.root / ".local/bin/ai-usage-scanners"
    self.assertEqual(len(list(scanners.glob("*.py"))), 3)
    self.assertFalse((scanners / "__pycache__").exists())
    self.assertTrue(os.access(self.root / ".local/bin/clipboard-history", os.X_OK))
    self.assertTrue(os.access(self.root / ".local/bin/network-settings", os.X_OK))
    self.assertTrue(os.access(self.root / ".local/bin/topbar-panel", os.X_OK))

  def test_desktop_defaults(self):
    defaults = configparser.ConfigParser()
    defaults.read(REPO / "config/mimeapps.list")
    for mime, desktop in {
      "x-scheme-handler/https": "firefox.desktop;",
      "application/pdf": "org.gnome.Papers.desktop;",
      "image/png": "imv.desktop;",
      "video/mp4": "mpv.desktop;",
      "inode/directory": "org.gnome.Nautilus.desktop;",
    }.items():
      self.assertEqual(defaults["Default Applications"][mime], desktop)
    defaults.read(REPO / "etc/dconf/db/blarchy.d/00-interface")
    self.assertEqual(defaults["org/gnome/desktop/interface"]["color-scheme"], "'prefer-dark'")
    defaults.read(REPO / "config/gtk-3.0/settings.ini")
    self.assertTrue(defaults["Settings"].getboolean("gtk-application-prefer-dark-theme"))
    bar = json.loads((REPO / "config/waybar/config.jsonc").read_text())
    self.assertEqual(bar["network"]["on-click"], "~/.local/bin/network-settings")
    self.assertIn("bluetooth", bar["modules-right"])
    self.assertEqual(bar["bluetooth"]["on-click"], "blueman-manager")
    self.assertEqual(bar["bluetooth"]["format-no-controller"], "")

  def test_keyring_pam_retry(self):
    original = "# Keep these authentication rules\nauth include system-local-login\n"
    for service in ("greetd", "passwd"):
      (self.root / service).write_text(original)
    script = 'source install/pam.sh; blarchy_configure_keyring_pam "$1"'
    for _ in range(2):
      result = self.bash(script, self.root)
      self.assertEqual(result.returncode, 0, result.stderr)
    greetd = (self.root / "greetd").read_text()
    self.assertTrue(greetd.startswith(original))
    self.assertEqual(greetd.count("auth optional pam_gnome_keyring.so"), 1)
    self.assertEqual(greetd.count("session optional pam_gnome_keyring.so auto_start"), 1)
    self.assertEqual((self.root / "passwd").read_text().count("password optional pam_gnome_keyring.so"), 1)
    (self.root / "greetd").unlink()
    self.assertNotEqual(self.bash(script, self.root).returncode, 0)
    self.assertFalse((self.root / "greetd").exists())

  def test_hardware_only_packages(self):
    script = '''source install/hardware.sh
lsusb() { return 1; }
lspci() { return 1; }
blarchy_detect_form_factor "$1" >/dev/null
blarchy_detect_bluetooth "$1" >/dev/null
printf '%s' "${BLARCHY_HW_PACKAGES[*]-}"
'''
    for chassis, backlight, bluetooth, expected in (
      ("3", False, False, ""),
      ("9", False, False, "power-profiles-daemon brightnessctl"),
      ("3", True, False, "brightnessctl"),
      ("3", False, True, "bluez bluez-utils blueman"),
    ):
      with tempfile.TemporaryDirectory(dir=self.root) as temporary:
        sysfs = Path(temporary)
        dmi = sysfs / "class/dmi/id"
        dmi.mkdir(parents=True)
        (dmi / "chassis_type").write_text(chassis)
        if backlight:
          (sysfs / "class/backlight/panel").mkdir(parents=True)
        if bluetooth:
          (sysfs / "class/bluetooth/hci0").mkdir(parents=True)
        result = self.bash(script, sysfs)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, expected)

  def test_network_settings_opens_sibling_panel(self):
    # The helper must also work when the managed bin directory has spaces and
    # ~/.local/bin is absent from the login PATH.
    directory = self.root / "desktop helpers"
    directory.mkdir()
    helper = directory / "network-settings"
    helper.write_text((REPO / "bin/network-settings").read_text())
    panel = directory / "topbar-panel"
    panel.write_text('#!/bin/bash\nprintf "%s\\n" "$@"\n')
    panel.chmod(0o755)
    result = self.bash('bash "$1"', helper)
    self.assertEqual(result.returncode, 0, result.stderr)
    self.assertEqual(result.stdout, "wifi\n")

  def test_bash_suggestions_startup(self):
    env = {**os.environ, "HOME": str(self.root), "BLARCHY_REPO": str(REPO)}
    subprocess.run(["bash", str(REPO / "install/user.sh")], env=env,
                   check=True, capture_output=True)
    # Stub the package, not the startup block: verify interactive-only loading
    # and the load -> prompt -> attach sequence without requiring Arch.
    stub = self.root / "ble.sh"
    stub.write_text('''[[ $1 == "--attach=none" ]] || exit 11
BLE_VERSION=test
startup_order=load
ble-attach() { startup_order+=:attach; }
''')
    bashrc = self.root / ".bashrc"
    bashrc.write_text(bashrc.read_text().replace("/usr/share/blesh/ble.sh", str(stub)))
    setup = '''starship() { printf '%s\\n' 'startup_order+=:prompt'; }
source "$HOME/.bashrc"
'''
    for interactive, expected in ((False, "unset"), (True, "load:prompt:attach")):
      result = subprocess.run(
        ["bash", "--noprofile", "--norc", "-ic" if interactive else "-c",
         setup + 'printf "%s" "${startup_order-unset}"'],
        env=env, text=True, capture_output=True,
      )
      self.assertEqual(result.returncode, 0, result.stderr)
      self.assertEqual(result.stdout, expected)
    stub.unlink()
    result = subprocess.run(
      ["bash", "--noprofile", "--norc", "-ic", setup + 'printf "%s" "$startup_order"'],
      env=env, text=True, capture_output=True,
    )
    self.assertEqual(result.returncode, 0, result.stderr)
    self.assertEqual(result.stdout, ":prompt")

  def pci(self, name, vendor, device_class):
    device = self.root / name
    device.mkdir()
    (device / "class").write_text(device_class)
    (device / "vendor").write_text(vendor)

  def test_gpu_detection_ignores_other_pci_classes(self):
    self.pci("audio", "0x8086", "0x040300")
    self.pci("network", "0x10de", "0x020000")
    self.pci("display", "0x1002", "0x030000")
    result = self.bash('source install/hardware.sh; blarchy_detect_gpu "$1"; '
                       '[[ $BLARCHY_HAS_INTEL_GPU == 0 && $BLARCHY_HAS_NVIDIA == 0 ]]; '
                       '[[ ${BLARCHY_HW_PACKAGES[*]} == "vulkan-radeon" ]]', self.root)
    self.assertEqual(result.returncode, 0, result.stderr)

  def test_nvidia_current_version_and_installed_kernels(self):
    for name in ("linux", "linux-lts"):
      directory = self.root / name
      directory.mkdir()
      (directory / "pkgbase").write_text(name)
    script = r'''
source install/hardware.sh
pacman() {
  case $2 in
    nvidia-utils) printf 'Version : 999.12.34-1\n' ;;
    linux-headers|linux-lts-headers) return 0 ;;
    *) return 1 ;;
  esac
}
curl() {
  [[ $* == *"/999.12.34/README.md"* ]] || return 1
  printf '| Test GPU | 2684 |\n'
}
blarchy_nvidia_packages '2684 10de 1234'
[[ " ${BLARCHY_HW_PACKAGES[*]} " == *" linux-headers "* ]]
[[ " ${BLARCHY_HW_PACKAGES[*]} " == *" linux-lts-headers "* ]]
[[ " ${BLARCHY_HW_PACKAGES[*]} " == *" nvidia-open-dkms "* ]]
[[ " ${BLARCHY_HW_PACKAGES[*]} " == *" nvidia-utils "* ]]
[[ " ${BLARCHY_HW_PACKAGES[*]} " != *" lib32-"* ]]
'''
    result = self.bash(script, BLARCHY_MODULES_PATH=str(self.root))
    self.assertEqual(result.returncode, 0, result.stderr)
    result = self.bash(script.replace("'2684 10de 1234'", "'1b80 10de 1234'"),
                       BLARCHY_MODULES_PATH=str(self.root))
    self.assertNotEqual(result.returncode, 0)
    self.assertIn("not supported", result.stderr)
    result = self.bash(script.replace("printf '| Test GPU | 2684 |\\n'", "return 22"),
                       BLARCHY_MODULES_PATH=str(self.root))
    self.assertNotEqual(result.returncode, 0)

  def test_battery_supported_and_unsupported(self):
    for name in ("BAT0", "BAT1", "BAT2"):
      (self.root / name).mkdir()
    end = self.root / "BAT0/charge_control_end_threshold"
    end.write_text("100\n")
    start = self.root / "BAT1/charge_control_start_threshold"
    start.write_text("90\n")
    for _ in range(2):
      result = subprocess.run(["bash", str(REPO / "etc/lib/blarchy/battery-limit"), str(self.root)],
                              capture_output=True, text=True)
      self.assertEqual(result.returncode, 0, result.stderr)
    self.assertEqual(end.read_text(), "80\n")
    self.assertEqual(start.read_text(), "75\n")

  def test_clipboard_picker_preserves_data_and_cancellation(self):
    payload = self.root / "payload"
    clipboard = self.root / "clipboard"
    script = r'''
cliphist() {
  case $1 in
    list) printf '1\tpreview\n' ;;
    decode)
      IFS= read -r selection
      [[ $selection == $'1\tpreview' ]]
      [[ $PICKER_ACTION != "missing" ]] || return 1
      cat "$PAYLOAD"
      ;;
  esac
}
fuzzel() {
  cat >/dev/null
  [[ $PICKER_ACTION != "cancel" ]] || return 1
  [[ $PICKER_ACTION != "empty" ]] || return 0
  printf '1\tpreview\n'
}
wl-copy() { cat >"$CLIPBOARD"; }
source bin/clipboard-history
'''
    for content in (b"text\nwith trailing newline\n", b"\x89PNG\r\n\x1a\n\x00\xff"):
      payload.write_bytes(content)
      for action in ("select", "cancel", "empty", "missing"):
        clipboard.write_bytes(b"original clipboard")
        result = self.bash(script, PAYLOAD=str(payload), CLIPBOARD=str(clipboard), PICKER_ACTION=action)
        self.assertEqual(result.returncode == 0, action != "missing", result.stderr)
        self.assertEqual(clipboard.read_bytes(), content if action == "select" else b"original clipboard")

  def test_old_claude_activity_is_not_today(self):
    provider = AI["base_provider"]("claude", "Claude")
    with patch.object(Path, "read_text", return_value=json.dumps({
      "dailyActivity": [{"date": "2000-01-01", "messageCount": 42}],
    })):
      AI["claude_stats_fallback"](provider)
    self.assertEqual(provider["todayPrompts"], 0)

  def test_claude_streaming_duplicates_and_dates(self):
    entry = {"type": "assistant", "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
             "message": {"id": "one", "usage": {"input_tokens": 10, "output_tokens": 2}}}
    lines = [json.dumps(entry)]
    entry["message"]["usage"]["output_tokens"] = 5
    lines.extend([json.dumps(entry)] * 2)
    entry["timestamp"] = "2000-01-01T00:00:00Z"
    entry["message"]["id"] = "old"
    lines.extend([json.dumps(entry), "broken json"])
    (self.root / "session.jsonl").write_text("\n".join(lines))
    self.assertEqual(CLAUDE["scan"](self.root), {"todayPrompts": 1, "todayTotalTokens": 15})

  def test_waybar_offline(self):
    data = {"updatedAt": 1, "providers": [{"name": "Fixture", "limits": [
      {"percent": 0.8, "label": "Session"},
    ]}]}
    result = json.loads(AI["waybar_output"](data))
    self.assertEqual(result["text"], "AI 20%")
    self.assertEqual(result["class"], "warning")
    config = json.loads((REPO / "config/waybar/config.jsonc").read_text())
    self.assertEqual(config["custom/ai-usage"]["on-click"], "~/.local/bin/topbar-panel ai")
    self.assertEqual(config["pulseaudio"]["on-click"], "~/.local/bin/topbar-panel audio")
    self.assertTrue(all(config["idle_inhibitor"]["format-icons"].values()))
    for mode in ("off", "night", "night-plus"):
      (self.root / "blarchy-night-mode").write_text(mode)
      result = self.bash('bin/night-mode status', XDG_RUNTIME_DIR=str(self.root))
      self.assertTrue(json.loads(result.stdout)["text"])

  def test_opencode_today_and_live_limits(self):
    scanner = runpy.run_path(str(REPO / "bin/ai-usage-scanners/opencode_go_usage_scanner.py"))
    database = self.root / "opencode.db"
    with sqlite3.connect(database) as connection:
      connection.execute("CREATE TABLE message (id TEXT, session_id TEXT, time_created INTEGER, data TEXT)")
      for key, timestamp in (("today", dt.datetime.now().timestamp()), ("old", 1)):
        connection.execute("INSERT INTO message VALUES (?, ?, ?, ?)", (key, "session", int(timestamp * 1000),
          json.dumps({"role": "assistant", "providerID": "opencode-go", "finish": "stop",
                      "tokens": {"input": 10, "output": 5, "cache": {"read": 20}}})))
    with patch.dict(scanner["scan"].__globals__, fetch_remote_usage=lambda *_: {
      "rolling": {"percent": 25, "resetsAt": "2099-01-01T00:00:00Z"},
    }):
      result = scanner["scan"](database, self.root / "missing-auth.json")
    self.assertEqual(result["todayTotalTokens"], 35)
    self.assertEqual(result["todayPrompts"], 1)
    self.assertEqual(result["rateLimitPercent"], 0.25)

  def test_codex_cached_tokens_are_not_counted_twice(self):
    scanner = runpy.run_path(str(REPO / "bin/ai-usage-scanners/codex_usage_scanner.py"))
    sessions = self.root / "sessions"
    sessions.mkdir()
    (sessions / "one.jsonl").write_text(json.dumps({
      "type": "event_msg", "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
      "payload": {"type": "token_count", "info": {"last_token_usage": {
        "input_tokens": 100, "cached_input_tokens": 80, "output_tokens": 20,
      }}},
    }))
    with patch.dict(os.environ, {"CODEX_HOME": str(self.root)}):
      scanner["scan_native_codex_sessions"]()
    self.assertEqual(scanner["add_usage"].__globals__["today_total_tokens"], 120)


if __name__ == "__main__":
  unittest.main()
