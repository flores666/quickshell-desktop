#!/usr/bin/env bash
# Build and install the hyprexpo compositor plugin that provides the overview.
#
# hyprexpo was dropped from the official hyprland-plugins repo as unmaintained,
# so this uses the maintained sandwichfarm fork, pinned to the tag that matches
# the installed Hyprland. Hyprland refuses to load a plugin built against
# different headers, so this must be re-run after every Hyprland update.
set -euo pipefail

repo=https://github.com/sandwichfarm/hyprexpo.git
dest="${XDG_DATA_HOME:-$HOME/.local/share}/hyprexpo"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

hypr_version="$(pkg-config --modversion hyprland)"
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

make all
install -Dm755 hyprexpo.so "$dest/hyprexpo.so"
echo "installed -> $dest/hyprexpo.so"
echo "reload with: hyprctl plugin unload $dest/hyprexpo.so; hyprctl plugin load $dest/hyprexpo.so"
