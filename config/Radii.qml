pragma ComponentBehavior: Bound

import QtQuick

/*! Corner radii. */
QtObject {
    id: root

    /*!
        How round the shell is, as a fraction of the tuned scale.

        One control over the whole set rather than a knob per radius: the steps
        below are in proportion to each other — a well's corner sits one step
        inside the panel's — and scaling them together is what keeps that true
        at any roundness.
    */
    readonly property real scale: Tuning.pick("roundness") / 100

    readonly property int xs: Math.round(6 * root.scale)
    readonly property int sm: Math.round(8 * root.scale)
    readonly property int md: Math.round(12 * root.scale)
    readonly property int lg: Math.round(16 * root.scale)
    readonly property int xl: Math.round(20 * root.scale)
    /*! A pill: half of whatever it is on, however round everything else is. */
    readonly property int full: 999
}
