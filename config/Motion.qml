pragma ComponentBehavior: Bound

import QtQuick

/*!
    Animation durations and curves.

    Unhurried, and eased at both ends where nothing has to feel immediate: a
    short animation on a curve that leaves at full speed reads as a jump with
    a tail, which is what the shell's motion used to look like. Every animation
    names one of the curves below — QML's own default is linear, which starts
    and stops dead.
*/
QtObject {
    /*! Hover and press washes: quick enough to follow the pointer. */
    readonly property int instant: 120
    /*! Fades and colour changes. */
    readonly property int fast: 180
    /*! Things moving: a slide, a pill stretching, a knob crossing a switch. */
    readonly property int base: 260
    /*! A whole popup changing size — a bigger move than any control makes. */
    readonly property int resize: 320

    /*! How long the pointer rests on something before more of it shows: a
        tooltip, the dock's preview of an application's windows. */
    readonly property int dwell: 450
    /*! How long the dock's preview stays once the pointer has left it and the
        icons, so a path that strays off them for a moment does not close it. */
    readonly property int linger: 250

    /*! Fades and colour: gentle at both ends, so nothing pops on or off. */
    readonly property int standardEasing: Easing.InOutQuad
    /*! Movement: leaves briskly and settles slowly, without the near-instant
        launch a quintic gives. */
    readonly property int emphasizedEasing: Easing.OutCubic
    /*! For a container changing size: even at both ends, so the edge does not
        appear to leap and then crawl the way an out-curve makes it. */
    readonly property int resizeEasing: Easing.InOutCubic
}
