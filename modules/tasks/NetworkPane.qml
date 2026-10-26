pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The network: what comes in and goes out a second now, over every
    physical interface, and a chart of both over the last minute. Linux
    keeps no count per process without root, so there is no list of who.
*/
Item {
    id: root

    property var manager: null

    Label {
        x: Appearance.s.xl
        y: (root.manager.barHeight - height) / 2
        text: qsTr("Network")
        role: Label.Role.Subtitle
    }

    Item {
        id: page

        anchors.fill: parent
        anchors.margins: Appearance.s.xl
        anchors.topMargin: root.manager.barHeight + Appearance.s.xl

        RateCard {
            id: down
            width: (page.width - Appearance.s.lg) / 2
            title: qsTr("Download")
            icon: "download"
            ink: Appearance.c.seriesIn
            rate: Usage.netDown
        }

        RateCard {
            x: page.width - width
            width: down.width
            title: qsTr("Upload")
            icon: "upload"
            ink: Appearance.c.seriesOut
            rate: Usage.netUp
        }

        ChartCard {
            anchors.top: down.bottom
            anchors.topMargin: Appearance.s.lg
            anchors.bottom: parent.bottom
            width: page.width
            legend: [
                { label: qsTr("Download"), color: Appearance.c.seriesIn },
                { label: qsTr("Upload"), color: Appearance.c.seriesOut }
            ]
            series: [
                { points: Usage.history.netDown, color: Appearance.c.seriesIn },
                { points: Usage.history.netUp, color: Appearance.c.seriesOut }
            ]
            now: Usage.now
            span: Usage.span
            max: 0
            format: v => Usage.formatRate(v)
        }
    }
}
