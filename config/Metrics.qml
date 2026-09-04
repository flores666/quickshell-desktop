pragma ComponentBehavior: Bound

import QtQuick

/*! Structural sizes: the dimensions of the shell's own furniture. */
QtObject {
    readonly property int barHeight: 36
    readonly property int barItemHeight: 26

    readonly property int dockIcon: 34
    readonly property int dockCell: 44
    readonly property int dockPadding: 5
    readonly property int dockGap: 2
    /*! How tall the dock is on screen, including the gap under it. It reserves
        no space — this is only used to position things relative to it. */
    readonly property int dockFootprint: dockCell + dockPadding * 2 + screenGap
    /*! Room kept above the dock inside its window for hover tooltips. */
    readonly property int dockTooltipSpace: 48

    readonly property int screenGap: 8
    readonly property int popoverWidth: 372
    readonly property int touchTarget: 32

    readonly property int iconSm: 14
    readonly property int icon: 16
    readonly property int iconLg: 20
    readonly property int iconXl: 28
}
