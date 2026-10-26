pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"

/*!
    The task manager: what runs (Processes), memory and earlyoom, which stops
    what uses the most of it before the machine runs out (Memory), and the
    commands systemd runs on a schedule (Scheduled).

    Laid out as the settings panel is, tabs down the left and one pane on the
    right, each pane drawing its own bar along the top above the rule.

    The process list is read from /proc on a clock (Processes), so it is read
    exactly while it is on screen: the popup open on Processes or Memory.
    Opens on Processes, wherever it was left.
*/
ShellOverlay {
    id: root

    overlayId: Overlay.taskManager
    placement: ShellOverlay.Placement.Centre
    cardWidth: Math.min(Appearance.m.paneCardWidth, (root.screen ? root.screen.width : 1920) - Appearance.s.huge * 2)
    cardHeight: Math.min(Appearance.m.paneCardHeight, (root.screen ? root.screen.height : 1080) - Appearance.s.huge * 3)

    readonly property var tabs: [
        { key: "processes", title: qsTr("Processes"), icon: "cat-system", component: processesPane },
        { key: "memory", title: qsTr("Memory"), icon: "computer", component: memoryPane },
        { key: "scheduled", title: qsTr("Scheduled"), icon: "calendar", component: scheduledPane }
    ]
    property string tab: "processes"
    readonly property var current: root.tabs.find(t => t.key === root.tab)

    /*! Where the rule under the panes' bars runs. */
    readonly property int barHeight: Appearance.m.fieldHeight + Appearance.s.lg * 2

    Binding {
        target: Processes
        property: "watched"
        value: root.shown && root.tab !== "scheduled"
    }

    onRenderedChanged: if (!root.rendered)
        root.tab = "processes"

    /*! A process's menu: ending it, for one of the user's own, and where
        earlyoom is, moving its name into or out of earlyoom's lists — only
        what would change something, and none for a name no list can hold. */
    function menuFor(process: var, earlyoom: bool, preference: string): var {
        const entries = [];
        if (process.own) {
            entries.push({ label: qsTr("End"), icon: "close", run: () => Processes.terminate(process.pid) });
            entries.push({ label: qsTr("Force Kill"), icon: "error", danger: true,
                           run: () => Processes.forceKill(process.pid) });
        }
        if (earlyoom && EarlyOomArgs.listable(process.name)) {
            if (preference !== "avoid")
                entries.push({ label: qsTr("Protect from earlyoom"), icon: "lock",
                               run: () => EarlyOom.protect(process.name) });
            if (preference !== "prefer")
                entries.push({ label: qsTr("Kill First"), icon: "trash",
                               run: () => EarlyOom.preferKill(process.name) });
            if (preference !== "")
                entries.push({ label: qsTr("No earlyoom Preference"), icon: "remove",
                               run: () => EarlyOom.clear(process.name) });
        }
        return entries;
    }

    Item {
        anchors.fill: parent

        Label {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.s.xl
            y: (root.barHeight - height) / 2
            text: qsTr("Task Manager")
            role: Label.Role.Subtitle
        }

        Divider {
            id: rule
            anchors.left: parent.left
            anchors.right: parent.right
            y: root.barHeight
        }

        Column {
            id: nav

            anchors.left: parent.left
            anchors.top: rule.bottom
            anchors.leftMargin: Appearance.s.md
            anchors.topMargin: Appearance.s.md
            width: Appearance.m.navWidth - Appearance.s.md * 2
            spacing: Appearance.s.xxs

            Repeater {
                model: root.tabs

                MenuRow {
                    required property var modelData

                    width: nav.width
                    implicitWidth: nav.width
                    implicitHeight: Appearance.m.navRowHeight
                    spacing: Appearance.s.md
                    title: this.modelData.title
                    icon: this.modelData.icon
                    selected: root.tab === this.modelData.key
                    onClicked: root.tab = this.modelData.key
                }
            }
        }

        Divider {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.m.navWidth
            anchors.top: rule.bottom
            anchors.bottom: parent.bottom
            vertical: true
        }

        Loader {
            id: pane

            x: Appearance.m.navWidth
            width: parent.width - x
            height: parent.height
            // Built afresh for every visit: an editor left open, a filter
            // half typed, is not there next time.
            active: root.rendered
            sourceComponent: root.current?.component ?? null
        }
    }

    Component { id: processesPane; ProcessPane { manager: root } }
    Component { id: memoryPane; MemoryPane { manager: root } }
    Component { id: scheduledPane; SchedulePane { manager: root } }
}
