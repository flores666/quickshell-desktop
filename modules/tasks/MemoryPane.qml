pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Memory and swap left, as earlyoom reckons them, against the levels it
    acts at; its options; and what it has stopped.

    Without earlyoom only the gauges are here, with no marks; without its
    journal to read (wheel, adm and systemd-journal may), no history.
*/
Item {
    id: root

    property var manager: null

    readonly property var memory: Processes.memory
    readonly property var config: EarlyOom.config

    Label {
        x: Appearance.s.xl
        y: (root.manager.barHeight - height) / 2
        text: qsTr("Memory")
        role: Label.Role.Subtitle
    }

    Label {
        anchors.right: parent.right
        anchors.rightMargin: Appearance.s.xl
        y: (root.manager.barHeight - height) / 2
        text: !EarlyOom.available ? qsTr("earlyoom is not installed")
            : EarlyOom.running ? qsTr("earlyoom is watching") : qsTr("earlyoom is stopped")
        role: Label.Role.Small
        color: EarlyOom.available && !EarlyOom.running ? Appearance.c.warning : Appearance.c.textMuted
    }

    Flickable {
        id: scroller

        anchors.fill: parent
        anchors.topMargin: root.manager.barHeight + Appearance.s.xl
        anchors.leftMargin: Appearance.s.xl
        anchors.rightMargin: Appearance.s.xl
        clip: true
        contentHeight: page.implicitHeight + Appearance.s.xl
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: page

            width: scroller.width - scrollbar.footprint
            spacing: Appearance.s.lg

            SettingGroup {
                width: page.width
                title: qsTr("Left now")

                MemoryGauge {
                    width: parent.width
                    title: qsTr("Memory")
                    percent: EarlyOom.usage.memPercent
                    detail: qsTr("%1 of %2 available")
                        .arg(Processes.formatSize(root.memory.available))
                        .arg(Processes.formatSize(root.memory.available + root.memory.anon))
                    marks: EarlyOom.available ? [root.config.memTerm, root.config.memKill] : []
                }

                MemoryGauge {
                    width: parent.width
                    visible: root.memory.swapTotal > 0
                    title: qsTr("Swap")
                    percent: EarlyOom.usage.swapPercent
                    detail: qsTr("%1 of %2 free")
                        .arg(Processes.formatSize(root.memory.swapFree))
                        .arg(Processes.formatSize(root.memory.swapTotal))
                    marks: EarlyOom.available ? [root.config.swapTerm, root.config.swapKill] : []
                }
            }

            Loader {
                width: page.width
                active: EarlyOom.available
                visible: this.active
                sourceComponent: EarlyOomSettings { width: page.width }
            }

            SettingGroup {
                width: page.width
                visible: EarlyOom.available && EarlyOom.logReadable
                title: qsTr("Stopped by earlyoom")

                Repeater {
                    model: EarlyOom.kills

                    MenuRow {
                        required property var modelData

                        width: parent.width
                        flush: true
                        title: this.modelData.name
                        subtitle: qsTr("%1 · PID %2 · %3 MiB · %4")
                            .arg(Qt.formatDateTime(new Date(this.modelData.time), "d MMM, HH:mm"))
                            .arg(this.modelData.pid).arg(this.modelData.rss)
                            .arg(this.modelData.signal === "SIGKILL" ? qsTr("forced") : qsTr("asked to quit"))
                    }
                }

                Label {
                    width: parent.width
                    visible: EarlyOom.kills.length === 0
                    text: qsTr("Nothing so far.")
                    role: Label.Role.Small
                    muted: true
                }
            }
        }
    }

    ThinScrollBar { id: scrollbar; flickable: scroller }
}
