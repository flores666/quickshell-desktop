#!/usr/bin/env bash
# Build and install the shell's native QML module from native/: the little the
# shell needs that QML cannot do, which is to have Qt read the icon themes
# again when an install changes them (services/IconThemes.qml).
#
# The unit finds it through QML_IMPORT_PATH (hyprland.conf). Qt loads a plugin
# built against its own version or an older one: with --if-stale this does
# nothing unless the module is missing or was built against another Qt or from
# other sources, and hyprland.conf runs that at every login. A running shell
# keeps the module it loaded; the rebuilt one is taken when it next starts.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../native" && pwd)"
dest="${XDG_DATA_HOME:-$HOME/.local/share}/quickshell-desktop/qml/Desktop/Native"
# What the installed module was built from: the Qt and the sources.
stamp="$dest/built-for"
qt_version="$(pkg-config --modversion Qt6Qml)"
built_for="$qt_version $(cat "$src"/CMakeLists.txt "$src"/*.cpp "$src"/*.hpp | sha256sum | cut -d' ' -f1)"

if [[ "${1:-}" == --if-stale ]]; then
    [[ -e "$dest/libdesktopnative.so" && "$(cat "$stamp" 2>/dev/null)" == "$built_for" ]] && exit 0
    if ! "${BASH_SOURCE[0]}"; then
        notify-send -a Shell "The shell's native module could not be rebuilt for Qt ${qt_version}" \
            "See journalctl --user -t quickshell-native, or run tools/build-native-module.sh." \
            2>/dev/null || true
        exit 1
    fi
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
echo "building the shell's native module for Qt ${qt_version}"

cmake -S "$src" -B "$work" -DCMAKE_BUILD_TYPE=Release --log-level=WARNING >/dev/null
cmake --build "$work" -j >/dev/null
# New files rather than ones written over: a running shell that has the old
# plugin loaded keeps its own copy.
built="$work/qml/Desktop/Native"
install -Dm755 "$built/libdesktopnative.so" "$dest/libdesktopnative.so"
install -Dm644 -t "$dest" "$built/qmldir" "$built/desktopnative.qmltypes"
printf '%s\n' "$built_for" > "$stamp"
echo "installed -> $dest"
