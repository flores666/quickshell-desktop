#!/usr/bin/env bash
# Build and install the hyprexpo compositor plugin that provides the overview.
#
# hyprexpo was dropped from the official hyprland-plugins repo as unmaintained,
# so this uses the maintained sandwichfarm fork, pinned to the tag that matches
# the installed Hyprland. Hyprland refuses to load a plugin built against
# different headers, so it has to be rebuilt after every Hyprland update:
# with --if-stale this does nothing unless the plugin is missing or was built
# against another Hyprland, and hyprland.conf runs that at every login.
set -euo pipefail

# Resolved before the cd into the build tree, so `patch` below still points here.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo=https://github.com/sandwichfarm/hyprexpo.git
dest="${XDG_DATA_HOME:-$HOME/.local/share}/hyprexpo"
# The Hyprland the installed plugin was built against, written after each build.
stamp="$dest/built-for"
hypr_version="$(pkg-config --modversion hyprland)"

if [[ "${1:-}" == --if-stale ]]; then
    [[ -e "$dest/hyprexpo.so" && "$(cat "$stamp" 2>/dev/null)" == "$hypr_version" ]] && exit 0
    notify() { notify-send -a Overview "$@" 2>/dev/null || true; }
    # At login the network may still be coming up, and the build clones.
    nm-online -q -t 60 2>/dev/null || true
    if ! "${BASH_SOURCE[0]}"; then
        notify "The overview could not be rebuilt for Hyprland ${hypr_version}" \
            "See journalctl --user -t hyprexpo, or run tools/build-overview-plugin.sh."
        exit 1
    fi
    # Into the running Hyprland, unless one is loaded already or its binary was
    # replaced on disk, which no plugin can load into; the next login does.
    hyprland="$(pidof -s Hyprland || true)"
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -n "$hyprland" ]] \
        && ! hyprctl plugin list | grep -q '^Plugin hyprexpo ' \
        && [[ "$(readlink "/proc/$hyprland/exe")" != *"(deleted)" ]]; then
        hyprctl plugin load "$dest/hyprexpo.so" >/dev/null
    fi
    notify "The overview was rebuilt for Hyprland ${hypr_version}"
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
echo "Hyprland ${hypr_version}"

git clone --quiet "$repo" "$work/src"
cd "$work/src"

# Newest tag whose major.minor matches the installed Hyprland; the tags are
# named after the Hyprland release they track.
series="${hypr_version%.*}"
tag="$(git tag --list "v${series}*" --sort=-v:refname | head -1)"
[[ -n "$tag" ]] || { echo "no hyprexpo tag for Hyprland ${series}" >&2; exit 1; }
echo "building hyprexpo ${tag}"
git checkout --quiet "$tag"

# hyprexpo's wallpaper_bg draws MON->m_background, which is Hyprland's built-in
# wall*.png asset rather than the background layer surface hyprpaper paints, so the
# overview backdrop ends up being a stock wallpaper nobody chose. The patch draws the
# real one instead, blurred. Not upstreamed, so this is the step that breaks when the
# tag moves.
patch="$script_dir/hyprexpo-real-wallpaper-bg.patch"
# Upstream moved its sources under src/ at v0.56.2+2 without touching the code the
# patch edits, so follow the file rather than the path the patch was cut against.
src_dir="$(dirname "$(git ls-files --full-name '*OverviewRender.cpp' | head -1)")"
apply_args=()
[[ "$src_dir" != "." ]] && apply_args=(--directory="$src_dir")
git apply "${apply_args[@]}" "$patch" || { echo "hyprexpo-real-wallpaper-bg.patch no longer applies to ${tag}" >&2; exit 1; }

# A tile is highlighted by a focus zoom rather than by a border: under the
# pointer or the keyboard the tile keeps its size and the workspace in it grows
# within the tile's edge, on a 400 ms ease-out; the current workspace rests
# part of the way there. The dynamic grid also gains a last tile: the next empty
# workspace, shown as the empty workspace it is, to open a new one from. Cut
# against the tree with the patch above applied, and relative to the same
# source directory.
zoom_patch="$script_dir/hyprexpo-tile-zoom-and-add-tile.patch"
git apply "${apply_args[@]}" "$zoom_patch" || { echo "hyprexpo-tile-zoom-and-add-tile.patch no longer applies to ${tag}" >&2; exit 1; }

# The swipe follows the zoom the way the keyboard's animation does: the gaps,
# the outer margin and the focus zoom are read off how far open the overview
# is, not off an animation clock a swipe never starts. And gesture_direction
# only opens it; the opposite swipe closes it. Cut against the tree with both
# patches above applied.
swipe_patch="$script_dir/hyprexpo-swipe-open-close.patch"
git apply "${apply_args[@]}" "$swipe_patch" || { echo "hyprexpo-swipe-open-close.patch no longer applies to ${tag}" >&2; exit 1; }

# The shell stays where it stands: the top and overlay layers -- the bar, the
# dock, their popups -- are left out of every workspace's picture and drawn
# live over the overview instead, taking the pointer and, while one of them
# has it, the keyboard. The grid keeps clear of what the screen's edges
# reserve, and each tile shows the work area alone, cropped to it and of its
# shape. Cut against the tree with the three patches above applied.
shell_patch="$script_dir/hyprexpo-shell-above-overview.patch"
git apply "${apply_args[@]}" "$shell_patch" || { echo "hyprexpo-shell-above-overview.patch no longer applies to ${tag}" >&2; exit 1; }

make all
install -Dm755 hyprexpo.so "$dest/hyprexpo.so"
printf '%s\n' "$hypr_version" > "$stamp"
echo "installed -> $dest/hyprexpo.so"
echo "reload with: hyprctl plugin unload $dest/hyprexpo.so; hyprctl plugin load $dest/hyprexpo.so"
