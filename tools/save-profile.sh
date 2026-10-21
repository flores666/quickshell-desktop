#!/usr/bin/env bash
# Save into profile/ what this machine has set up that is not a file in the
# project, so that install.sh can give it to the next one: the shell's
# preferences, and the GTK and file-manager settings. Not the wallpapers: the
# pictures stay out of the repository, and the choice among them is saved by
# name, so it comes back on a machine whose folder has a picture of that name.
#
# The configs themselves need no saving: install.sh links them to the project,
# so an edit to one already lands here. Commit profile/ afterwards.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
profile="$repo/profile"

# Where Qt finds the Pictures folder, which is what Wallpaper.folder is under.
pictures="$(xdg-user-dir PICTURES 2>/dev/null || true)"
[[ -n "$pictures" && "$pictures" != "$HOME" ]] || pictures="$HOME/Pictures"
wallpapers="$pictures/Wallpapers"

# The running shell knows which state directory is its own.
id="$(qs list -c shell 2>/dev/null | awk '/Shell ID:/ { print $3; exit }')"
[[ -n "$id" ]] || { echo "the shell is not running; start it and run this again" >&2; exit 1; }
settings="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/by-shell/$id/settings.json"

mkdir -p "$profile"

# systemFontBefore is this machine's GTK font from before the shell set its
# own, which only means something here; so do vpnConnections, the names of
# this machine's NetworkManager profiles. A wallpaper in the folder is saved by
# its name alone, which Wallpaper.current finds in the next machine's folder.
# The dock keeps only the applications the project installs: a pin or a place
# for any other is this user's own, and the dock on the next machine would
# have nothing to launch for it.
python3 - "$settings" "$profile/settings.json" "$wallpapers" "$repo" <<'EOF'
import json, os, subprocess, sys
source, target, folder, repo = sys.argv[1:]
with open(source) as f:
    settings = json.load(f)
settings["systemFontBefore"] = ""
settings["vpnConnections"] = []

packages = set()
for name in ("packages.txt", "packages-aur.txt"):
    with open(os.path.join(repo, name)) as f:
        packages.update(l.strip() for l in f if l.strip() and not l.lstrip().startswith("#"))
data_dirs = (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
def installed_by_project(app):
    for d in data_dirs:
        path = os.path.join(d, "applications", app + ".desktop")
        if os.path.exists(path):
            owner = subprocess.run(["pacman", "-Qqo", path], capture_output=True, text=True).stdout.strip()
            return owner in packages
    return False
for key in ("pinnedApps", "dockOrder"):
    settings[key] = [app for app in settings.get(key, []) if installed_by_project(app)]
if os.path.dirname(settings.get("wallpaper", "")) == folder:
    settings["wallpaper"] = os.path.basename(settings["wallpaper"])
with open(target, "w") as f:
    json.dump(settings, f, indent=4, ensure_ascii=False)
    f.write("\n")
EOF
echo "saved the shell's preferences"

# Only the looks of GTK and nautilus: dconf also holds window sizes, Wi-Fi
# credentials and proxies, none of which belongs in a repository.
gtk=(
    org/gnome/desktop/interface
    org/gnome/desktop/wm/preferences
    org/gnome/nautilus/preferences
    org/gnome/nautilus/icon-view
    com/github/stunkymonkey/nautilus-open-any-terminal
)
for dir in "${gtk[@]}"; do
    printf '[%s]\n' "$dir"
    # The keys of the directory itself, not of the ones below it.
    dconf dump "/$dir/" | awk 'NR > 1 && /^\[/ { exit } NR > 1 && NF'
done > "$profile/gtk.dconf"
echo "saved the GTK settings"
