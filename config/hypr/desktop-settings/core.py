"""Shared settings, system service clients and user preference storage."""

from contextlib import closing, contextmanager
import fcntl
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import time
import wave


class SettingsError(Exception):
    pass


def command(name, *args, timeout=12):
    try:
        result = subprocess.run([name, *map(str, args)], capture_output=True,
                                text=True, timeout=timeout, env={**os.environ, "LC_ALL": "C"})
    except (OSError, subprocess.TimeoutExpired) as error:
        raise SettingsError(f"Could not run {name}: {error}") from error
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise SettingsError(detail or f"{name} could not complete the request.")
    return result.stdout


def config_home():
    return Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))


def config_root():
    return config_home() / "desktop-settings"


def load_json(path):
    try:
        value = json.loads(Path(path).read_text())
    except FileNotFoundError:
        return {}
    except OSError as error:
        raise SettingsError(f"Could not read {Path(path).name}: {error}") from error
    except ValueError as error:
        raise SettingsError(f"Invalid JSON in {Path(path).name}: {error}") from error
    if not isinstance(value, dict):
        raise SettingsError(f"The settings in {Path(path).name} must be an object.")
    return value


def atomic_write(path, content):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


@contextmanager
def lock_file(path, blocking=True):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with path.open("a") as lock:
        flags = fcntl.LOCK_EX if blocking else fcntl.LOCK_EX | fcntl.LOCK_NB
        fcntl.flock(lock, flags)
        yield


class Preferences:
    def __init__(self, path=None):
        self.path = Path(path) if path else config_root() / "settings.json"

    def read(self):
        value = load_json(self.path)
        if value.get("version", 1) != 1:
            raise SettingsError("The saved settings format is not supported.")
        return value

    def update(self, key, value):
        with lock_file(self.path.with_name(".settings.lock")):
            self.write(self.read(), key, value)

    def update_device(self, key, value):
        with lock_file(self.path.with_name(".settings.lock")):
            state = self.read()
            devices = state.get("input_devices", {})
            devices.pop(key, None) if value is None else devices.update({key: value})
            self.write(state, "input_devices", devices or None)

    def write(self, state, key, value):
        if value is None:
            state.pop(key, None)
        else:
            state[key] = value
        state["version"] = 1
        atomic_write(self.path, json.dumps(state, indent=2, ensure_ascii=False) + "\n")


def defaults():
    return load_json(os.environ.get("DESKTOP_SETTINGS_DEFAULTS", config_root() / "defaults.json"))


def capability(name, discovered=True):
    value = defaults().get("capabilities", {}).get(name)
    return value if isinstance(value, bool) else discovered


def nightlight_settings(preferences=None):
    value = (preferences or Preferences()).read().get("nightlight", {"enabled": False, "intensity": 50})
    if (not isinstance(value, dict) or type(value.get("enabled")) is not bool
            or type(value.get("intensity")) is not int or not 0 <= value["intensity"] <= 100):
        raise SettingsError("The saved night light setting is invalid.")
    return value


POWER_PROFILES = {
    "performance": ("Performance", "Favor performance when hardware allows it."),
    "balanced": ("Balanced", "Balance performance and energy use."),
    "power-saver": ("Power Saver", "Favor lower power consumption."),
}
POWER_SERVICES = (
    ("org.freedesktop.UPower.PowerProfiles", "/org/freedesktop/UPower/PowerProfiles"),
    ("net.hadess.PowerProfiles", "/net/hadess/PowerProfiles"),
)


@contextmanager
def system_bus():
    try:
        import dbus
    except ImportError as error:
        raise SettingsError("Install the Python D-Bus bindings to use system services.") from error
    try:
        with closing(dbus.SystemBus(private=True)) as bus:
            yield dbus, bus
    except dbus.DBusException as error:
        raise SettingsError(error.get_dbus_message()) from error


def power_profile_call(method, *args):
    with system_bus() as (dbus, bus):
        for name, path in POWER_SERVICES:
            try:
                proxy = bus.get_object(name, path, introspect=False)
                properties = dbus.Interface(proxy, "org.freedesktop.DBus.Properties")
                signature = "ssv" if method == "Set" else "s"
                return getattr(properties, method)(name, *args, signature=signature, timeout=4)
            except dbus.DBusException as error:
                if error.get_dbus_name() not in ("org.freedesktop.DBus.Error.ServiceUnknown",
                                                "org.freedesktop.DBus.Error.NameHasNoOwner"):
                    raise
    raise SettingsError("Run power-profiles-daemon or tlp-pd to select a power mode.")


def power_profiles():
    if not capability("hasPowerProfiles"):
        raise SettingsError("Power profiles are disabled in defaults.json.")
    properties = power_profile_call("GetAll")
    available = [str(item["Profile"]) for item in properties.get("Profiles", [])]
    active = str(properties.get("ActiveProfile", ""))
    if active not in POWER_PROFILES or active not in available:
        raise SettingsError("The power service reported an unknown mode.")
    return {"available": True, "active": active,
            "profiles": [profile for profile in POWER_PROFILES if profile in available]}


def power_profile_state():
    try:
        return power_profiles()
    except SettingsError as error:
        return {"available": False, "profiles": [], "error": str(error)}


def set_power_profile(profile, preferences=None, persist=True):
    if not isinstance(profile, str) or profile not in POWER_PROFILES:
        raise SettingsError("Choose Performance, Balanced or Power Saver.")
    preferences = preferences or Preferences()
    with lock_file(preferences.path.with_name(".power-mode.lock")):
        current = power_profiles()
        if profile not in current["profiles"]:
            raise SettingsError("This power mode is unavailable on this device.")
        if profile != current["active"]:
            power_profile_call("Set", "ActiveProfile", profile)
            # tlp-pd can acknowledge before its detached process applies the mode.
            deadline = time.monotonic() + 8
            while power_profiles()["active"] != profile:
                if time.monotonic() >= deadline:
                    raise SettingsError("The power service did not confirm the selected mode.")
                time.sleep(0.1)
        if persist:
            try:
                preferences.update("power_mode", profile)
            except (OSError, SettingsError):
                if current["active"] != profile:
                    power_profile_call("Set", "ActiveProfile", current["active"])
                raise


def audio_state():
    def devices(kind):
        result = []
        for item in json.loads(command("pactl", "--format=json", "list", kind)):
            if kind == "sources" and (item.get("name", "").endswith(".monitor") or
                                     item.get("properties", {}).get("device.class") == "monitor"):
                continue
            volumes = [channel["value"] for channel in item.get("volume", {}).values()]
            result.append({"name": item["name"], "description": item.get("description", item["name"]),
                           "volume": round(sum(volumes) / len(volumes) / 65536 * 100) if volumes else 0,
                           "mute": item.get("mute", False)})
        return result
    return {"sinks": devices("sinks"), "sources": devices("sources"),
            "sink": command("pactl", "get-default-sink").strip(),
            "source": command("pactl", "get-default-source").strip()}


def play_test_sound(device):
    with tempfile.NamedTemporaryFile(suffix=".wav") as sound:
        with wave.open(sound.name, "wb") as audio:
            audio.setparams((1, 2, 24000, 0, "NONE", "not compressed"))
            audio.writeframes(b"".join(struct.pack("<h", int(4500 * math.sin(2 * math.pi * 440 * i / 24000)
                              * min(1, i / 1200, (12000 - i) / 1200))) for i in range(12000)))
        command("paplay", "--device", device, sound.name)


def has_backlight():
    return capability("hasBacklight", any(Path("/sys/class/backlight").glob("*")))


def brightness():
    result = command("brightnessctl", "--class=backlight", "--machine-readable").strip().split(",")
    if len(result) < 4:
        raise SettingsError("No backlight is available through brightnessctl.")
    return int(result[3].rstrip("%"))


def batteries():
    result = []
    for path in sorted(Path("/sys/class/power_supply").glob("*")):
        def read(name):
            try:
                return (path / name).read_text().strip()
            except OSError:
                return ""
        if read("type") != "Battery" or read("scope") == "Device":
            continue
        result.append({"name": path.name, "capacity": read("capacity"), "status": read("status"),
                       "charge_limit": read("charge_control_end_threshold")})
    return result


def suspend_capability():
    if defaults().get("suspendCommand"):
        return None
    if not shutil.which("systemctl"):
        return "Install systemd session tools to suspend."
    try:
        with system_bus() as (_, bus):
            manager = bus.get_object("org.freedesktop.login1", "/org/freedesktop/login1", introspect=False)
            capability = manager.CanSuspend(dbus_interface="org.freedesktop.login1.Manager", timeout=4)
    except SettingsError as error:
        return f"Could not check logind suspend support: {error}"
    if capability not in ("yes", "challenge"):
        return "Logind does not allow this session to suspend."
    return None


def system_info():
    info = {}
    release = ""
    for path in (Path("/etc/os-release"), Path("/usr/lib/os-release")):
        if path.is_file():
            release = path.read_text()
            break
    for line in release.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            info[key] = value.strip('"')
    memory = re.search(r"MemTotal:\s+(\d+)", Path("/proc/meminfo").read_text())
    cpu = re.search(r"(?:model name|Hardware)\s*:\s*(.+)", Path("/proc/cpuinfo").read_text())
    disk = shutil.disk_usage("/")
    return [("System", info.get("PRETTY_NAME", "Linux")), ("Device", os.uname().nodename),
            ("Session", "Hyprland"), ("Kernel", os.uname().release),
            ("Processor", cpu[1] if cpu else os.uname().machine),
            ("Memory", f"{int(memory[1]) / 1024 ** 2:.1f} GiB" if memory else "Unknown"),
            ("Storage available", f"{disk.free / 1024 ** 3:.1f} / {disk.total / 1024 ** 3:.1f} GiB"),
            ("Desktop Settings", "0.1.0")]
