"""Offline behavior checks for installer helpers and user setup."""

import datetime as dt
import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch


REPO = Path(__file__).resolve().parents[1]
SCANNER_PATH = REPO / "bin/ai-usage-scanners/codex_usage_scanner.py"


class RegressionTests(unittest.TestCase):
  def setUp(self):
    self.temporary = tempfile.TemporaryDirectory(prefix="desktop-test-")
    self.root = Path(self.temporary.name)
    self.addCleanup(self.temporary.cleanup)

  def run_bash(self, script, *args, **extra_env):
    env = {
      **os.environ,
      "HOME": str(self.root),
      "INSTALL_REPO": str(REPO),
      **extra_env,
    }
    return subprocess.run(
      ["bash", "-eu", "-o", "pipefail", "-c", script, "test", *map(str, args)],
      cwd=REPO,
      env=env,
      text=True,
      capture_output=True,
    )

  def test_user_setup_retry_preserves_config_and_keeps_blank_nvim(self):
    command = ["bash", str(REPO / "install/user.sh")]
    env = {
      **os.environ,
      "HOME": str(self.root),
      "INSTALL_REPO": str(REPO),
    }
    subprocess.run(command, env=env, check=True, capture_output=True)

    ghostty = self.root / ".config/ghostty/config"
    self.assertEqual(ghostty.read_text(), (REPO / "config/ghostty/config").read_text())
    nvim = self.root / ".config/nvim/init.lua"
    self.assertTrue(nvim.exists())
    self.assertEqual(nvim.read_text(), "")
    quickshell = self.root / ".config/quickshell/shell.qml"
    self.assertTrue(quickshell.is_file())
    self.assertFalse((self.root / ".mozilla/firefox").exists())

    ghostty.write_text("user terminal settings\n")
    nvim.write_text("-- user config\n")
    subprocess.run(command, env=env, check=True, capture_output=True)
    self.assertEqual(ghostty.read_text(), "user terminal settings\n")
    self.assertEqual(nvim.read_text(), "-- user config\n")

    bashrc = (self.root / ".bashrc").read_text()
    self.assertEqual(bashrc.count("# >>> desktop setup >>>"), 1)
    self.assertEqual(bashrc.count("source /usr/share/blesh/ble.sh --attach=none"), 1)
    for helper in (
      "ai-usage", "clipboard-history", "control-menu", "desktop-session",
      "desktop-settings", "desktop-settings-apply", "desktop-status", "dev",
      "displays", "keep-awake", "screenshot", "session-controls", "settings-menu",
      "system-info",
    ):
      installed = self.root / ".local/bin" / helper
      self.assertTrue(installed.is_file(), helper)
      self.assertTrue(os.access(installed, os.X_OK), helper)
    self.assertFalse((self.root / ".local/bin/network-settings").exists())
    self.assertEqual(
      sorted(path.name for path in (self.root / ".local/bin/ai-usage-scanners").glob("*.py")),
      ["codex_usage_scanner.py"],
    )
    self.assertFalse((self.root / ".local/bin/ai-usage-scanners/__pycache__").exists())

  def test_keyring_pam_rules_are_idempotent_for_tty_login(self):
    original = "# Keep the Arch authentication stack\nauth include system-local-login\n"
    for service in ("login", "passwd"):
      (self.root / service).write_text(original)
    script = 'source install/pam.sh; configure_keyring_pam "$1"'
    for _ in range(2):
      result = self.run_bash(script, self.root)
      self.assertEqual(result.returncode, 0, result.stderr)

    login = (self.root / "login").read_text()
    self.assertTrue(login.startswith(original))
    self.assertEqual(login.count("auth optional pam_gnome_keyring.so"), 1)
    self.assertEqual(login.count("session optional pam_gnome_keyring.so auto_start"), 1)
    self.assertEqual((self.root / "passwd").read_text().count(
      "password optional pam_gnome_keyring.so"), 1)
    self.assertFalse((self.root / "sddm").exists())

  def test_hardware_packages_remain_machine_specific(self):
    script = '''
source install/hardware.sh
lsusb() { return 1; }
lspci() { return 1; }
installer_detect_form_factor "$1" >/dev/null
installer_detect_bluetooth "$1" >/dev/null
printf '%s' "${INSTALL_HW_PACKAGES[*]-}"
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
        result = self.run_bash(script, sysfs)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, expected)

  def test_nvidia_uses_current_driver_and_installed_kernel_headers(self):
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
installer_nvidia_packages '2684 10de 1234'
[[ " ${INSTALL_HW_PACKAGES[*]} " == *" linux-headers "* ]]
[[ " ${INSTALL_HW_PACKAGES[*]} " == *" linux-lts-headers "* ]]
[[ " ${INSTALL_HW_PACKAGES[*]} " == *" nvidia-open-dkms "* ]]
[[ " ${INSTALL_HW_PACKAGES[*]} " == *" nvidia-utils "* ]]
[[ " ${INSTALL_HW_PACKAGES[*]} " != *" lib32-"* ]]
'''
    result = self.run_bash(script, INSTALL_MODULES_PATH=str(self.root))
    self.assertEqual(result.returncode, 0, result.stderr)

  def test_battery_charge_limits_are_written_idempotently(self):
    for name in ("BAT0", "BAT1", "BAT2"):
      (self.root / name).mkdir()
    end = self.root / "BAT0/charge_control_end_threshold"
    end.write_text("100\n")
    start = self.root / "BAT1/charge_control_start_threshold"
    start.write_text("90\n")
    command = ["bash", str(REPO / "etc/lib/battery-charge-limit"), str(self.root)]
    for _ in range(2):
      result = subprocess.run(command, capture_output=True, text=True)
      self.assertEqual(result.returncode, 0, result.stderr)
    self.assertEqual(end.read_text(), "80\n")
    self.assertEqual(start.read_text(), "75\n")

  def test_nightlight_level_cycles_in_user_state(self):
    state_home = self.root / "state"
    env = {"XDG_STATE_HOME": str(state_home), "WAYLAND_DISPLAY": ""}
    command = ["bash", str(REPO / "bin/session-controls"), "nightlight-cycle"]
    expected = ("50", "100", "0")
    for level in expected:
      result = subprocess.run(command, env={**os.environ, **env}, capture_output=True, text=True)
      self.assertEqual(result.returncode, 0, result.stderr)
      self.assertEqual((state_home / "desktop-session/nightlight-level").read_text().strip(), level)

  def test_codex_scanner_counts_latest_native_token_usage(self):
    scanner = runpy.run_path(str(SCANNER_PATH))
    now = dt.datetime.now(dt.timezone.utc).isoformat()
    sessions = self.root / "sessions"
    sessions.mkdir()
    entry = {
      "type": "event_msg",
      "timestamp": now,
      "payload": {
        "type": "token_count",
        "info": {
          "last_token_usage": {
            "input_tokens": 100,
            "cached_input_tokens": 80,
            "output_tokens": 20,
          },
        },
      },
    }
    (sessions / "session.jsonl").write_text(json.dumps(entry) + "\n")
    with patch.dict(os.environ, {"CODEX_HOME": str(self.root)}):
      scanner["scan_native_codex_sessions"]()
    state = scanner["scan_native_codex_sessions"].__globals__
    self.assertEqual(state["today_total_tokens"], 120)
    self.assertEqual(state["today_prompts"], 1)


if __name__ == "__main__":
  unittest.main()
