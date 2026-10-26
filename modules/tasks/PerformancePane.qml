pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    How busy the machine is, a card each, two to a row: CPU, memory, the GPU
    (only with one) and the disk, each its figure now, a sparkline of the
    last minute and what it is against — the CPUs' frequency, memory used of
    all of it, the GPU's name, the root filesystem's space. A card alone in
    its row takes the whole row.

    Every figure reads "–" until Usage has two samples; a detail it does not
    know yet is left out. The cards are kept by the reading they show, so a
    sample changes what they say and builds none of them again.
*/
Item {
    id: root

    property var manager: null

    /*! The readings shown, each a series of Usage's. */
    readonly property var readings: ["cpu", "memory", "gpu", "disk"].filter(k => k !== "gpu" || Usage.hasGpu)
    readonly property var titles: ({ cpu: qsTr("CPU"), memory: qsTr("RAM"), gpu: qsTr("GPU"), disk: qsTr("Disk") })
    readonly property var colors: ({
        cpu: Appearance.c.seriesCpu, memory: Appearance.c.seriesMemory,
        gpu: Appearance.c.seriesGpu, disk: Appearance.c.seriesDisk
    })

    readonly property int gap: Appearance.s.lg
    readonly property int rows: Math.ceil(root.readings.length / 2)
    readonly property real cardWidth: (grid.width - root.gap) / 2
    readonly property real cardHeight: (grid.height - root.gap * (root.rows - 1)) / root.rows

    /*! What a reading is against, "" while that is not known. */
    function detail(key: string): string {
        switch (key) {
        case "cpu":
            return Usage.cpuFreq > 0 ? qsTr("%1 GHz").arg((Usage.cpuFreq / 1000).toFixed(1)) : "";
        case "memory":
            return Usage.memoryTotal > 0 ? qsTr("%1 of %2").arg(Usage.formatBytes(Usage.memoryUsed))
                .arg(Usage.formatBytes(Usage.memoryTotal)) : "";
        case "gpu":
            return Usage.gpuName;
        case "disk":
            return Usage.fsTotal > 0 ? qsTr("/: %1 of %2").arg(Usage.formatBytes(Usage.fsUsed))
                .arg(Usage.formatBytes(Usage.fsTotal)) : "";
        }
        return "";
    }

    Label {
        x: Appearance.s.xl
        y: (root.manager.barHeight - height) / 2
        text: qsTr("Performance")
        role: Label.Role.Subtitle
    }

    Item {
        id: grid

        anchors.fill: parent
        anchors.margins: Appearance.s.xl
        anchors.topMargin: root.manager.barHeight + Appearance.s.xl

        Repeater {
            model: root.readings

            StatCard {
                id: card

                required property string modelData
                required property int index

                readonly property bool alone: card.index === root.readings.length - 1 && card.index % 2 === 0

                x: card.index % 2 * (root.cardWidth + root.gap)
                y: Math.floor(card.index / 2) * (root.cardHeight + root.gap)
                width: card.alone ? grid.width : root.cardWidth
                height: root.cardHeight
                title: root.titles[card.modelData]
                figure: root.manager.percent(Usage[card.modelData])
                detail: root.detail(card.modelData)
                series: [{ points: Usage.history[card.modelData], color: root.colors[card.modelData] }]
                now: Usage.now
                span: Usage.span
                max: 100
            }
        }
    }
}
