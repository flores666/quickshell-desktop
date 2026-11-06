#!/usr/bin/env bash
# Install Conflux from a pinned upstream without vendoring the artwork.
# Stage the complete theme, then publish it in XDG_DATA_HOME. A re-run of
# the same revision is silent.
set -euo pipefail

revision=c175e0e550c8970fe9cb8484afe44188a8ea589f
source_url=https://github.com/MoshiurRahmanAdib/Conflux-Icon-Theme.git
icons="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
theme=Conflux
mkdir -p "$icons"
# Concurrent installers must not replace one another's completed themes.
exec {theme_lock}>"$icons/.quickshell-conflux.lock"
flock "$theme_lock"

# The upstream keeps authoring shortcuts beside its SVGs. Workspace is not
# installed, so those shortcuts have no runtime use and would dangle.
remove_authoring_links() {
    local directory path
    for directory in apps devices mimes places preferences; do
        path="$1/$directory/scalable/optimize.sh"
        if [[ -L "$path" ]]; then rm -- "$path"; fi
    done
}

if [[ -f "$icons/$theme/index.theme" \
    && "$(cat "$icons/$theme/.quickshell-source" 2>/dev/null || true)" == "$revision" ]]; then
    remove_authoring_links "$icons/$theme"
    exit 0
fi

# Stage on the destination filesystem so publication is an atomic rename.
work="$(mktemp -d "$icons/.conflux-stage.XXXXXX")"
backup=""
cleanup() {
    # Restore an existing theme if publication was interrupted after moving it.
    if [[ -n "$backup" && ! -e "$icons/$theme" && ! -L "$icons/$theme" \
        && ( -e "$backup/$theme" || -L "$backup/$theme" ) ]]; then
        mv -- "$backup/$theme" "$icons/$theme"
    fi
    rm -rf -- "$work"
}
trap cleanup EXIT
git init --quiet "$work/source"
git -C "$work/source" fetch --quiet --depth 1 "$source_url" "$revision"
git -C "$work/source" checkout --quiet --detach FETCH_HEAD
# Publish runtime artwork, symlinks, license and credits. Upstream's Workspace
# and preview images are authoring assets, and make GTK's cache invalid.
mkdir "$work/$theme"
for entry in index.theme LICENSE CREDITS.md apps apps@2x devices devices@2x \
    emblems emblems@2x mimes mimes@2x places places@2x preferences preferences@2x \
    status status@2x; do
    cp -a -- "$work/source/$entry" "$work/$theme/"
done
remove_authoring_links "$work/$theme"
gtk-update-icon-cache --force --quiet "$work/$theme"
printf '%s\n' "$revision" > "$work/$theme/.quickshell-source"
if [[ -e "$icons/$theme" || -L "$icons/$theme" ]]; then
    backup="$(mktemp -d "$icons/Conflux-backup.XXXXXX")"
    mv -- "$icons/$theme" "$backup/$theme"
    printf 'kept your %s as %s\n' "$icons/$theme" "$backup/$theme"
fi
mv -- "$work/$theme" "$icons/$theme"
printf 'installed %s\n' "$icons/$theme"
