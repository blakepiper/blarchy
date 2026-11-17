"""Native Hyprland display, input, night light and session controls."""

import json
import math
import os
from pathlib import Path
import re
import select
import shutil
import signal
import socket
import subprocess
import sys
import time

from core import (Preferences, SettingsError, atomic_write, brightness, capability, command, defaults,
                  load_json, lock_file, nightlight_settings, set_power_profile)


ROTATIONS = {"normal": 0, "left": 1, "inverted": 2, "right": 3, "flipped": 4,
             "flipped-left": 5, "flipped-inverted": 6, "flipped-right": 7}
MODE = re.compile(r"(\d+x\d+)@(\d+(?:\.\d+)?)Hz")
INPUT_FIELDS = {"speed": "sensitivity", "natural": "natural_scroll", "tapping": "tap_to_click"}
NIGHTLIGHT_UNIT = "hyprsunset.service"


def runtime_root():
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not runtime or not re.fullmatch(r"[a-zA-Z0-9_-]+", signature):
        raise SettingsError("Start a Hyprland session to use these settings.")
    root = Path(runtime) / "hypr" / signature
    if not root.is_dir() or root.is_symlink() or root.stat().st_uid != os.getuid():
        raise SettingsError("The active Hyprland instance could not be found.")
    return root


def lua_string(value):
    # Lua accepts byte escapes for quotes, backslashes and control characters.
    return '"' + re.sub(r'[\x00-\x1f"\\]', lambda match: f"\\{ord(match[0]):03d}", value) + '"'


def hypr_command(*args, timeout=6):
    runtime_root()
    return command("hyprctl", *args, timeout=timeout).strip()


def hypr_json(*args):
    response = hypr_command("-j", *args)
    try:
        return json.loads(response)
    except ValueError as error:
        raise SettingsError(response or "Hyprland returned no data.") from error


def hypr_change(*args):
    response = hypr_command(*args)
    if response != "ok":
        raise SettingsError(response or "Hyprland did not acknowledge the change.")


def outputs():
    return parse_outputs(hypr_json("monitors", "all"))


def parse_outputs(monitors):
    names = {str(item["id"]): item["name"] for item in monitors}
    result = []
    for item in monitors:
        modes = {}
        for value in item.get("availableModes", []):
            match = MODE.fullmatch(value)
            if match:
                rates = modes.setdefault(match[1], [])
                if match[2] not in rates:
                    rates.append(match[2])
        enabled = not item.get("disabled", False)
        mode = f"{item['width']}x{item['height']}" if enabled and item["width"] and item["height"] else None
        rate = None
        if mode and item["refreshRate"] > 0:
            rates = modes.setdefault(mode, [])
            rate = f"{item['refreshRate']:.2f}"
            if rate not in rates:
                rates.append(rate)
        mirror_id = str(item.get("mirrorOf", "none"))
        mirror = names.get(mirror_id, mirror_id if mirror_id in names.values() else None)
        result.append({"name": item["name"], "connected": True, "enabled": enabled,
                       "mode": mode if rate else None, "rate": rate, "modes": modes, "mirror": mirror,
                       "rotation": next((name for name, value in ROTATIONS.items() if value == item["transform"]), "normal"),
                       "scale": round(item["scale"], 4) or 1.0, "x": item["x"], "y": item["y"]})
    return result


def mode_size(mode, rotation="normal", scale=1):
    width, height = map(int, mode.split("x"))
    if ROTATIONS[rotation] % 2:
        width, height = height, width
    return max(1, round(width / scale)), max(1, round(height / scale))


def preferred_mode(output, wanted=None):
    modes = output["modes"]
    if not modes:
        raise SettingsError(f"{output['name']} has no advertised display modes.")
    if wanted in modes:
        return wanted
    return output.get("mode") or next(iter(modes))


def choose_rate(output, mode, wanted=None):
    rates = output["modes"][mode]
    return wanted if wanted in rates else max(rates, key=float)


def primary_output(available, requested=None):
    active = [item for item in available if item["enabled"] and item["mode"] and not item.get("mirror")]
    if not active:
        return None
    mirror_sources = {item["mirror"] for item in available if item.get("mirror")}
    main = next((item for item in active if item["name"] in mirror_sources), None)
    if not main:
        main = next((item for item in active if item["name"] == requested),
                    min(active, key=lambda item: (item["x"], item["y"], item["name"])))
    return main["name"]


def display_state(backlight=True):
    available = outputs()
    preferences = Preferences().read()
    saved = preferences.get("display", {}).get("outputs", [])
    configured = defaults().get("display", {}).get("primaryOutput")
    primary = primary_output(available, next((item["name"] for item in saved if item.get("primary")), configured))
    for item in available:
        item["primary"] = item["name"] == primary
    state = {"outputs": available, "brightness": None, "brightness_error": None,
             "nightlight_error": nightlight_capability()}
    if backlight:
        try:
            state["brightness"] = brightness()
        except (SettingsError, ValueError) as error:
            state["brightness_error"] = str(error)
    return state


def validate_display(plan, available):
    if not isinstance(plan, dict) or plan.get("layout") not in ("mirror", "extend") or not isinstance(plan.get("outputs"), list):
        raise SettingsError("Choose a valid display layout.")
    actual = {item["name"]: item for item in available if item["modes"]}
    enabled, names = [], set()
    for item in plan["outputs"]:
        if not isinstance(item, dict) or not isinstance(item.get("name"), str) or type(item.get("enabled")) is not bool:
            raise SettingsError("The display layout is invalid.")
        name = item["name"]
        if name in names or name not in actual:
            raise SettingsError("The connected displays changed. Refresh and try again.")
        names.add(name)
        if not item.get("enabled"):
            continue
        mode = item.get("mode")
        if not isinstance(mode, str) or mode not in actual[name]["modes"]:
            raise SettingsError(f"{name} does not advertise this resolution.")
        if str(item.get("rate")) not in actual[name]["modes"][mode]:
            raise SettingsError(f"{name} does not advertise this refresh rate at the selected resolution.")
        if item.get("rotation") not in ROTATIONS:
            raise SettingsError("Choose a valid display rotation.")
        if type(item.get("scale")) not in (int, float) or not 0.5 <= item["scale"] <= 4:
            raise SettingsError("Display scale must be between 50% and 400%.")
        if any(type(item.get(axis)) is not int or not -16384 <= item[axis] <= 16384 for axis in ("x", "y")):
            raise SettingsError("Display positions must be between −16384 and 16384 pixels.")
        enabled.append(item)
    if names != set(actual):
        raise SettingsError("The connected displays changed. Refresh and try again.")
    if not enabled or sum(item.get("primary") is True for item in enabled) != 1:
        raise SettingsError("Enable at least one display and choose one enabled main display.")
    return plan


def arranged_outputs(plan):
    primary = next(item for item in plan["outputs"] if item["enabled"] and item.get("primary") is True)
    return [{**item, "mirror": primary["name"] if plan["layout"] == "mirror"
                                and item["enabled"] and item is not primary else None}
            for item in plan["outputs"]]


def display_matches(expected, actual):
    by_name = {item["name"]: item for item in actual}
    for item in expected:
        live = by_name.get(item["name"])
        if not live or item["enabled"] != live["enabled"]:
            return False
        if not item["enabled"]:
            continue
        if (item["mode"] != live["mode"] or not live["rate"]
                or not math.isclose(float(item["rate"]), float(live["rate"]), abs_tol=0.015)
                or item["rotation"] != live["rotation"]
                or not math.isclose(float(item["scale"]), live["scale"], abs_tol=0.002)
                or item.get("mirror") != live.get("mirror")):
            return False
        if not item.get("mirror") and (item["x"], item["y"]) != (live["x"], live["y"]):
            return False
    return True


def apply_display(items):
    current = outputs()
    if display_matches(items, current):
        return
    # Promote the new source before attaching any mirror to it.
    current_by_name = {item["name"]: item for item in current}
    promoted = [item["name"] for item in items if item["enabled"] and not item.get("mirror")
                and current_by_name.get(item["name"], {}).get("mirror")]
    if promoted:
        hypr_change("eval", "\n".join(f"hl.monitor({{ output = {lua_string(name)}, mirror = \"\" }})"
                                     for name in promoted)
                    + "\nlocal refresh = hl.exec_scheduled_prop_refresh_immediately or hl.force_prop_refresh"
                    + "\nif refresh then refresh() end")
    rules = []
    for item in sorted(items, key=lambda value: (not value["enabled"], bool(value.get("mirror")))):
        name = lua_string(item["name"])
        if not item["enabled"]:
            rules.append(f'hl.monitor({{ output = {name}, disabled = true, mirror = "" }})')
            continue
        mode = lua_string(f"{item['mode']}@{item['rate']}")
        position = lua_string(f"{item['x']}x{item['y']}" if not item.get("mirror") else "auto")
        rules.append(f"hl.monitor({{ output = {name}, disabled = false, mode = {mode}, position = {position}, "
                     f"scale = {item['scale']:g}, transform = {ROTATIONS[item['rotation']]}, "
                     f"mirror = {lua_string(item.get('mirror') or '')} }})")
    hypr_change("eval", "\n".join(rules))
    deadline = time.monotonic() + 1.5
    while not display_matches(items, outputs()):
        if time.monotonic() >= deadline:
            raise SettingsError("Hyprland could not apply the requested mode, scale, or arrangement.")
        time.sleep(0.1)


def restore_display(snapshot):
    available = outputs()
    names = {item["name"] for item in available}
    active = {item["name"] for item in snapshot if item["enabled"] and item["name"] in names and item["mode"]}
    if not active:
        hypr_change("reload")
        return
    original = [
        {**item, "mirror": item["mirror"] if item.get("mirror") in active else None}
        for item in snapshot if item["name"] in names and (not item["enabled"] or item["mode"])
    ]
    apply_display(original)


def preview_display(request, input_stream=sys.stdin, output_stream=sys.stdout, seconds=15):
    """With no keep response from the GUI, restore the original modes on timeout or EOF."""
    root = runtime_root()
    marker = root / ".desktop-settings-display-managed"
    preferences = Preferences()
    try:
        with lock_file(root / ".desktop-settings-display.lock", blocking=False):
            previous = outputs()
            restoring_defaults = request.get("restore", False)
            if not restoring_defaults:
                plan = validate_display(request.get("plan"), previous)
            managed = marker.exists()
            kept = False

            def interrupted(*_):
                raise SettingsError("The display preview was interrupted.")

            handlers = {sig: signal.signal(sig, interrupted) for sig in (signal.SIGTERM, signal.SIGINT)}
            try:
                if restoring_defaults:
                    marker.unlink(missing_ok=True)
                    hypr_change("reload")
                else:
                    marker.touch()
                    apply_display(arranged_outputs(plan))
                deadline = time.monotonic() + seconds
                print(json.dumps({"ready": True, "seconds": seconds}), file=output_stream, flush=True)
                ready, _, _ = select.select([input_stream], [], [], seconds)
                answer = input_stream.readline().strip() if ready else "revert"
                if answer == "keep" and time.monotonic() <= deadline:
                    if {item["name"] for item in outputs()} != {item["name"] for item in previous}:
                        raise SettingsError("Displays changed during preview. Refresh and try again.")
                    preferences.update("display", None if restoring_defaults else plan)
                    kept = True
            finally:
                try:
                    if not kept:
                        # Keep the compositor's automatic dock policy from racing the rollback.
                        marker.touch()
                        try:
                            restore_display(previous)
                        finally:
                            if not managed:
                                marker.unlink(missing_ok=True)
                finally:
                    for sig, handler in handlers.items():
                        signal.signal(sig, handler)
            print(json.dumps({"kept": kept}), file=output_stream, flush=True)
    except BlockingIOError as error:
        raise SettingsError("Another display change is awaiting confirmation.") from error


def saved_display(available, saved):
    remembered = {item["name"]: item for item in saved["outputs"]}
    items, new = [], []
    for output in available:
        if not output["modes"]:
            continue
        original = remembered.get(output["name"])
        mode = preferred_mode(output, original.get("mode") if original else None)
        rate = choose_rate(output, mode, original.get("rate") if original else output["rate"])
        item = {"name": output["name"], "mode": mode, "rate": rate}
        if original:
            item.update({key: original[key] for key in ("enabled", "primary", "rotation", "scale", "x", "y")})
        else:
            item.update(enabled=True, primary=False, rotation=output["rotation"], scale=output["scale"], x=0, y=0)
            new.append(item)
        items.append(item)
    if not items:
        raise SettingsError("No connected displays were found.")
    right = max((item["x"] + mode_size(item["mode"], item["rotation"], item["scale"])[0]
                 for item in items if item["enabled"] and item["name"] in remembered), default=0)
    for item in new:
        item["x"] = right
        right += mode_size(item["mode"], item["rotation"], item["scale"])[0]
    active = [item for item in items if item["enabled"]]
    if not active:
        items[0]["enabled"] = True
        active = items[:1]
    primary = next((item for item in active if item["primary"]), active[0])
    for item in items:
        item["primary"] = item is primary
    return validate_display({"layout": saved["layout"], "outputs": items}, available)


def apply_saved_display():
    root = runtime_root()
    marker = root / ".desktop-settings-display-managed"
    with lock_file(root / ".desktop-settings-display.lock", blocking=False):
        saved = Preferences().read().get("display")
        if not saved:
            marker.unlink(missing_ok=True)
            return
        previous = outputs()
        try:
            plan = saved_display(previous, saved)
        except (KeyError, TypeError, ValueError) as error:
            raise SettingsError("The saved display layout is invalid.") from error
        marker.touch()
        try:
            apply_display(arranged_outputs(plan))
        except SettingsError:
            try:
                restore_display(previous)
            finally:
                marker.unlink(missing_ok=True)
            raise


def nightlight_capability():
    if not capability("hasNightLight"):
        return "Night light is disabled in defaults.json."
    try:
        temperature = hypr_command("hyprsunset", "temperature", timeout=2)
        if temperature.isdecimal():
            return None
    except SettingsError:
        pass
    if os.environ.get("HYPRLAND_SESSION_BACKEND") == "systemd" and shutil.which("hyprsunset"):
        try:
            loaded = command("systemctl", "--user", "show", NIGHTLIGHT_UNIT, "-p", "LoadState", "--value", timeout=2)
            if loaded.strip() == "loaded":
                return None
        except SettingsError:
            pass
    return "Run hyprsunset in this Hyprland session to adjust warmth."


def apply_hyprland_nightlight(value=None, attempts=20):
    if not capability("hasNightLight"):
        return
    if value is None:
        value = nightlight_settings()
    request = ("temperature", 6500 - value["intensity"] * 40) if value["enabled"] else ("identity",)
    for attempt in range(attempts):
        try:
            hypr_change("hyprsunset", *request)
            return
        except SettingsError:
            if attempt == attempts - 1:
                raise
            time.sleep(0.1)


def set_nightlight(enabled, intensity, preferences=None):
    if type(enabled) is not bool or type(intensity) is not int or not 0 <= intensity <= 100:
        raise SettingsError("Choose a night light intensity between 0 and 100.")
    if reason := nightlight_capability():
        raise SettingsError(reason)
    preferences = preferences or Preferences()
    value = {"enabled": enabled, "intensity": intensity}
    with lock_file(preferences.path.with_name(".nightlight.lock")):
        previous = nightlight_settings(preferences)
        try:
            apply_hyprland_nightlight(value, attempts=1)
        except SettingsError:
            if os.environ.get("HYPRLAND_SESSION_BACKEND") != "systemd":
                raise
            command("systemctl", "--user", "reset-failed", NIGHTLIGHT_UNIT)
            command("systemctl", "--user", "start", NIGHTLIGHT_UNIT)
            apply_hyprland_nightlight(value)
        try:
            preferences.update("nightlight", value)
        except (OSError, SettingsError):
            apply_hyprland_nightlight(previous, attempts=1)
            raise


def keyboard_state():
    fields = {"delay": "input.repeat_delay", "rate": "input.repeat_rate"}
    return {key: hypr_json("getoption", field)["int"] for key, field in fields.items()}


def set_keyboard(value):
    delay, rate = value.get("delay"), value.get("rate")
    if type(delay) is not int or not 0 <= delay <= 65535 or type(rate) is not int or not 0 <= rate <= 1000:
        raise SettingsError("The keyboard repeat setting is invalid.")
    hypr_change("eval", f"hl.config({{ input = {{ repeat_delay = {delay}, repeat_rate = {rate} }} }})")


def keyboard_defaults(refresh=False):
    path = runtime_root() / ".desktop-settings-keyboard.json"
    value = load_json(path) if not refresh else {}
    if not value:
        value = keyboard_state()
        atomic_write(path, json.dumps(value) + "\n")
    return {**value, **defaults().get("keyboard", {})}


def save_keyboard(value, restore=False, preferences=None):
    preferences = preferences or Preferences()
    with lock_file(preferences.path.with_name(".input.lock")):
        baseline = keyboard_defaults()
        previous = keyboard_state()
        set_keyboard(baseline if restore else value)
        try:
            preferences.update("keyboard", None if restore else value)
        except (OSError, SettingsError):
            set_keyboard(previous)
            raise


def input_baseline(device, settings):
    touchpad = device["touchpad"]
    base = {"speed": hypr_json("getoption", "input.sensitivity")["float"]}
    if device.get("natural") is not None:
        path = "input.touchpad.natural_scroll" if touchpad else "input.natural_scroll"
        base["natural"] = hypr_json("getoption", path)["bool"]
    if device.get("tapping") is not None:
        base["tapping"] = hypr_json("getoption", "input.touchpad.tap_to_click")["bool"]
    return {key: value for key, value in {**base, **settings.get("touchpad" if touchpad else "mouse", {})}.items()
            if key in base}


def pointer_types():
    """Read udev's classified events without opening input devices."""
    result = {}
    for event in Path("/sys/class/input").glob("event*"):
        try:
            name = (event / "device/name").read_text().strip().lower().replace(" ", "-")
            number = (event / "dev").read_text().strip()
            properties = Path("/run/udev/data", f"c{number}").read_text().splitlines()
        except OSError:
            continue
        flags = set(properties)
        if "E:ID_INPUT_TOUCHPAD=1" in flags:
            result[name] = "touchpad"
        elif "E:ID_INPUT_POINTINGSTICK=1" in flags:
            result[name] = "pointing-stick"
        elif "E:ID_INPUT_MOUSE=1" in flags and "E:ID_INPUT_TABLET=1" not in flags:
            result.setdefault(name, "mouse")
    return result


def input_devices(preferences=None):
    pointers = hypr_json("devices").get("mice", [])
    settings = defaults().get("input", {})
    configured = settings.get("types", {})
    known = pointer_types()
    saved = (preferences or Preferences()).read().get("input_devices", {})
    result = []
    baselines = {}
    for pointer in pointers:
        name = pointer["name"]
        kind = configured.get(name) or known.get(name) or known.get(re.sub(r"-\d+$", "", name))
        if kind not in ("touchpad", "pointing-stick", "mouse"):
            continue
        device = {"id": name, "name": name, "key": name, "touchpad": kind == "touchpad", "speed": 0.0,
                  "natural": None if kind == "pointing-stick" else True,
                  "tapping": True if kind == "touchpad" else None}
        if kind not in baselines:
            baselines[kind] = input_baseline(device, settings)
        # Per-device defaults can supplement compositor options that IPC cannot read back.
        per_device = settings.get("devices", {}).get(name, {})
        desired = {**baselines[kind], **per_device, **saved.get(name, {})}
        device.update({key: desired[key] for key in INPUT_FIELDS if device[key] is not None and key in desired})
        result.append(device)
    return result


def input_rule(name, values):
    fields = [f"name = {lua_string(name)}"]
    for key, value in values.items():
        valid = type(value) in (int, float) and -1 <= value <= 1 if key == "speed" else type(value) is bool
        if key not in INPUT_FIELDS or not valid:
            raise SettingsError("The pointing-device setting is invalid.")
        fields.append(f"{INPUT_FIELDS[key]} = {str(value).lower()}")
    return "hl.device({ " + ", ".join(fields) + " })"


def set_input(device, values):
    hypr_change("eval", input_rule(device["id"], values))


def save_input(device, values, restore=False, preferences=None):
    preferences = preferences or Preferences()
    with lock_file(preferences.path.with_name(".input.lock")):
        live = next((item for item in input_devices(preferences) if item["key"] == device["key"]), None)
        if not live:
            raise SettingsError("This pointing device was disconnected.")
        previous = {key: live[key] for key in INPUT_FIELDS if live[key] is not None}
        if restore:
            settings = defaults().get("input", {})
            values = {**input_baseline(live, settings), **settings.get("devices", {}).get(live["key"], {})}
        values = {key: value for key, value in values.items() if key in previous}
        set_input(live, values)
        try:
            preferences.update_device(live["key"], None if restore else values)
        except (OSError, SettingsError):
            set_input(live, previous)
            raise


def apply_input_preferences(saved):
    rules = [input_rule(name, values) for name, values in saved.items()]
    if rules:
        # Device rules also apply to those devices when they next connect.
        hypr_change("eval", "\n".join(rules))


def input_state():
    return {"devices": input_devices(), "keyboard": keyboard_state()}


def lock_session(suspend=False):
    settings = defaults()
    locker = settings.get("lockCommand")
    if not locker:
        locker = ["workstation-hyprland-lock"] if shutil.which("workstation-hyprland-lock") else ["loginctl", "lock-session"]
    if not isinstance(locker, list) or not all(isinstance(arg, str) and arg for arg in locker):
        raise SettingsError("lockCommand in defaults.json must be a list of command arguments.")
    if not hypr_json("locked")["locked"]:
        try:
            lock = subprocess.Popen(locker, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
        except OSError as error:
            raise SettingsError(f"Could not start the screen locker: {error}") from error
        deadline = time.monotonic() + 6
        while not hypr_json("locked")["locked"]:
            if (lock.poll() is not None and lock.returncode != 0) or time.monotonic() >= deadline:
                raise SettingsError("Hyprland could not confirm the screen lock. Check the locker and its PAM setup.")
            time.sleep(0.1)
    if suspend:
        suspend_command = settings.get("suspendCommand", ["systemctl", "suspend"])
        if not isinstance(suspend_command, list) or not suspend_command or not all(isinstance(arg, str) and arg for arg in suspend_command):
            raise SettingsError("suspendCommand in defaults.json must be a list of command arguments.")
        command(*suspend_command, timeout=30)


def apply_session_preferences(config_reloaded=False, restore_power=False):
    preferences = Preferences()
    with lock_file(preferences.path.with_name(".input.lock")):
        saved = preferences.read()
        try:
            keyboard_defaults(refresh=config_reloaded)
            if "keyboard" in saved:
                set_keyboard(saved["keyboard"])
        except SettingsError as error:
            print(error, file=sys.stderr)
        try:
            apply_input_preferences(saved.get("input_devices", {}))
        except SettingsError as error:
            print(error, file=sys.stderr)
    if restore_power and saved.get("power_mode"):
        try:
            set_power_profile(saved["power_mode"], persist=False)
        except SettingsError as error:
            print(error, file=sys.stderr)


def watch_session():
    root = runtime_root()
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as events:
        events.connect(str(root / ".socket2.sock"))
        apply_session_preferences(restore_power=True)
        pending = b""
        deadline = time.monotonic()
        last_names = None
        forced = True
        reload_input = False
        while True:
            timeout = max(0, deadline - time.monotonic()) if deadline is not None else None
            readable, _, _ = select.select([events], [], [], timeout)
            if readable:
                data = events.recv(65536)
                if not data:
                    return
                *lines, pending = (pending + data).split(b"\n")
                tags = {line.split(b">>", 1)[0] for line in lines}
                if b"configreloaded" in tags:
                    forced = reload_input = True
                if tags & {b"configreloaded", b"monitoraddedv2", b"monitorremovedv2"}:
                    deadline = time.monotonic() + 0.45
            if deadline is not None and deadline <= time.monotonic():
                deadline = None
                try:
                    if reload_input:
                        apply_session_preferences(config_reloaded=True)
                        reload_input = False
                    names = {item["name"] for item in outputs()}
                    if forced or names != last_names:
                        apply_saved_display()
                    last_names, forced = names, False
                except BlockingIOError:
                    deadline = time.monotonic() + 0.5
                except SettingsError as error:
                    print(error, file=sys.stderr)


def shortcut_reference():
    modifiers = ((64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift"), (2, "Caps Lock"),
                 (16, "Mod2"), (32, "Mod3"), (128, "Mod5"))
    result = []
    for binding in hypr_json("binds"):
        key = binding["key"] or (f"Keycode {binding['keycode']}" if binding["keycode"] else "")
        if not key:
            continue
        chord = " + ".join([name for mask, name in modifiers if binding["modmask"] & mask] + [key])
        if binding.get("submap"):
            chord += f" ({binding['submap']})"
        description = binding.get("description") or binding.get("arg") or binding.get("dispatcher")
        if description:
            result.append((chord, description))
    return result
