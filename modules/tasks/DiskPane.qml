pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The disk: its model, with a bar of how full the root filesystem is; a
    chart of what is read and written a second, the last minute of it; and
    the user's own processes doing the most of that now (Most active), five
    at most. Another user's I/O is not readable, so it is never listed.

    The list holds its room for five whether or not five are busy, so the
    chart does not change size as processes come and go.
*/
Item {
    id: root

    property var manager: null

    readonly property int most: 5
    readonly property real share: Usage.fsTotal > 0 ? Usage.fsUsed / Usage.fsTotal : 0
    /*! The busiest of the user's own processes, by pid, busiest first. */
    readonly property var active: Processes.list
        .filter(p => p.own && p.io > 0)
        .sort((a, b) => b.io - a.io || a.pid - b.pid)
        .slice(0, root.most)
        .map(p => p.pid)

    Label {
        x: Appearance.s.xl
        y: (root.manager.barHeight - height) / 2
        text: qsTr("Disk")
        role: Label.Role.Subtitle
    }

    Item {
        id: page

        anchors.fill: parent
        anchors.margins: Appearance.s.xl
        anchors.topMargin: root.manager.barHeight + Appearance.s.xl

        Card {
            id: drive

            width: page.width
            height: room.height + drive.padding * 2

            Icon {
                id: glyph
                x: drive.padding
                anchors.verticalCenter: parent.verticalCenter
                name: "disk"
                size: Appearance.m.iconXl
                color: Appearance.c.textMuted
            }

            Column {
                id: room

                x: glyph.x + glyph.width + Appearance.s.lg
                y: drive.padding
                width: drive.width - x - drive.padding
                spacing: Appearance.s.sm

                Item {
                    width: room.width
                    height: title.height

                    Label {
                        id: title
                        width: Math.min(implicitWidth, room.width - space.implicitWidth - Appearance.s.lg)
                        text: Usage.diskModel !== "" ? Usage.diskModel : qsTr("Disk")
                        font.weight: Font.Medium
                    }

                    Label {
                        id: space
                        anchors.right: parent.right
                        anchors.verticalCenter: title.verticalCenter
                        text: Usage.fsTotal > 0
                            ? qsTr("%1 of %2 · %3%").arg(Usage.formatBytes(Usage.fsUsed))
                                .arg(Usage.formatBytes(Usage.fsTotal)).arg(Math.round(root.share * 100))
                            : "–"
                        role: Label.Role.Small
                        muted: true
                        font.features: { "tnum": 1 }
                    }
                }

                UsageBar {
                    width: room.width
                    fraction: root.share
                    color: Appearance.c.seriesDisk
                }
            }
        }

        ChartCard {
            anchors.top: drive.bottom
            anchors.topMargin: Appearance.s.lg
            anchors.bottom: heading.top
            anchors.bottomMargin: Appearance.s.lg
            width: page.width
            legend: [
                { label: qsTr("Read"), color: Appearance.c.seriesIn, value: Usage.formatRate(Usage.diskRead) },
                { label: qsTr("Write"), color: Appearance.c.seriesOut, value: Usage.formatRate(Usage.diskWrite) }
            ]
            series: [
                { points: Usage.history.diskRead, color: Appearance.c.seriesIn },
                { points: Usage.history.diskWrite, color: Appearance.c.seriesOut }
            ]
            now: Usage.now
            span: Usage.span
            max: 0
            format: v => Usage.formatRate(v)
        }

        Label {
            id: heading
            anchors.bottom: busiest.top
            anchors.bottomMargin: Appearance.s.sm
            text: qsTr("Most active")
            role: Label.Role.Small
            font.weight: Font.DemiBold
            muted: true
            leftPadding: Appearance.s.xxs
        }

        Card {
            id: busiest

            anchors.bottom: parent.bottom
            width: page.width
            height: Appearance.m.touchTarget * root.most + Appearance.s.sm * 2

            Column {
                id: rows
                x: busiest.padding
                y: Appearance.s.sm
                width: busiest.width - busiest.padding * 2

                Repeater {
                    model: ScriptModel { values: root.active }

                    BusyRow { width: rows.width }
                }
            }

            Label {
                anchors.centerIn: parent
                // Said once a rate is in: the first sample has none for anyone.
                visible: Processes.listed > 1 && root.active.length === 0
                text: qsTr("Nothing of yours is reading or writing now.")
                role: Label.Role.Small
                muted: true
            }
        }
    }
}
