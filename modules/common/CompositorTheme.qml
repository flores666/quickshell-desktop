pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*!
    The design system's share of Hyprland's options: the hyprexpo overview's
    colours and shape, the title bars' colours and timings, and the shadow
    under every window.

    All are drawn by the compositor, so their look lives in Hyprland's options
    rather than in the design system. Rather than let the two drift, the options
    that matter are derived from the tokens here and handed to
    CompositorOptions, which pushes whatever changed and all of them again
    after every config reload — loading a plugin raises one too, so they
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

    /*!
        The windows' shadow: the nearest Hyprland draws to Appearance.windowShadow.

        Hyprland's shadow is solid over the window's box moved by its offset,
        and fades out over `range` as ((range − d) / range)^power. Dropped as
        far as the token's, that solid part shows under the window as a slab
        with a hard lower edge, nothing like the popups' falloff: measured at
        the 22px a value fit asks for, and still plain at 12. So the drop is
        held to what passes for the window's own rim, and the rest is fitted
        to both of the token's layers below, above and beside a window: power
        4, a range of 1.7 × the blur and ¾ of the alpha — 0.30 and 76 for
        25/45/0.40. It falls short below a window and shows a little above.
    */
    readonly property int drop: 6
    readonly property var shadow: Appearance.windowShadow[0]
    readonly property var windowShadow: ({
        "decoration:shadow:range": String(Math.round(1.7 * root.shadow.blur)),
        "decoration:shadow:render_power": "4",
        "decoration:shadow:offset": `0 ${Math.min(root.drop, root.shadow.y)}`,
        "decoration:shadow:color": root.rgba(Qt.alpha(Appearance.c.shadow, 0.75 * root.shadow.alpha))
    })

    /*!
        The title bars (hypr/windows). A bar takes its application's colour
        where the plugin can tell it, and the system's surface otherwise; what
        is drawn on it is the scheme of the same lightness, the day theme's on
        a light bar and the night theme's on a dark one, whichever theme is up.
        Its buttons are the system's danger, warning, success and accent, their
        glyphs cut out in the scheme's surface. Its washes, fades and linger
        are the shell's own, on the shell's curve, and a tiled or fullscreen
        window's bar comes out after `reveal`.

        A function, not a property of this Binding: as one it was read by
        `value` before it had been evaluated, and every load logged a binding
        loop on `value`.
    */
    function titleBars(): var {
        const ink = (prefix, scheme) => ({
            [`plugin:windows:${prefix}_text`]: root.rgba(scheme.text),
            [`plugin:windows:${prefix}_glyph`]: root.rgba(scheme.surface),
            [`plugin:windows:${prefix}_close`]: root.rgba(scheme.danger),
            [`plugin:windows:${prefix}_minimize`]: root.rgba(scheme.warning),
            [`plugin:windows:${prefix}_zoom`]: root.rgba(scheme.success),
            [`plugin:windows:${prefix}_layout`]: root.rgba(scheme.accent)
        });
        return Object.assign({
            // A title bar is part of its window, not floating chrome: opaque.
            "plugin:windows:bar_color": root.rgba(Appearance.c.surface),
            "plugin:windows:hover_duration": String(Appearance.t.instant),
            "plugin:windows:fade_duration": String(Appearance.t.fast),
            "plugin:windows:dwell": String(Appearance.t.reveal),
            "plugin:windows:linger": String(Appearance.t.linger),
            "plugin:windows:curve": Appearance.t.standardCurve.join(" ")
        }, ink("light", Appearance.day), ink("dark", Appearance.night));
    }

    target: CompositorOptions
    property: "derived"
    value: Object.assign({
        "plugin:hyprexpo:bg_col": root.rgba(Appearance.c.base),
        // No tile is outlined: the patched plugin marks the one under the
        // pointer by zooming into it. The focus colour still outlines a window
        // being dragged between tiles.
        "plugin:hyprexpo:border_color": root.rgba(Appearance.c.borderStrong),
        "plugin:hyprexpo:border_color_focus": root.rgba(Appearance.c.accent),
        "plugin:hyprexpo:border_width": "0",
        // A workspace tile is a card like any other, so it takes the one
        // panel radius, which follows the roundness setting or the windows.
        "plugin:hyprexpo:tile_rounding": String(Appearance.r.panel)
    }, root.titleBars(), root.windowShadow)
}
