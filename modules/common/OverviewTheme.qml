pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"

/*!
    Keeps the hyprexpo overview in the shell's colours.

    The overview is drawn by the compositor, so its palette lives in Hyprland's
    config rather than in the design system. Rather than let the two drift, the
    shell pushes the three colours that matter whenever the theme or the user's
    accent changes — a handful of times a day, not on a timer.

    Everything else about the overview (grid shape, gestures) is static and
    belongs in hyprland.conf.
*/
QtObject {
    id: root

    readonly property color background: Appearance.c.base
    readonly property color accent: Appearance.c.accent
    readonly property color border: Appearance.c.borderStrong

    /*! Hyprland wants rrggbb, QML gives #rrggbb. */
    function rgb(value: color): string {
        return `rgb(${String(value).replace("#", "").slice(-6)})`;
    }

    readonly property Process push: Process {
        command: ["hyprctl", "--batch",
            `keyword plugin:hyprexpo:bg_col ${root.rgb(root.background)}`
            + ` ; keyword plugin:hyprexpo:border_color_focus ${root.rgb(root.accent)}`
            + ` ; keyword plugin:hyprexpo:border_color ${root.rgb(root.border)}`]
    }

    readonly property Timer apply: Timer {
        // Coalesces the three colour changes a theme switch produces into one
        // call, and waits for the plugin to be up at login.
        interval: 400
        running: true
        onTriggered: root.push.running = true
    }

    onBackgroundChanged: root.apply.restart()
    onAccentChanged: root.apply.restart()
    onBorderChanged: root.apply.restart()
}
