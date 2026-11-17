"""In-memory preview devices, also used by the GTK interaction checks."""
import copy

from core import POWER_PROFILES
from hyprland import parse_outputs


class DemoPreferences:
    def __init__(self):
        self.state = {}

    def read(self):
        return copy.deepcopy(self.state)

    def update(self, key, value):
        if value is None:
            self.state.pop(key, None)
        else:
            self.state[key] = copy.deepcopy(value)

    def update_device(self, key, value):
        devices = self.read().get("input_devices", {})
        if value is None:
            devices.pop(key, None)
        else:
            devices[key] = value
        self.update("input_devices", devices or None)


class Demo:
    def __init__(self):
        self.calls = []
        self.defaults = {"capabilities": {"hasBacklight": True, "hasBattery": True, "hasBluetooth": True, "hasPowerProfiles": True},
                         "display": {"primaryOutput": "eDP-1", "layout": "extend", "primaryRotation": "normal",
                                     "blankAfterSeconds": 0}, "keyboard": {"delay": 200, "rate": 50},
                         "input": {"mouse": {"speed": 0, "natural": True},
                                   "touchpad": {"speed": 0, "natural": True, "tapping": True}}}
        self.monitors = parse_outputs([
            {"id": index, "name": name, "width": 1920, "height": 1080, "refreshRate": 60, "x": index * 1920,
             "y": 0, "transform": 0, "scale": 1.0,
             "availableModes": ["1920x1080@60.00Hz", f"1920x1080@{rate}.00Hz", "1280x720@60.00Hz"]}
            for index, (name, rate) in enumerate((("eDP-1", 120), ("HDMI-2", 144)))
        ])
        for index, output in enumerate(self.monitors):
            output["primary"] = index == 0
        self.default_monitors = copy.deepcopy(self.monitors)
        self.audio = {"sinks": [{"name": "speakers", "description": "Built-in speakers", "volume": 65, "mute": False},
                                {"name": "headphones", "description": "Studio headphones", "volume": 40, "mute": False}],
                      "sources": [{"name": "microphone", "description": "Built-in microphone", "volume": 70, "mute": False}],
                      "sink": "speakers", "source": "microphone"}
        self.devices = [{"id": "12", "name": "Precision touchpad", "key": "touchpad", "touchpad": True,
                         "speed": 0.0, "natural": True, "tapping": True}]
        self.brightness_percent = 70
        self.keyboard = {"delay": 200, "rate": 50}
        self.blank_seconds = 0
        self.power_profile = "balanced"
        self.wifi = {"enabled": True, "available": True,
                     "networks": [{"name": "Home", "ssid": b"Home", "security": "wpa", "strength": 94,
                                   "saved": "home", "active": True, "status": "Connected", "device": "wifi", "path": "home"},
                                  {"name": "Guest", "ssid": b"Guest", "security": "wpa", "strength": 72,
                                   "saved": None, "active": False, "status": "Disconnected", "device": "wifi", "path": "guest"}],
                     "wired": [{"name": "Ethernet", "status": "Disconnected", "address": ""}],
                     "profiles": [{"name": "Home", "uuid": "home", "type": "802-11-wireless", "active": True}]}
        self.bluetooth = {"adapters": [{"path": "adapter", "name": "Bluetooth", "powered": True, "discovering": False, "scanning": False}],
                          "devices": [{"path": "headphones", "name": "Studio headphones", "adapter": "adapter",
                                       "paired": True, "connected": True, "trusted": True},
                                      {"path": "keyboard", "name": "Wireless keyboard", "adapter": "adapter",
                                       "paired": False, "connected": False, "trusted": False}]}

    def command(self, name, *args):
        self.calls.append((name, *args))
        if name == "pactl":
            operation = args[0]
            if operation in ("set-default-sink", "set-default-source"):
                self.audio["sink" if operation.endswith("sink") else "source"] = args[1]
            elif operation.startswith("set-"):
                kind = "sinks" if "sink" in operation else "sources"
                device = next(item for item in self.audio[kind] if item["name"] == args[1])
                if "volume" in operation:
                    device["volume"] = int(str(args[2]).rstrip("%"))
                else:
                    device["mute"] = bool(int(args[2]))
        elif name == "brightnessctl":
            self.brightness_percent = int(str(args[-1]).rstrip("%"))
        return ""

    def snapshot(self, kind):
        return copy.deepcopy({"display": {"outputs": self.monitors, "brightness": self.brightness_percent},
            "audio": self.audio, "input": {"devices": self.devices, "keyboard": self.keyboard},
            "power": {"batteries": [{"name": "Battery", "capacity": "82", "status": "Discharging", "charge_limit": "80"}],
                      "blank_seconds": self.blank_seconds, "power_profiles": {
                          "available": True, "active": self.power_profile, "profiles": list(POWER_PROFILES)}},
            "shortcuts": [("Super + S", "Desktop Settings"), ("Super + L", "Lock screen"),
                          ("Super + 1", "Switch to workspace 1")],
            "about": [("System", "Linux"), ("Device", "Preview device"), ("Session", "Hyprland"),
                      ("Memory", "16 GiB"), ("Desktop Settings", "0.1.0")],
            "network": self.wifi, "bluetooth": self.bluetooth}[kind])

    def display_default(self):
        return {"layout": "extend", "outputs": copy.deepcopy(self.default_monitors)}

    def apply_display(self, plan):
        primary = next(item["name"] for item in plan["outputs"] if item["enabled"] and item["primary"])
        for values in plan["outputs"]:
            output = next(item for item in self.monitors if item["name"] == values["name"])
            output.update(values)
            output["mirror"] = primary if plan["layout"] == "mirror" and output["enabled"] and not output["primary"] else None
            if not output["enabled"]:
                output.update(mode=None, rate=None)


class DemoRadio:
    def __init__(self, demo, kind):
        self.demo, self.kind = demo, kind

    def snapshot(self):
        return self.demo.snapshot(self.kind)

    def toggle(self, *args):
        self.demo.calls.append((self.kind, "toggle", *args))
        if self.kind == "network":
            self.demo.wifi["enabled"] = args[0]
        else:
            self.demo.bluetooth["adapters"][0]["powered"] = args[1]

    def scan(self, *args):
        self.demo.calls.append((self.kind, "scan"))
        if self.kind == "network":
            args[0](None)
        else:
            self.demo.bluetooth["adapters"][0].update(discovering=True, scanning=True)

    def stop_scan(self):
        if self.kind == "bluetooth":
            self.demo.bluetooth["adapters"][0].update(discovering=False, scanning=False)

    def connect_network(self, item, password, callback):
        # Never store the submitted password, including in the preview log.
        self.demo.calls.append(("network", "connect", item["name"]))
        for network in self.demo.wifi["networks"]:
            network["active"] = network["name"] == item["name"]
            if network["active"]:
                network["saved"] = network["saved"] or network["path"]
                network["active_uuid"] = network["saved"]
        identity = next(network["saved"] for network in self.demo.wifi["networks"] if network["active"])
        for profile in self.demo.wifi["profiles"]:
            profile["active"] = profile["uuid"] == identity
        if not any(profile["uuid"] == identity for profile in self.demo.wifi["profiles"]):
            self.demo.wifi["profiles"].append({"name": item["name"], "uuid": identity, "type": "802-11-wireless", "active": True})
        callback(None)

    def activate(self, value, callback):
        self.demo.calls.append(("network", "activate", value))
        callback(None)

    def disconnect(self, value, callback):
        self.demo.calls.append(("network", "disconnect", value))
        for network in self.demo.wifi["networks"]:
            if network.get("active_uuid", network["saved"]) == value:
                network["active"] = False
        for profile in self.demo.wifi["profiles"]:
            if profile["uuid"] == value:
                profile["active"] = False
        callback(None)

    def forget(self, value, callback):
        self.demo.calls.append(("network", "forget", value))
        self.demo.wifi["profiles"] = [item for item in self.demo.wifi["profiles"] if item["uuid"] != value]
        callback(None)

    def action(self, item, action, callback):
        self.demo.calls.append(("bluetooth", action, item["name"]))
        device = next(value for value in self.demo.bluetooth["devices"] if value["path"] == item["path"])
        if action == "Pair":
            device["paired"] = device["trusted"] = True
        elif action == "RemoveDevice":
            self.demo.bluetooth["devices"].remove(device)
        else:
            device["connected"] = action == "Connect"
        callback(None)

    def close(self):
        pass
