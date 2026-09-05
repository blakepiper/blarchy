"""Widget behavior with fake audio/network backends; never changes the desktop."""
import json
from pathlib import Path
import runpy
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

try:
  import gi
  gi.require_version("Gtk", "3.0")
  gi.require_version("Gdk", "3.0")
  gi.require_version("GtkLayerShell", "0.1")
  gi.require_version("NM", "1.0")
  from gi.repository import GLib, Gtk, NM
  AVAILABLE = Gtk.init_check()[0]
except (ImportError, ValueError):
  AVAILABLE = False

MODULE = runpy.run_path(str(Path(__file__).resolve().parents[1] / "bin/topbar-panel"), run_name="topbar_test") if AVAILABLE else {}


class FakePanel:
  def __init__(self):
    self.alive = True
    self.widgets = []
    self.status = ""
    self.timer = 0

  def add(self, widget):
    self.widgets.append(widget)

  def clear(self):
    self.widgets.clear()

  def message(self, text, error=False):
    self.status = text

  def work(self, task, done):
    done(task())

  def load_audio(self):
    pass


@unittest.skipUnless(AVAILABLE, "GTK/libnm and a graphical session are required")
class PanelTests(unittest.TestCase):
  def test_outside_click_closes_panel_but_inside_click_does_not(self):
    panel = SimpleNamespace(card=Mock(), destroy=Mock())
    method = MODULE["Panel"].outside_click
    with patch.object(MODULE["Gtk"], "get_event_widget", return_value=panel.card):
      method(panel, None, Mock())
    panel.destroy.assert_not_called()
    outside = Mock()
    outside.is_ancestor.return_value = False
    with patch.object(MODULE["Gtk"], "get_event_widget", return_value=outside):
      method(panel, None, Mock())
    panel.destroy.assert_called_once()

  def test_volume_averages_channels(self):
    volume = MODULE["volume_percent"]
    self.assertEqual(volume({"volume": {"left": {"value": 65536}, "right": {"value": 0}}}), 50)
    self.assertEqual(volume({}), 0)

  def test_audio_without_microphone_keeps_output_controls(self):
    sinks = [{"name": "speaker", "description": "Speaker", "mute": False,
              "volume": {"mono": {"value": 32768}}}]
    def command(*args):
      if args[-1] == "sinks":
        return json.dumps(sinks)
      if args[-1] == "sources":
        return "[]"
      if args[-1] == "get-default-sink":
        return "speaker"
      self.fail(f"Unexpected command: {args}")
    panel = FakePanel()
    method = MODULE["Panel"].load_audio
    with patch.dict(method.__globals__, command=command):
      method(panel)
    scale = next(widget for widget in panel.widgets if isinstance(widget, Gtk.Scale))
    self.assertEqual(scale.get_value(), 50)
    labels = [widget.get_label() for widget in panel.widgets if isinstance(widget, Gtk.Button)]
    self.assertIn("Mute output", labels)
    self.assertNotIn("Mute microphone", labels)

  def test_audio_without_outputs_shows_empty_state(self):
    panel = FakePanel()
    method = MODULE["Panel"].load_audio
    with patch.dict(method.__globals__, command=lambda *args: "[]"):
      method(panel)
    self.assertEqual(panel.status, "No audio output is available.")

  def wifi(self):
    wifi = MODULE["Wifi"].__new__(MODULE["Wifi"])
    wifi.NM = NM
    wifi.panel = FakePanel()
    wifi.client = Mock()
    wifi.device = Mock()
    wifi.device.get_available_connections.return_value = []
    wifi.editing = False
    wifi.connecting = False
    wifi.connect_button = None
    ap = Mock()
    flags = getattr(NM, "80211ApSecurityFlags")
    ap.get_rsn_flags.return_value = flags.KEY_MGMT_PSK
    ap.get_wpa_flags.return_value = 0
    ap.get_flags.return_value = getattr(NM, "80211ApFlags").PRIVACY
    ap.get_ssid.return_value = GLib.Bytes.new(b'Cafe: "hello"')
    ap.get_path.return_value = "/fake/ap"
    return wifi, ap

  def test_password_validation_and_single_activation(self):
    wifi, ap = self.wifi()
    wifi.credentials(ap, "Cafe")
    entry = next(w for w in wifi.panel.widgets if isinstance(w, Gtk.Entry))
    entry.set_text("short")
    wifi.connect_button.clicked()
    wifi.client.add_and_activate_connection_async.assert_not_called()
    self.assertIn("valid Wi-Fi password", wifi.panel.status)
    entry.set_text("a secret password")
    wifi.connect_button.clicked()
    # Enter must not create a second connection while the first is pending.
    entry.emit("activate")
    wifi.client.add_and_activate_connection_async.assert_called_once()
    connection = wifi.client.add_and_activate_connection_async.call_args.args[0]
    self.assertEqual(bytes(connection.get_setting_wireless().get_ssid().get_data()), b'Cafe: "hello"')
    self.assertEqual(connection.get_setting_wireless_security().get_psk(), "a secret password")

  def test_scan_does_not_erase_password_entry(self):
    wifi, ap = self.wifi()
    wifi.credentials(ap, "Cafe")
    previous = list(wifi.panel.widgets)
    wifi.render()
    self.assertEqual(wifi.panel.widgets, previous)

  def test_saved_network_reuses_profile(self):
    wifi, ap = self.wifi()
    saved = Mock()
    wifi.device.get_available_connections.return_value = [saved]
    ap.connection_valid.return_value = True
    wifi.choose(ap, "Cafe", False)
    wifi.client.activate_connection_async.assert_called_once()
    self.assertIs(wifi.client.activate_connection_async.call_args.args[0], saved)
    wifi.client.add_and_activate_connection_async.assert_not_called()

  def test_connection_error_allows_retry(self):
    wifi, ap = self.wifi()
    wifi.credentials(ap, "Cafe")
    wifi.connecting = True
    wifi.connect_button.set_sensitive(False)
    wifi.client.add_and_activate_connection_finish.side_effect = GLib.Error("Wrong password")
    wifi.finish("add_and_activate_connection_finish")(wifi.client, Mock())
    self.assertFalse(wifi.connecting)
    self.assertTrue(wifi.connect_button.get_sensitive())
    self.assertEqual(wifi.panel.status, "Wrong password")

  def test_iwd_credentials_use_dbus_and_can_be_canceled(self):
    wifi = MODULE["IwdWifi"].__new__(MODULE["IwdWifi"])
    wifi.panel = FakePanel()
    wifi.pending = None
    wifi.render = Mock()
    invocation = Mock()
    wifi.agent(None, None, None, None, "RequestPassphrase", None, invocation)
    password = next(w for w in wifi.panel.widgets if isinstance(w, Gtk.Entry))
    password.set_text("a secret password")
    password.emit("activate")
    self.assertEqual(invocation.return_value.call_args.args[0].unpack(), ("a secret password",))
    self.assertIsNone(wifi.pending)
    pending = Mock()
    wifi.pending = pending
    wifi.cancel()
    pending.return_dbus_error.assert_called_once()
    self.assertIsNone(wifi.pending)

  def test_ai_refresh_updates_bar_and_remaining_progress(self):
    panel = FakePanel()
    ai = {"fetch_data": lambda **kwargs: {"providers": [{"name": "Fixture", "limits": [{"percent": 0.2}]}]},
          "normalized_percent": lambda value: value, "reset_text": lambda value: "",
          "provider_lines": lambda provider: ["Today: 10 tokens"], "details_text": lambda data: "Updated now"}
    method = MODULE["Panel"].load_ai
    with patch.dict(method.__globals__, runpy=SimpleNamespace(run_path=lambda path: ai)), \
         patch("subprocess.run") as run:
      method(panel, True)
    progress = next(w for w in panel.widgets if isinstance(w, Gtk.ProgressBar))
    self.assertAlmostEqual(progress.get_fraction(), 0.8)
    run.assert_called_once_with(["pkill", "-RTMIN+9", "-x", "waybar"], check=False)


if __name__ == "__main__":
  unittest.main()
