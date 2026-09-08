pragma ComponentBehavior: Bound

import QtQuick

/*! Type scale, in device-independent pixels. */
QtObject {
    id: root

    /*!
        The whole scale, as a fraction of the tuned sizes.

        One control over the set rather than a knob per role, for the same
        reason roundness is one number: the sizes below stand in proportion to
        each other — a caption is a caption because a title is bigger — and
        scaling them together is what keeps that true at any text size.
    */
    readonly property real scale: Tuning.pick("fontScale") / 100

    readonly property int caption: Math.round(11 * root.scale)
    readonly property int small: Math.round(12 * root.scale)
    readonly property int body: Math.round(13 * root.scale)
    readonly property int subtitle: Math.round(15 * root.scale)
    readonly property int title: Math.round(19 * root.scale)
    readonly property int display: Math.round(34 * root.scale)
    readonly property int clock: Math.round(44 * root.scale)
}
