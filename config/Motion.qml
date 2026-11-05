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
    id: root

    /*! Hover and press washes: quick enough to follow the pointer. */
    readonly property int instant: 120
    /*! Fades and colour changes. */
    readonly property int fast: 180
    /*! Things moving: a slide, a pill stretching, a knob crossing a switch. */
    readonly property int base: 260
    /*! A whole popup changing size — a bigger move than any control makes. */
    readonly property int resize: 320
    /*! Player transitions, 1.5 times faster than the previous 360 ms. */
    readonly property int mediaChange: 240
    readonly property int mediaEasing: Easing.InOutSine
    /*! Short acceleration/deceleration ramps while a seek follows new targets. */
    readonly property int mediaEasingTime: Math.round(root.mediaChange / 5)
    /*! Native windows: preserve the compositor's move/overview pace, but
        ease window geometry at both ends. Genie needs time to form its neck. */
    readonly property int windowMove: 479
    /*! Genie: 1.5 times faster than its original 560 ms. */
    readonly property int windowMinimize: 373
    /*! Motion exposure while Genie moves; resting windows stay sharp. */
    readonly property int windowExposure: 22
    readonly property int windowClose: 180
    readonly property var windowCurve: [0.25, 0.1, 0.25, 1]
    /*! The step between notification exits, oldest first, when cleared together. */
    readonly property int notificationStagger: 60
    readonly property int spinner: 900
    readonly property int overviewFocus: 400
    readonly property var overviewFocusCurve: [0.22, 1, 0.36, 1]

    /*! How much quicker a popup's own motion is than the rest of the shell's:
        its card opening, closing, flying into another's place and changing
        size, and whatever is timed to that (OverlayCard, ShellOverlay, quick
        settings' pages). */
    readonly property real popupPace: 1.3
    /*! `fast`, `base` and `resize` at that pace: a popup's card fading, and
        rolling back into its door; sliding or rolling out; flying and
        changing size. */
    readonly property int popupFade: Math.round(root.fast / root.popupPace)
    readonly property int popupMove: Math.round(root.base / root.popupPace)
    readonly property int popupResize: Math.round(root.resize / root.popupPace)
    /*! How much quicker the window switcher comes and goes than a popup's
        card, and its title changes: it is up only while Alt is held, and
        must not keep the hand on it waiting. `popupFade` and `popupMove` at
        that pace. */
    readonly property real switcherPace: 1.5
    readonly property int switcherFade: Math.round(root.popupFade / root.switcherPace)
    readonly property int switcherMove: Math.round(root.popupMove / root.switcherPace)
    /*! How long past a fade's end what faded is kept before it is taken
        down — a popup's card, the OSD's window — so the fade's last frame is
        drawn first: the fade is a Behavior's, which never says it has
        finished, so a timer of its length and this stands in. Not at a
        popup's pace: it is frames, not motion. */
    readonly property int grace: 60

    /*! How long the pointer rests on something before more of it shows: a
        tooltip, the dock's preview of an application's windows. */
    readonly property int dwell: 450
    /*! With magnification on, the dock's hand and name wait together;
        magnification itself and input still follow the pointer immediately. */
    readonly property int dockHover: 300
    /*! How long the dock's preview stays once the pointer has left it and the
        icons, so a path that strays off them for a moment does not close it. */
    readonly property int linger: 250
    /*! How long the pointer rests on another application's icon, off its way
        to the dock's preview, before the preview goes and comes back over
        that one. */
    readonly property int hop: 300
    /*! How long the pointer rests at a tiled or fullscreen window's top edge
        before its title bar comes out: half the dwell, since the bar is
        what the pointer went up there for. */
    readonly property int reveal: 225
    /*! How long Alt is held after Alt+Tab before the window switcher shows:
        a quick Alt+Tab goes back to the window before without flashing it,
        as macOS's Command-Tab does. */
    readonly property int glance: 100

    /*! Fades and colour: gentle at both ends, so nothing pops on or off. */
    readonly property int standardEasing: Easing.InOutQuad
    /*! The same curve as a CSS cubic-bezier(), for what the compositor eases
        and Qt does not: the title bars (modules/common/CompositorTheme). */
    readonly property var standardCurve: [0.45, 0, 0.55, 1]
    /*! Movement: leaves briskly and settles slowly, without the near-instant
        launch a quintic gives. */
    readonly property int emphasizedEasing: Easing.OutCubic
    /*! The same curve as a CSS cubic-bezier(): a title bar rolling out of its
        window as a popup's door does (modules/common/CompositorTheme). */
    readonly property var emphasizedCurve: [0.33, 1, 0.68, 1]
    /*! For a container changing size: even at both ends, so the edge does not
        appear to leap and then crawl the way an out-curve makes it. */
    readonly property int resizeEasing: Easing.InOutCubic
}
