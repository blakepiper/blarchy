"""Desktop Settings and its runtime actions."""

import argparse
import json
import sys

from core import SettingsError, command, nightlight_settings, power_profile_state, set_power_profile


PAGES = ("display", "audio", "network", "bluetooth", "power", "input", "shortcuts", "about")


def run_action(args):
    from hyprland import apply_hyprland_nightlight, apply_saved_display, apply_session_preferences, preview_display, set_nightlight, watch_session
    from idle import run_idle

    if args.action == "display-preview":
        preview_display(json.loads(sys.stdin.readline()))
    elif args.action == "display-hotplug":
        apply_saved_display()
    elif args.action == "apply-session":
        apply_session_preferences(restore_power=True)
        apply_saved_display()
    elif args.action == "watch-session":
        watch_session()
    elif args.action == "idle":
        run_idle()
    elif args.action == "apply-hyprland-nightlight":
        apply_hyprland_nightlight()
    elif args.action == "nightlight-level":
        value = nightlight_settings()
        if args.intensity is None:
            print(value["intensity"] if value["enabled"] else 0)
        else:
            intensity = args.intensity if args.intensity else value["intensity"] or 50
            set_nightlight(args.intensity > 0, intensity)
    elif args.action == "power-mode":
        if args.profile:
            set_power_profile(args.profile)
        else:
            print(power_profile_state().get("active", ""))
    elif args.action == "power-profiles":
        print(json.dumps(power_profile_state()))


def main():
    runtime = "--runtime" in sys.argv[1:]
    parser = argparse.ArgumentParser(prog="desktop-settings-apply" if runtime else "desktop-settings",
                                     description="Desktop Settings" + (" runtime actions" if runtime else " for Hyprland"))
    parser.add_argument("--runtime", action="store_true", help=argparse.SUPPRESS)
    if runtime:
        actions = parser.add_subparsers(dest="action", required=True)
        for action in ("display-preview", "display-hotplug", "apply-session", "watch-session", "idle",
                       "apply-hyprland-nightlight", "power-profiles"):
            actions.add_parser(action)
        power = actions.add_parser("power-mode")
        power.add_argument("profile", nargs="?", choices=("performance", "balanced", "power-saver"))
        night = actions.add_parser("nightlight-level")
        night.add_argument("--intensity", type=int, help="Night light warmth from 0 (off) to 100")
    else:
        parser.add_argument("--demo", action="store_true", help="Use simulated devices and in-memory preferences")
        parser.add_argument("--page", choices=PAGES)
    args = parser.parse_args()
    try:
        if runtime:
            run_action(args)
            return 0
        from gi.repository import GLib
        GLib.set_prgname("org.local.DesktopSettings")
        from ui import Application
        return Application(demo=args.demo).run([sys.argv[0]] + ([args.page] if args.page else []))
    except (SettingsError, ValueError, OSError, ImportError) as error:
        print(error, file=sys.stderr)
        notify = runtime and (args.action == "power-mode" and args.profile
                              or args.action == "nightlight-level" and args.intensity is not None)
        if notify:
            try:
                command("notify-send", "--urgency=critical", "Setting could not be changed", str(error))
            except SettingsError:
                pass
        return 1


if __name__ == "__main__":
    sys.exit(main())
