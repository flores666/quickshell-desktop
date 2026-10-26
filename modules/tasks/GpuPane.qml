pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The GPU: its name and how busy it is now, a chart of the last minute of
    that, how much of its memory is used, and its temperature. Shown only
    while there is a GPU (TaskManager's tabs); what it does not report — its
    memory, its temperature — is not shown, and the rest takes the room.
*/
Item {
    id: root

    property var manager: null

    readonly property bool hasVram: Usage.vramTotal > 0
    readonly property bool hasTemp: Usage.gpuTemp >= 0

    Label {
        x: Appearance.s.xl
        y: (root.manager.barHeight - height) / 2
        text: qsTr("GPU")
        role: Label.Role.Subtitle
    }

    Item {
        id: page

        anchors.fill: parent
        anchors.margins: Appearance.s.xl
        anchors.topMargin: root.manager.barHeight + Appearance.s.xl

        ChartCard {
            width: page.width
            height: (root.hasVram || root.hasTemp ? facts.y - Appearance.s.lg : page.height)
            title: Usage.gpuName !== "" ? Usage.gpuName : qsTr("GPU")
            figure: root.manager.percent(Usage.gpu)
            series: [{ points: Usage.history.gpu, color: Appearance.c.seriesGpu }]
            now: Usage.now
            span: Usage.span
            max: 100
            format: v => root.manager.percent(v)
        }

        Item {
            id: facts

            y: page.height - height
            width: page.width
            height: Math.max(vram.implicitHeight, temp.implicitHeight)

            FactCard {
                id: vram
                visible: root.hasVram
                width: root.hasTemp ? facts.width - temp.width - Appearance.s.lg : facts.width
                height: facts.height
                title: qsTr("VRAM")
                value: qsTr("%1 of %2 · %3%").arg(Usage.formatBytes(Usage.vramUsed))
                    .arg(Usage.formatBytes(Usage.vramTotal))
                    .arg(Math.round(Usage.vramUsed * 100 / Math.max(1, Usage.vramTotal)))
                fraction: Usage.vramUsed / Math.max(1, Usage.vramTotal)
                ink: Appearance.c.seriesGpu
            }

            FactCard {
                id: temp
                visible: root.hasTemp
                x: facts.width - width
                width: root.hasVram ? (facts.width - Appearance.s.lg) / 3 : facts.width
                height: facts.height
                title: qsTr("Temperature")
                value: qsTr("%1 °C").arg(Math.round(Usage.gpuTemp))
            }
        }
    }
}
