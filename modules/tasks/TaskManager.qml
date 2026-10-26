pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"

/*!
    The task manager: what runs (Processes); how busy the machine is, a
    minute of it charted (Performance), its disk, its network and its GPU;
    memory and earlyoom, which stops what uses the most of it before the
    machine runs out (Memory); and the commands systemd runs on a schedule
    (Scheduled). The GPU's tab is there only while a GPU reports how busy it
    is (Usage.hasGpu), and one shown as the GPU goes gives way to Processes.

    Laid out as the settings panel is, tabs down the left and one pane on the
    right, each pane drawing its own title in the bar along the top above the
    rule.

    The machine's readings are kept always (Usage), so every chart opens
    with the last minute in it; each process is read only while a tab that
    lists processes is on screen: Processes, Disk's most active and Memory's
    next victim. Opens on Processes, wherever it was left, or on the tab its
    subject names (`{ tab }`, the date menu's cards) where it has that tab.
*/
ShellOverlay {
    id: root

    overlayId: Overlay.taskManager
    placement: ShellOverlay.Placement.Centre
    cardWidth: Math.min(Appearance.m.paneCardWidth, (root.screen ? root.screen.width : 1920) - Appearance.s.huge * 2)
    cardHeight: Math.min(Appearance.m.paneCardHeight, (root.screen ? root.screen.height : 1080) - Appearance.s.huge * 3)

    readonly property var tabs: [
        { key: "processes", title: qsTr("Processes"), icon: "cat-system", component: processesPane },
        { key: "performance", title: qsTr("Performance"), icon: "performance", component: performancePane },
        { key: "disk", title: qsTr("Disk"), icon: "disk", component: diskPane },
        { key: "network", title: qsTr("Network"), icon: "network-transfer", component: networkPane },
        { key: "gpu", title: qsTr("GPU"), icon: "gpu", component: gpuPane },
        { key: "memory", title: qsTr("Memory"), icon: "computer", component: memoryPane },
        { key: "scheduled", title: qsTr("Scheduled"), icon: "calendar", component: scheduledPane }
    ].filter(t => t.key !== "gpu" || Usage.hasGpu)
    property string tab: "processes"
    readonly property var current: root.tabs.find(t => t.key === root.tab)
    /*! The pane shown, loaded afresh for every tab and every visit. */
    readonly property alias pane: pane

    /*! Where the rule under the panes' bars runs. */
    readonly property int barHeight: Appearance.m.fieldHeight + Appearance.s.lg * 2

    /*! Whether a tab that lists processes is on screen. */
    readonly property bool listing: root.shown && ["processes", "disk", "memory"].includes(root.tab)

    onListingChanged: Processes.watch("taskManager", root.listing)
    Component.onDestruction: Processes.watch("taskManager", false)

    /*! Whether the pane is built: from a moment after the card comes up, so
        that a subject naming a tab, handed over just after the open, is in
        first. Built for Processes and thrown away at once, the list left
        rows half made, and said so in the log. */
    property bool building: false

    onRenderedChanged: {
        if (root.rendered) {
            Qt.callLater(() => root.building = root.rendered);
        } else {
            root.building = false;
            root.tab = "processes";
        }
    }
    // The subject is held from the open until the card goes, so one naming a
    // tab is heard once, as it comes.
    onSubjectChanged: if (root.subject?.tab)
        root.show(root.subject.tab)
    onTabsChanged: root.show(root.tab)

    /*! Shows a tab, or Processes for one it does not have (the GPU's, with
        no GPU). */
    function show(key: string): void {
        root.tab = root.tabs.some(t => t.key === key) ? key : "processes";
    }

    /*! A percentage as the panes show one, "–" before there is a reading. */
    function percent(value: real): string {
        return value < 0 ? "–" : qsTr("%1%").arg(Math.round(value));
    }

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
            active: root.building
            sourceComponent: root.current?.component ?? null
        }
    }

    Component { id: processesPane; ProcessPane { manager: root } }
    Component { id: performancePane; PerformancePane { manager: root } }
    Component { id: diskPane; DiskPane { manager: root } }
    Component { id: networkPane; NetworkPane { manager: root } }
    Component { id: gpuPane; GpuPane { manager: root } }
    Component { id: memoryPane; MemoryPane { manager: root } }
    Component { id: scheduledPane; SchedulePane { manager: root } }
}
