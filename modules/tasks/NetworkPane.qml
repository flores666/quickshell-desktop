pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*!
    The network, as an entity tab: the physical interfaces it is counted
    over, and what comes in and goes out a second now, each beside its
    glyph in its line's colour; a chart of both over the last minute; and
    the processes with the most connections open now, the user's own alone.
    Linux keeps no count of traffic per process from anyone but root, so
    connections are what ranks them.
*/
EntityPane {
    id: root

    readonly property var interfaces: (Processes.last?.nets ?? []).map(n => n.name)

    title: qsTr("Network")
    icon: "network-transfer"
    lines: [
        { text: root.interfaces.length > 0 ? root.interfaces.join(" · ") : qsTr("Network") },
        { text: qsTr("Download"), value: Usage.formatRate(Usage.netDown), icon: "download", ink: Appearance.c.seriesIn },
        { text: qsTr("Upload"), value: Usage.formatRate(Usage.netUp), icon: "upload", ink: Appearance.c.seriesOut }
    ]

    legend: [
        { label: qsTr("Download"), color: Appearance.c.seriesIn, value: Usage.formatRate(Usage.netDown) },
        { label: qsTr("Upload"), color: Appearance.c.seriesOut, value: Usage.formatRate(Usage.netUp) }
    ]
    series: [
        { points: Usage.history.netDown, color: Appearance.c.seriesIn },
        { points: Usage.history.netUp, color: Appearance.c.seriesOut }
    ]
    max: 0
    format: v => Usage.formatRate(v)

    rankKey: "connections"
    rankTitle: qsTr("Most connections")
    figure: v => v === 1 ? qsTr("1 connection") : qsTr("%1 connections").arg(v)
    empty: qsTr("Nothing of yours has a connection open.")
}
