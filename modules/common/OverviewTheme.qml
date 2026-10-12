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

    /*! Hyprland wants rgba(rrggbbaa). Built from the channels rather than
        from the colour's string, which QML writes as #aarrggbb once there is
        any alpha in it — and the hairline tokens are translucent washes. */
    function rgba(value: color): string {
        const hex = channel => Math.round(channel * 255).toString(16).padStart(2, "0");
        return `rgba(${hex(value.r)}${hex(value.g)}${hex(value.b)}${hex(value.a)})`;
    }

    target: CompositorOptions
    property: "derived"
    value: ({
        "plugin:hyprexpo:bg_col": root.rgba(Appearance.c.base),
        "plugin:hyprexpo:border_color": root.rgba(Appearance.c.borderStrong),
        "plugin:hyprexpo:border_color_focus": root.rgba(Appearance.c.accent),
        "plugin:hyprexpo:border_width": String(Appearance.m.focusRing),
        // A workspace tile is a card like any other, so it takes the one
        // panel radius, which follows the roundness setting or the windows.
        "plugin:hyprexpo:tile_rounding": String(Appearance.r.panel)
    })
}
