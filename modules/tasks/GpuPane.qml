pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*!
    The GPU, as an entity tab: its name and how busy it is now, how much of
    its memory is used, with a bar, and its temperature — each only where
    the GPU reports it; the last minute of how busy; and the processes that
    used most of it over that minute, the user's own alone (another's GPU
    time is not readable). Shown only while there is a GPU (TaskManager's
    tabs).
*/
EntityPane {
    id: root

    readonly property real vram: Usage.vramTotal > 0 ? Usage.vramUsed / Usage.vramTotal : -1

    title: qsTr("GPU")
    icon: "gpu"
    lines: [
        { text: Usage.gpuName !== "" ? Usage.gpuName : qsTr("GPU"), value: root.manager.percent(Usage.gpu) },
        { text: root.vram < 0 ? "" : qsTr("VRAM"),
          value: root.vram < 0 ? "" : qsTr("%1 of %2 · %3%").arg(Usage.formatBytes(Usage.vramUsed))
              .arg(Usage.formatBytes(Usage.vramTotal)).arg(Math.round(root.vram * 100)) },
        root.vram < 0 ? {} : { bar: root.vram, ink: Appearance.c.seriesGpu },
        { text: Usage.gpuTemp < 0 ? "" : qsTr("Temperature"),
          value: Usage.gpuTemp < 0 ? "" : qsTr("%1 °C").arg(Math.round(Usage.gpuTemp)) }
    ]

    legend: [{ label: qsTr("Busy"), color: Appearance.c.seriesGpu, value: root.manager.percent(Usage.gpu) }]
    series: [{ points: Usage.history.gpu, color: Appearance.c.seriesGpu }]

    rankKey: "gpu"
    rankTitle: qsTr("Most GPU · last minute")
    figure: v => qsTr("%1%").arg(v.toFixed(1))
    empty: qsTr("Nothing of yours has used the GPU in the last minute.")
}
