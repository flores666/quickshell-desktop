pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    A chart with its axes on a card, the last `Usage.span` seconds of one
    reading or two: along the top, what it is (`title`), a legend where it
    shows more than one line, and the reading now at the far end (`figure`).
    The chart takes the height left.
*/
Card {
    id: root

    property string title: ""
    property string figure: ""
    /*! As Legend's; none for a chart of one line. */
    property var legend: []

    /*! As Chart's. */
    property var series: []
    property real now: 0
    property real span: 60
    property real max: 100
    property var format: v => Math.round(v) + "%"

    Row {
        id: heading

        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2 - (reading.visible ? reading.width + Appearance.s.md : 0)
        spacing: Appearance.s.lg

        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, heading.width - (key.visible ? key.width + heading.spacing : 0))
            visible: root.title !== ""
            text: root.title
            font.weight: Font.Medium
        }

        Legend {
            id: key
            anchors.verticalCenter: parent.verticalCenter
            visible: root.legend.length > 0
            entries: root.legend
        }
    }

    Label {
        id: reading
        anchors.right: parent.right
        anchors.rightMargin: root.padding
        anchors.verticalCenter: heading.verticalCenter
        visible: root.figure !== ""
        text: root.figure
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
    }

    Chart {
        x: root.padding
        y: heading.y + Math.max(heading.height, reading.height) + Appearance.s.md
        width: root.width - root.padding * 2
        height: Math.max(0, root.height - root.padding - y)
        series: root.series
        now: root.now
        span: root.span
        max: root.max
        axes: true
        format: root.format
    }
}
