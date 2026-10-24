pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*!
    The design system's share of other applications' settings, as
    CompositorTheme is of Hyprland's: while the accent follows the wallpaper,
    GTK's accent — the libadwaita one nearest it — and the terminal's — the
    wallpaper's colour at the lightness of palette.conf's own accents, which
    were tuned to read on the terminal's background. Handed to DesktopAccent,
    which sets them, and puts them back when the accent stops following.
*/
QtObject {
    id: root

    readonly property Binding gtk: Binding {
        target: DesktopAccent
        property: "gtk"
        value: Appearance.followsWallpaper
            ? ColorMath.nearest(Appearance.c.accent, Appearance.gtkAccents) : ""
    }

    readonly property Binding terminal: Binding {
        target: DesktopAccent
        property: "terminal"
        value: Appearance.followsWallpaper && DesktopAccent.palette.accent !== undefined
            ? ({
                accent: Appearance.fromWallpaper(DesktopAccent.palette.accent).toString(),
                accent_bright: Appearance.fromWallpaper(DesktopAccent.palette.accent_bright).toString()
            })
            : null
    }
}
