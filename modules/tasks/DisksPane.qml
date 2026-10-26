pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*!
    The disks, as an entity tab: each whole disk, its model and size, the
    largest first, and how full the root filesystem is, with a bar; a chart
    of what is read and written a second over the last minute; and the
    processes that read and wrote the most over that minute, the user's own
    alone (another's I/O is not readable).
*/
EntityPane {
    id: root

    readonly property var disks: (Processes.last?.disks ?? []).slice().sort((a, b) => b.size - a.size)
    readonly property real share: Usage.fsTotal > 0 ? Usage.fsUsed / Usage.fsTotal : 0

    title: qsTr("Disks")
    icon: "disk"
    lines: root.disks.map(d => ({ text: d.model !== "" ? d.model : d.name, value: Usage.formatBytes(d.size), strong: true }))
        .concat([
            { text: qsTr("Root filesystem"), value: Usage.fsTotal > 0
                ? qsTr("%1 of %2 · %3%").arg(Usage.formatBytes(Usage.fsUsed))
                    .arg(Usage.formatBytes(Usage.fsTotal)).arg(Math.round(root.share * 100))
                : "–" },
            { bar: root.share, ink: Appearance.c.seriesDisk }
        ])

    legend: [
        { label: qsTr("Read"), color: Appearance.c.seriesIn, value: Usage.formatRate(Usage.diskRead) },
        { label: qsTr("Write"), color: Appearance.c.seriesOut, value: Usage.formatRate(Usage.diskWrite) }
    ]
    series: [
        { points: Usage.history.diskRead, color: Appearance.c.seriesIn },
        { points: Usage.history.diskWrite, color: Appearance.c.seriesOut }
    ]
    max: 0
    format: v => Usage.formatRate(v)

    rankKey: "io"
    rankTitle: qsTr("Most active · last minute")
    figure: v => Usage.formatRate(v)
    empty: qsTr("Nothing of yours has read or written in the last minute.")
}
