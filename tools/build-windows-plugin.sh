#!/usr/bin/env bash
# Build and install the desktop's window plugin from hypr/windows: the title
# bars, and windows that open floating where they were left.
#
# Hyprland refuses to load a plugin built against different headers, so it has
# to be rebuilt after every Hyprland update: with --if-stale this does nothing
# unless the plugin is missing or was built against another Hyprland or other
# sources, and hyprland.conf runs that at every login.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../hypr/windows" && pwd)"
dest="${XDG_DATA_HOME:-$HOME/.local/share}/hypr-windows"
# What the installed plugin was built from: the Hyprland and the sources.
stamp="$dest/built-for"
hypr_version="$(pkg-config --modversion hyprland)"
built_for="$hypr_version $(cat "$src"/*.cpp "$src"/*.hpp | sha256sum | cut -d' ' -f1)"

if [[ "${1:-}" == --if-stale ]]; then
    [[ -e "$dest/windows.so" && "$(cat "$stamp" 2>/dev/null)" == "$built_for" ]] && exit 0
    notify() { notify-send -a Windows "$@" 2>/dev/null || true; }
    if ! "${BASH_SOURCE[0]}"; then
        notify "The window plugin could not be rebuilt for Hyprland ${hypr_version}" \
            "See journalctl --user -t hypr-windows, or run tools/build-windows-plugin.sh."
        exit 1
    fi
    # Into the running Hyprland, unless one is loaded already (built from older
    # sources) or its binary was replaced on disk, which no plugin can load
    # into; the next login does.
    hyprland="$(pidof -s Hyprland || true)"
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -n "$hyprland" ]] \
        && ! hyprctl plugin list | grep -q '^Plugin windows ' \
        && [[ "$(readlink "/proc/$hyprland/exe")" != *"(deleted)" ]]; then
        hyprctl plugin load "$dest/windows.so" >/dev/null
        notify "The window plugin was rebuilt for Hyprland ${hypr_version}"
    else
        notify "The window plugin was rebuilt for Hyprland ${hypr_version}" \
            "It takes effect at the next login."
    fi
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
echo "building the window plugin for Hyprland ${hypr_version}"

# shellcheck disable=SC2046 # pkg-config's flags are meant to split
g++ -shared -fPIC -O2 -std=c++2b --no-gnu-unique -Wall \
    $(pkg-config --cflags pixman-1 libdrm hyprland libinput libudev wayland-server xkbcommon) \
    "$src"/*.cpp -o "$work/windows.so"
# A new file rather than one written over: a running Hyprland that has the old
# one loaded keeps its own copy (see AGENTS.md).
install -Dm755 "$work/windows.so" "$dest/windows.so"
printf '%s\n' "$built_for" > "$stamp"
echo "installed -> $dest/windows.so"
