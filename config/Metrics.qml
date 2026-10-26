pragma ComponentBehavior: Bound

import QtQuick

/*! Structural sizes: the dimensions of the shell's own furniture.
    The user-settable ones and their limits live in Tuning. */
QtObject {
    id: root

    readonly property int barHeight: Tuning.pick("barHeight")
    /*! One spacing step (s.md) shorter than the panel, so a control is inset by
        half that per side — and since both are capsules, that inset is also
        the difference between their radii, which is what keeps a control's
        hover wash concentric with the bar's ends. Derived rather than set, so
        the two cannot drift apart. */
    readonly property int barItemHeight: root.barHeight - 8
    /*! The gap above the bar. Tighter than the one beside it by default:
        vertical room is taken from every window on the screen, and horizontal
        room is not. */
    readonly property int barGap: Tuning.pick("barGap")
    readonly property int barSideGap: Tuning.pick("barSideGap")
    /*! How much of the screen the bar occupies, including the gap above it. */
    readonly property int barFootprint: root.barHeight + root.barGap

    /*!
        The dock, from the inside out. Every application, and the launcher,
        stands in one round slot: its icon, inset all round by `dockInset`.
        The slot is also its highlight — hover, press and the focused
        application alike — and its window dots sit just under it.

        With its background the dock keeps `dockClearance` of glass round
        every slot and centres its round ends on the first and last ones, so a
        highlight is concentric with them and stands as far from the dock's
        edge everywhere, and every icon as far from the top as from the
        bottom. Without one (its opacity at 0) there is no edge to keep clear
        of, and the dock is only as big as its slots and the dots under them —
        which is what it reserves, and what popups keep clear of. Only the icon
        is the user's; the rest is fixed, so the proportions hold across its
        whole range.
    */
    readonly property int dockIcon: Tuning.pick("dockIcon")
    readonly property int dockInset: 2
    readonly property int dockClearance: 8
    /*! A window dot: round, this across, and how far under its slot. */
    readonly property int dockDot: 3
    readonly property int dockDotGap: 2
    /*! Between neighbouring slots, so their icons stand 12px apart. */
    readonly property int dockGap: 8
    readonly property int dockSlot: root.dockIcon + root.dockInset * 2
    /*! Whether the dock has any glass at all; Appearance, which resolves the
        dock's opacity, sets it. */
    property bool dockBackground: true
    /*! The room the dock keeps above its slots and at either end, and below
        them: the clearance while it has its background, and without one
        nothing above and only the dots below. */
    readonly property int dockFrame: root.dockBackground ? root.dockClearance : 0
    readonly property int dockBase: root.dockBackground
        ? root.dockClearance : root.dockDotGap + root.dockDot
    readonly property int dockHeight: root.dockFrame + root.dockSlot + root.dockBase
    /*! The divider before the launcher, as a share of an icon: shorter than
        the icons, it reads as a pause rather than a wall. */
    readonly property int dockDivider: Math.round(root.dockIcon * 0.6)
    /*! How tall the dock is on screen, including the gap under it: what it
        reserves while it is always shown, and what popups and the OSD keep
        clear of either way. */
    readonly property int dockFootprint: root.dockHeight + root.screenGap
    /*! A window's picture in the dock's preview: the box it is fitted into,
        this tall and as wide as its screen's shape makes it. */
    readonly property int dockPreview: 140
    /*! An application in the window switcher: its icon, and the room round
        it that its highlight fills. */
    readonly property int switcherIcon: 64
    readonly property int switcherInset: 10

    /*! The hairline around every Surface. Zero is a legitimate choice, which is
        why the unset marker for it is -1 and not 0. */
    readonly property int border: Tuning.pick("border")

    /*! The gap under the dock, to the screen's bottom edge. Fixed, not one
        of the user's: the same at every icon size. */
    readonly property int screenGap: 6
    /*! The keyboard focus ring: never the hairline above, which may be zero. */
    readonly property int focusRing: 2
    /*! The gap a popup keeps from the panel it opens off — the bar above it or
        the dock below it. Named once so no popup can drift from the others. */
    readonly property int popupGap: 8
    /*! How far a notification travels sliding in from the screen's edge and
        back out to it: a toast, and a row leaving the notification centre. */
    readonly property int notificationSlide: 40
    readonly property int popoverWidth: 372
    readonly property int touchTarget: 32
    /*! How tall a text field stands. Named once so the search fields and the
        password wells cannot drift apart. */
    readonly property int fieldHeight: 32
    /*! The least a menu stands across: a popup menu's rows, a card's context menu. */
    readonly property int menuWidth: 180
    /*! A row of a sidebar: the launcher's categories, the settings sections. */
    readonly property int navRowHeight: 36
    /*! The settings panel's and the task manager's card at most, and the
        list of tabs down its left. */
    readonly property int paneCardWidth: 820
    readonly property int paneCardHeight: 580
    readonly property int navWidth: 196
    /*! A column of figures in the task manager's lists: CPU, OOM score; a
        size or a user's name. */
    readonly property int figureColumn: 60
    readonly property int wideColumn: 92
    /*! A gauge's bar, and a threshold's mark across it. */
    readonly property int gaugeHeight: 8
    readonly property int gaugeMark: 2

    /*! The sparkline of a usage card on the date menu: the least it is drawn at. */
    readonly property int usageChart: 32
    /*! The task manager's entity tabs (CPU, GPU, RAM, Disks, Network): the
        chart's height on one that scrolls, with more under its list (RAM's
        earlyoom) — about what the others' charts take in a full-size card,
        so the tabs line up and the next heading shows under the list — and
        the least any takes in a smaller card. */
    readonly property int entityChart: 196
    readonly property int entityChartLeast: 96
    /*! A process in a "most" list that went quiet within the minute: how
        strongly its icon is drawn, its text muted beside it. */
    readonly property real quiet: 0.5

    /*! A colour swatch, and the pin badge a pinned one wears. */
    readonly property int swatch: 28
    readonly property int swatchBadge: 14
    /*! The colour picker: its saturation-value plane, hue strip and knobs. */
    readonly property int pickerPlane: 112
    readonly property int pickerStrip: 14
    readonly property int pickerKnob: 16

    /*! A chart's line, and the dot a lone sample is. */
    readonly property int chartLine: 2
    readonly property int chartDot: 3
    /*! The room its axis labels take: the value labels' width at the left,
        the span labels' height below. Wide enough for a rate at the
        caption size, "1023.9 MiB/s" (67 px): the disk's and network's. */
    readonly property int chartAxisWidth: 72
    readonly property int chartAxisHeight: 16
    /*! The fill under a line, as its strongest opacity (at the line): enough
        for the area to read as the reading's, under the line, on glass. */
    readonly property real chartFill: 0.45
    /*! How far above its highest point a scale that follows the data tops
        out, as a share of it. */
    readonly property real chartHeadroom: 1.25
    /*! The hover crosshair's width. */
    readonly property int chartCrosshair: 1

    readonly property int iconSm: 14
    readonly property int icon: 16
    readonly property int iconLg: 20
    readonly property int iconXl: 28
}
