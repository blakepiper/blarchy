"""Hypridle's session worker and the managed screen-off preference."""

import json
import os
import signal
import socket
import subprocess
import time

from core import Preferences, SettingsError, atomic_write, config_home, defaults, lock_file
from hyprland import runtime_root


def default_blank_seconds():
    return defaults().get("display", {}).get("blankAfterSeconds", 0)


def validate_seconds(seconds):
    if type(seconds) is not int or not 0 <= seconds <= 86400:
        raise SettingsError("Choose a screen-off delay between 0 and 1440 minutes.")
    return seconds


def idle_request(request):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as control:
            control.settimeout(4)
            control.connect(str(runtime_root() / ".desktop-idle"))
            control.sendall((json.dumps(request) + "\n").encode())
            with control.makefile("r") as response:
                result = json.loads(response.readline(4096))
    except (OSError, ValueError) as error:
        raise SettingsError("Start the Settings-managed Hypridle worker to edit this timer.") from error
    if "error" in result:
        raise SettingsError(result["error"])
    return result["blank_seconds"]


def blank_state():
    try:
        return {"blank_seconds": idle_request({}), "blank_error": None}
    except SettingsError as error:
        return {"blank_seconds": Preferences().read().get("blank_seconds", default_blank_seconds()),
                "blank_error": str(error)}


def set_blank(seconds, restore=False, preferences=None):
    validate_seconds(seconds)
    preferences = preferences or Preferences()
    with lock_file(preferences.path.with_name(".screen-off.lock")):
        previous = idle_request({})
        idle_request({"blank_seconds": seconds})
        try:
            preferences.update("blank_seconds", None if restore else seconds)
        except (OSError, SettingsError):
            idle_request({"blank_seconds": previous})
            raise


def hypridle_command(seconds):
    source = config_home() / "hypr/hypridle.conf"
    if not source.is_file():
        raise SettingsError(f"Place the Hypridle base configuration at {source}.")
    config = runtime_root() / ".desktop-settings-hypridle.conf"
    text = f"source = {source}\n"
    if seconds:
        text += f"""
listener {{
    timeout = {seconds}
    on-timeout = hyprctl dispatch 'hl.dsp.dpms({{action="off"}})'
    on-resume = hyprctl dispatch 'hl.dsp.dpms({{action="on"}})'
}}
"""
    atomic_write(config, text)
    return ["hypridle", "--config", str(config)]


def stop_child(child):
    if child and child.poll() is None:
        child.terminate()
        try:
            child.wait(timeout=1)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()


def run_idle():
    root = runtime_root()
    path = root / ".desktop-idle"
    child = None
    stopping = False

    def stop(*_):
        nonlocal stopping
        stopping = True

    def start(seconds):
        nonlocal child
        args = hypridle_command(seconds)
        stop_child(child)
        child = subprocess.Popen(args)
        time.sleep(0.15)
        if child.poll() is not None:
            raise SettingsError("Hypridle exited. Check its configuration and session logs.")

    def handle(client):
        nonlocal seconds
        try:
            client.settimeout(1)
            with client.makefile("r") as stream:
                request = json.loads(stream.readline(1024))
            if not isinstance(request, dict):
                raise SettingsError("The screen timer request is invalid.")
            proposed = validate_seconds(request.get("blank_seconds", seconds))
            if proposed != seconds:
                try:
                    start(proposed)
                except (SettingsError, OSError):
                    start(seconds)
                    raise
                seconds = proposed
            result = {"blank_seconds": seconds}
        except (OSError, ValueError, SettingsError) as error:
            result = {"error": str(error)}
        try:
            client.sendall((json.dumps(result) + "\n").encode())
        except OSError:
            pass

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    # An alternative session backend must not start a second Hypridle instance.
    try:
        with lock_file(root / ".desktop-settings-idle.lock", blocking=False):
            seconds = validate_seconds(Preferences().read().get("blank_seconds", default_blank_seconds()))
            path.unlink(missing_ok=True)
            try:
                start(seconds)
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as control:
                    control.bind(str(path))
                    path.chmod(0o600)
                    control.listen()
                    control.settimeout(0.5)
                    while not stopping and child.poll() is None:
                        try:
                            client, _ = control.accept()
                        except TimeoutError:
                            continue
                        with client:
                            handle(client)
                if not stopping:
                    raise SettingsError("Hypridle exited. Check the session logs.")
            finally:
                stop_child(child)
                path.unlink(missing_ok=True)
    except BlockingIOError as error:
        raise SettingsError("A Settings-managed Hypridle worker is already running.") from error
