pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*!
    The CPU, as an entity tab: its model and how busy it is now, its cores,
    threads and frequency (each only where known); the last minute of how
    busy; and the processes that used most of it over that minute, any
    user's.
*/
EntityPane {
    id: root

    title: qsTr("CPU")
    icon: "cpu"
    lines: [
        { text: Usage.cpuModel !== "" ? Usage.cpuModel : qsTr("CPU"), value: root.manager.percent(Usage.cpu) },
        { text: [
            Usage.cpuCores > 0 ? (Usage.cpuCores === 1 ? qsTr("1 core") : qsTr("%1 cores").arg(Usage.cpuCores)) : "",
            Usage.cpuThreads > 0
                ? (Usage.cpuThreads === 1 ? qsTr("1 thread") : qsTr("%1 threads").arg(Usage.cpuThreads)) : "",
            Usage.cpuFreq > 0 ? qsTr("%1 GHz").arg((Usage.cpuFreq / 1000).toFixed(1)) : ""
        ].filter(part => part !== "").join(" · ") }
    ]

    legend: [{ label: qsTr("Busy"), color: Appearance.c.seriesCpu, value: root.manager.percent(Usage.cpu) }]
    series: [{ points: Usage.history.cpu, color: Appearance.c.seriesCpu }]

    rankKey: "cpu"
    rankTitle: qsTr("Most CPU · last minute")
    figure: v => qsTr("%1%").arg(v.toFixed(1))
    empty: qsTr("Nothing has used the CPU in the last minute.")
}
