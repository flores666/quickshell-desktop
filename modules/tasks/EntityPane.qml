pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The one pattern every entity tab follows — CPU, GPU, RAM, Disks,
    Network: its title in the bar, then top to bottom a card naming the
    thing with its facts (EntityFacts: a bar where it has a capacity), a
    chart of its last minute with its axes and a legend, and the processes
    that used it most (RankedList: `Activity.top(rankKey)`, five at most,
    their room kept).

    The chart takes the height the rest leaves. A tab with more under its
    list (`section`: RAM's earlyoom) scrolls instead, its chart the height
    the others take in a full-size card (`entityChart`).
*/
Item {
    id: root

    property var manager: null

    property string title: ""
    /*! The facts card's glyph and lines, as EntityFacts takes them. */
    property string icon: ""
    property var lines: []

    /*! The chart: as ChartCard's. */
    property var legend: []
    property var series: []
    property real max: 100
    property var format: v => root.manager.percent(v)

    /*! What the list ranks by, an `Activity` key, and how a figure of it
        reads; its heading, and what it says while nothing is listed. */
    property string rankKey: ""
    property var figure: v => String(v)
    property string rankTitle: ""
    property string empty: ""
    readonly property int most: 5
    readonly property var ranked: Activity.top(root.rankKey, root.most)

    /*! What goes under the list, scrolled to; null for nothing. */
    property Component section: null
    readonly property bool scrolls: root.section !== null

    Label {
        x: Appearance.s.xl
        y: (root.manager.barHeight - height) / 2
        text: root.title
        role: Label.Role.Subtitle
    }

    Flickable {
        id: scroller

        anchors.fill: parent
        anchors.topMargin: root.manager.barHeight
        clip: true
        interactive: root.scrolls
        contentHeight: root.scrolls ? page.implicitHeight + Appearance.s.xl * 2 : scroller.height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: page

            x: Appearance.s.xl
            y: Appearance.s.xl
            width: scroller.width - Appearance.s.xl * 2
            spacing: Appearance.s.lg

            EntityFacts {
                id: facts
                width: page.width
                height: implicitHeight
                icon: root.icon
                lines: root.lines
            }

            ChartCard {
                width: page.width
                height: root.scrolls ? Appearance.m.entityChart
                    : Math.max(Appearance.m.entityChartLeast, scroller.height - Appearance.s.xl * 2
                        - facts.height - list.height - page.spacing * 2)
                legend: root.legend
                series: root.series
                now: Usage.now
                span: Usage.span
                max: root.max
                format: root.format
            }

            RankedList {
                id: list
                width: page.width
                title: root.rankTitle
                entries: root.ranked
                format: root.figure
                empty: root.empty
                // Said once there could be one: the second sample of the
                // watch, or of the extra the tab asked for, has a figure.
                ready: Processes.fresh > 1
                most: root.most
            }

            Loader {
                width: page.width
                active: root.scrolls
                sourceComponent: root.section
            }
        }
    }

    // Over the margin at the right, clear of the content.
    ThinScrollBar { flickable: scroller }
}
