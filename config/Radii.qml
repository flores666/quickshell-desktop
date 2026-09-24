pragma ComponentBehavior: Bound

import QtQuick
import "root:/services"

/*! Corner radii. */
QtObject {
    id: root

    /*!
        How round the shell is, as a fraction of the tuned scale.

        One control over the whole set rather than a knob per radius: the steps
        below are in proportion to each other — a well's corner sits one step
        inside the panel's — and scaling them together is what keeps that true
        at any roundness.

        Or, when the user has locked the two together, whatever makes the
        panel radius equal Hyprland's window rounding — the same proportions,
        scaled from the windows rather than from the roundness setting, and
        held to the roundness setting's own range.
    */
    readonly property bool followsWindows: Settings.roundnessFollowsWindows
        && CompositorOptions.known("hyprRounding")
    readonly property real scale: root.followsWindows
        ? Math.max(Tuning.spec.roundness.min, Math.min(Tuning.spec.roundness.max,
            CompositorOptions.value("hyprRounding") / root.panelBase * 100)) / 100
        : Tuning.pick("roundness") / 100

    /*! The panel radius at 100% roundness. */
    readonly property int panelBase: 20

    readonly property int xs: Math.round(6 * root.scale)
    readonly property int sm: Math.round(8 * root.scale)
    readonly property int md: Math.round(12 * root.scale)
    readonly property int lg: Math.round(16 * root.scale)
    readonly property int xl: Math.round(20 * root.scale)
    /*! Every panel: bar, dock and each popup's card, so they all agree. */
    readonly property int panel: Math.round(root.panelBase * root.scale)
    /*! A pill: half of whatever it is on, however round everything else is. */
    readonly property int full: 999
}
