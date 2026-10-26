pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*!
    Memory, as an entity tab: how much is used of all of it, with a bar, and
    swap where there is any; the last minute of it; the processes holding
    the most now, any user's; and under them earlyoom (EarlyOomSection), so
    the tab scrolls.
*/
EntityPane {
    id: root

    readonly property var memory: Processes.memory

    title: qsTr("RAM")
    icon: "ram"
    lines: [
        { text: qsTr("RAM"), value: Usage.memoryTotal > 0 && Usage.memory >= 0
            ? qsTr("%1 of %2 · %3%").arg(Usage.formatBytes(Usage.memoryUsed))
                .arg(Usage.formatBytes(Usage.memoryTotal)).arg(Math.round(Usage.memory))
            : "–" },
        { bar: Usage.memoryTotal > 0 ? Usage.memoryUsed / Usage.memoryTotal : 0, ink: Appearance.c.seriesMemory },
        { text: root.memory.swapTotal > 0 ? qsTr("Swap") : "",
          value: root.memory.swapTotal > 0 ? qsTr("%1 of %2")
              .arg(Usage.formatBytes((root.memory.swapTotal - root.memory.swapFree) * 1024))
              .arg(Usage.formatBytes(root.memory.swapTotal * 1024)) : "" }
    ]

    legend: [{ label: qsTr("Used"), color: Appearance.c.seriesMemory, value: root.manager.percent(Usage.memory) }]
    series: [{ points: Usage.history.memory, color: Appearance.c.seriesMemory }]

    rankKey: "rss"
    rankTitle: qsTr("Most memory")
    figure: v => Processes.formatSize(v)
    empty: qsTr("Nothing is holding memory.")

    section: EarlyOomSection {}
}
