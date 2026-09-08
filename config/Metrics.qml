pragma ComponentBehavior: Bound

import QtQuick

/*! Structural sizes: the dimensions of the shell's own furniture.
    The user-settable ones and their limits live in Tuning. */
QtObject {
    id: root

    readonly property int barHeight: Tuning.pick("barHeight")
    /*! One spacing step (s.md) shorter than the panel, so a well is inset by
        half that per side — which is exactly r.lg - r.md, and is what keeps the
        well's corner and the panel's concentric. Both halves of that rule have
        to move together, so this is derived rather than set. */
    readonly property int barItemHeight: root.barHeight - 8
    /*! The gap above the bar. Tighter than the one beside it by default:
        vertical room is taken from every window on the screen, and horizontal
        room is not. */
    readonly property int barGap: Tuning.pick("barGap")
    readonly property int barSideGap: Tuning.pick("barSideGap")
    /*! How much of the screen the bar occupies, including the gap above it. */
    readonly property int barFootprint: root.barHeight + root.barGap

    readonly property int dockIcon: Tuning.pick("dockIcon")
    readonly property int dockPadding: 5
    /*! The icon plus its padding. DockItem hangs the icon a pixel high of centre
        and spends what is left at the bottom on the running indicator, so this
        has to follow the icon rather than stand as a number of its own. */
    readonly property int dockCell: root.dockIcon + root.dockPadding * 2
    readonly property int dockGap: 2
    /*! How tall the dock is on screen, including the gap under it. It reserves
        no space — this is only used to position things relative to it. */
    readonly property int dockFootprint: root.dockCell + root.dockPadding * 2 + root.screenGap
    /*! Room kept above the dock inside its window for hover tooltips. */
    readonly property int dockTooltipSpace: 48

    /*! The hairline around every Surface. Zero is a legitimate choice, which is
        why the unset marker for it is -1 and not 0. */
    readonly property int border: Tuning.pick("border")

    readonly property int screenGap: Tuning.pick("screenGap")
    /*! The gap a popup keeps from the panel it opens off — the bar above it or
        the dock below it. Named once so no popup can drift from the others. */
    readonly property int popupGap: 8
    readonly property int popoverWidth: 372
    readonly property int touchTarget: 32

    readonly property int iconSm: 14
    readonly property int icon: 16
    readonly property int iconLg: 20
    readonly property int iconXl: 28
}
