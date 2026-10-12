pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*!
    Keeps the hyprexpo overview in the shell's colours and shape.

    The overview is drawn by the compositor, so its look lives in Hyprland's
    options rather than in the design system. Rather than let the two drift,
    the options that matter are derived from the tokens here and handed to
    CompositorOptions, which pushes whatever changed and all of them again
    after every config reload — loading the plugin raises one too, so they
    land even when the shell is up before the plugin is.

    Everything else about the overview (grid shape, gestures) is static and
    belongs in hyprland.conf.
*/
Binding {
    id: root

    /*! Hyprland wants rgb(rrggbb), QML gives #rrggbb. */
    function rgb(value: color): string {
        return `rgb(${String(value).replace("#", "").slice(-6)})`;
    }

    target: CompositorOptions
    property: "derived"
    value: ({
        "plugin:hyprexpo:bg_col": root.rgb(Appearance.c.base),
        "plugin:hyprexpo:border_color": root.rgb(Appearance.c.borderStrong),
        "plugin:hyprexpo:border_color_focus": root.rgb(Appearance.c.accent),
        "plugin:hyprexpo:border_width": String(Appearance.m.focusRing),
        // A workspace tile is a card like any other, so it takes the one
        // panel radius, which follows the roundness setting or the windows.
        "plugin:hyprexpo:tile_rounding": String(Appearance.r.panel)
    })
}
