#!/usr/bin/env python3
"""Generate components/Icons.qml from the Adwaita symbolic icon theme.

Adwaita symbolic icons are single-colour 16x16 SVGs made of one or more <path>
fill elements.  We lift the raw path data out so the shell can draw them with
QtQuick.Shapes in any colour, at any size, with no runtime SVG or image-effect
cost.
"""
import re, sys, os, xml.etree.ElementTree as ET

THEME = "/usr/share/icons/Adwaita/symbolic"
OUT = os.path.join(os.path.dirname(__file__), "..", "components", "Icons.qml")
SVG = "{http://www.w3.org/2000/svg}"
MAX_LAYERS = 3

# key -> adwaita icon name (without -symbolic.svg)
ICONS = {
    # network
    "wifi-none": "network-wireless-signal-none",
    "wifi-weak": "network-wireless-signal-weak",
    "wifi-ok": "network-wireless-signal-ok",
    "wifi-good": "network-wireless-signal-good",
    "wifi-excellent": "network-wireless-signal-excellent",
    "wifi-off": "network-wireless-disabled",
    "wifi-acquiring": "network-wireless-acquiring",
    "wifi-locked": "network-wireless-encrypted",
    "wifi-hotspot": "network-wireless-hotspot",
    "ethernet": "network-wired",
    "ethernet-off": "network-wired-disconnected",
    "network-offline": "network-offline",
    "network-error": "network-error",
    "network-limited": "network-no-route",
    "vpn": "network-vpn",
    # audio
    "volume-muted": "audio-volume-muted",
    "volume-low": "audio-volume-low",
    "volume-medium": "audio-volume-medium",
    "volume-high": "audio-volume-high",
    "volume-over": "audio-volume-overamplified",
    "speakers": "audio-speakers",
    "headphones": "audio-headphones",
    "headset": "audio-headset",
    "audio-card": "audio-card",
    "mic": "audio-input-microphone",
    "mic-muted": "microphone-sensitivity-muted",
    # bluetooth
    "bluetooth": "bluetooth-active",
    "bluetooth-off": "bluetooth-disabled",
    "bluetooth-disconnected": "bluetooth-disconnected",
    "bluetooth-acquiring": "bluetooth-acquiring",
    # power
    "battery-missing": "battery-missing",
    "ac-adapter": "ac-adapter",
    "power-saver": "power-profile-power-saver",
    "power-balanced": "power-profile-balanced",
    "power-performance": "power-profile-performance",
    "brightness": "display-brightness",
    # session
    "lock": "system-lock-screen",
    "logout": "system-log-out",
    "reboot": "system-reboot",
    "shutdown": "system-shutdown",
    "suspend": "weather-clear-night",
    # ui / chrome
    "chevron-down": "pan-down",
    "chevron-up": "pan-up",
    "chevron-left": "pan-start",
    "chevron-right": "pan-end",
    "close": "window-close",
    "check": "object-select",
    "search": "system-search",
    "apps": "view-app-grid",
    "menu": "open-menu",
    "more": "view-more",
    "refresh": "view-refresh",
    "add": "list-add",
    "remove": "list-remove",
    "clear": "edit-clear",
    "trash": "user-trash-full",
    "settings": "system-run",
    "pin": "view-pin",
    "reveal": "view-reveal",
    "conceal": "view-conceal",
    "fullscreen": "view-fullscreen",
    "grid": "view-grid",
    "back": "go-previous",
    "forward": "go-next",
    # media
    "play": "media-playback-start",
    "pause": "media-playback-pause",
    "prev": "media-skip-backward",
    "next": "media-skip-forward",
    "shuffle": "media-playlist-shuffle",
    "repeat": "media-playlist-repeat",
    "repeat-one": "media-playlist-repeat-song",
    "music": "multimedia-player",
    # status
    "dnd": "notifications-disabled",
    "bell": "preferences-system-notifications",
    "info": "dialog-information",
    "warning": "dialog-warning",
    "error": "dialog-error",
    "night-light": "night-light",
    "calendar": "x-office-calendar",
    "loading": "content-loading",
    "password": "dialog-password",
    "user": "avatar-default",
    # devices
    "computer": "computer",
    "display": "video-display",
    "keyboard": "input-keyboard",
    "mouse": "input-mouse",
    "gamepad": "input-gaming",
    "phone": "phone",
    "printer": "printer",
    "window": "window-new",
}

# battery levels are generated programmatically
for lvl in (0, 10, 20, 30, 40, 50, 60, 70, 80, 90):
    ICONS[f"battery-{lvl}"] = f"battery-level-{lvl}"
    ICONS[f"battery-{lvl}-charging"] = f"battery-level-{lvl}-charging"
ICONS["battery-100"] = "battery-level-100"
ICONS["battery-100-charging"] = "battery-level-100-charged"


def find(name):
    for sub in ("status", "ui", "actions", "devices", "categories", "places",
                "emotes", "mimetypes", "legacy"):
        p = os.path.join(THEME, sub, f"{name}-symbolic.svg")
        if os.path.exists(p):
            return p
    return None


def extract(path):
    """-> (viewBox size, [(d, opacity)])"""
    root = ET.parse(path).getroot()
    vb = root.get("viewBox", "0 0 16 16").split()
    size = float(vb[2]) if len(vb) == 4 else 16.0
    out = []
    for el in root.iter(f"{SVG}path"):
        d = el.get("d")
        if not d:
            continue
        op = el.get("fill-opacity")
        style = el.get("style") or ""
        m = re.search(r"fill-opacity:\s*([0-9.]+)", style)
        if m:
            op = m.group(1)
        out.append((" ".join(d.split()), float(op) if op else 1.0))
    return size, out


def absolute_start(d):
    """Make a path's opening moveto absolute.

    A standalone path's leading lowercase `m` is already interpreted as
    absolute, but once the path is concatenated after another one it becomes
    relative to that path's final point. Upper-casing it keeps the merged path
    identical to the separate ones.
    """
    d = d.lstrip()
    return "M" + d[1:] if d[:1] == "m" else d


def main():
    missing, entries = [], []
    for key in sorted(ICONS):
        p = find(ICONS[key])
        if not p:
            missing.append(f"{key} -> {ICONS[key]}")
            continue
        size, paths = extract(p)
        if not paths:
            missing.append(f"{key} (no path data)")
            continue
        # Merge subpaths that share an opacity into one path element: Adwaita
        # icons are disjoint shapes, so a single nonzero-fill path renders
        # identically while keeping the QML delegate count fixed and small.
        merged = {}
        for d, o in paths:
            merged.setdefault(o, []).append(absolute_start(d))
        groups = [(" ".join(v), k) for k, v in merged.items()]
        groups.sort(key=lambda g: -g[1])
        if len(groups) > MAX_LAYERS:
            missing.append(f"{key} has {len(groups)} opacity layers")
        body = ", ".join(
            '{ "d": "%s", "o": %g }' % (d.replace("\\", "\\\\").replace('"', '\\"'), o)
            for d, o in groups)
        entries.append('        "%s": { "size": %g, "paths": [%s] }' % (key, size, body))

    if missing:
        print("MISSING:\n  " + "\n  ".join(missing), file=sys.stderr)

    with open(OUT, "w") as f:
        f.write("pragma Singleton\n\n")
        f.write("import QtQuick\n\n")
        f.write("// GENERATED by tools/genicons.py from the Adwaita symbolic icon\n")
        f.write("// theme. Do not edit by hand; re-run the script instead.\n")
        f.write("QtObject {\n")
        f.write("    readonly property var glyphs: ({\n")
        f.write(",\n".join(entries))
        f.write("\n    })\n\n")
        f.write("    function has(name: string): bool { return name in glyphs; }\n")
        f.write("}\n")
    print(f"wrote {len(entries)} icons -> {os.path.normpath(OUT)}")


main()
