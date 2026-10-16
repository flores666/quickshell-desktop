#!/usr/bin/env bash
# Save into profile/ what this machine has set up that is not a file in the
# project, so that install.sh can give it to the next one: the shell's
# preferences, the GTK and file-manager settings, and the wallpapers.
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
# own, which only means something here. A wallpaper in the folder is saved by
# its name alone, which Wallpaper.current finds in the next machine's folder.
python3 - "$settings" "$profile/settings.json" "$wallpapers" <<'EOF'
import json, os, sys
source, target, folder = sys.argv[1:]
with open(source) as f:
    settings = json.load(f)
settings["systemFontBefore"] = ""
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

# A mirror of the folder, so a picture deleted here goes from the profile too.
rm -rf "$profile/wallpapers"
mkdir -p "$profile/wallpapers"
shopt -s nullglob nocaseglob
for picture in "$wallpapers"/*.{jpg,jpeg,png,webp,bmp}; do
    cp -- "$picture" "$profile/wallpapers/"
done
echo "saved $(ls "$profile/wallpapers" | wc -l) wallpapers"
