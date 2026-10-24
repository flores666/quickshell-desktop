# kitty's colours, from palette.conf beside this file, and the lines of this
# machine's state file over it (the shell's accent, while it follows the
# wallpaper: services/DesktopAccent.qml). kitty.conf runs this through
# geninclude, at every start and reload, and includes what it prints.

import os

here = os.path.dirname(os.path.realpath(__file__))
state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
palette = {}
for path in (os.path.join(here, "palette.conf"), os.path.join(state, "quickshell-desktop", "palette.conf")):
    try:
        with open(path) as f:
            for line in f:
                words = line.split()
                if len(words) == 2 and not words[0].startswith("#"):
                    palette[words[0]] = words[1]
    except FileNotFoundError:
        pass

roles = {
    "foreground": "fg",
    "background": "bg",
    "selection_foreground": "bright",
    "selection_background": "selection",
    "cursor": "fg",
    "cursor_text_color": "bg",
    "url_color": "accent",
    "active_border_color": "selection",
    "inactive_border_color": "surface",
    "bell_border_color": "yellow",
    "tab_bar_background": "bg",
    "active_tab_foreground": "bright",
    "active_tab_background": "selection",
    "inactive_tab_foreground": "dim",
    "inactive_tab_background": "surface",
}
# black, red, green, yellow, blue, magenta, cyan, white; then the bright ones
ansi = [
    "surface", "red", "green", "yellow", "accent", "magenta", "cyan", "fg",
    "muted", "red_bright", "green_bright", "yellow_bright", "accent_bright",
    "magenta_bright", "cyan_bright", "bright",
]

for option, name in roles.items():
    print(option, palette[name])
for index, name in enumerate(ansi):
    print(f"color{index}", palette[name])
