pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    One reading on a `raised` card: what it is, its figure, a chart of the
    last minute of it, and a line of detail under that ("3.4 GHz",
    "6.7 GiB of 16 GiB"). The chart takes whatever height the card has left,
    on a scale of its own data, as a sparkline is drawn: the figure above it
    says how much, the line how it went. A percentage's, so never under
    10%.

    The card takes no input of its own; one that opens something is laid in a
    Clickable, whose state layer shows through the card's wash (the date
    menu's).
*/
Rectangle {
    id: root

    property string title: ""
    /*! The reading as it stands, "–" before there is one. */
    property string figure: ""
    property string detail: ""

    /*! As Chart's. */
    property var series: []
    property real now: 0
    property real span: 60
    property real max: 0
    property real least: 10
    property bool axes: false
    property var format: v => Math.round(v) + "%"

    readonly property int padding: Appearance.s.lg

    radius: Appearance.r.lg
    color: Appearance.c.raised
    border.width: Appearance.m.border
    border.color: Appearance.c.border

    Label {
        id: heading
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        text: root.title
        role: Label.Role.Small
        muted: true
        elide: Text.ElideRight
    }

    Label {
        id: reading
        x: root.padding
        anchors.top: heading.bottom
        text: root.figure
        role: Label.Role.Subtitle
        font.features: { "tnum": 1 }
    }

    readonly property alias chart: plot

    Chart {
        id: plot
        x: root.padding
        anchors.top: reading.bottom
        anchors.topMargin: Appearance.s.xs
        width: root.width - root.padding * 2
        height: Math.max(0, (note.visible ? note.y - Appearance.s.xs : root.height - root.padding) - y)
        series: root.series
        now: root.now
        span: root.span
        max: root.max
        least: root.least
        axes: root.axes
        format: root.format
    }

    Label {
        id: note
        x: root.padding
        y: root.height - root.padding - height
        width: root.width - root.padding * 2
        visible: root.detail !== ""
        text: root.detail
        role: Label.Role.Caption
        muted: true
        elide: Text.ElideRight
    }
}
