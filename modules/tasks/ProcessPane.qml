pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Every process, as a table: a search field above it, and its columns'
    headings sort it — CPU, highest first, to begin with. Disk is a process's
    reads and writes a second, readable for the user's own processes alone
    ("–" for another's). The row earlyoom would stop next is marked, as are
    the names it spares and takes first.

    The rows are kept by pid (ScriptModel), so a new sample moves rows rather
    than building them again, and each row reads its process as it stands.
*/
Item {
    id: root

    property var manager: null

    property string sortKey: "cpu"
    property bool descending: true

    /*! The columns after the name: key, heading, width. */
    readonly property var columns: [
        { key: "cpu", title: qsTr("CPU"), width: Appearance.m.figureColumn },
        { key: "rss", title: qsTr("Memory"), width: Appearance.m.wideColumn },
        { key: "io", title: qsTr("Disk"), width: Appearance.m.wideColumn },
        { key: "pid", title: qsTr("PID"), width: Appearance.m.figureColumn }
    ]

    readonly property var pids: {
        const needle = filter.text.trim().toLowerCase();
        const key = root.sortKey;
        const sign = root.descending ? -1 : 1;
        return Processes.list
            .filter(p => needle === "" || p.name.toLowerCase().includes(needle)
                || p.user.toLowerCase().includes(needle) || String(p.pid).startsWith(needle))
            .sort((a, b) => sign * (typeof a[key] === "string" ? a[key].localeCompare(b[key]) : a[key] - b[key])
                || a.pid - b.pid)
            .map(p => p.pid);
    }

    function sortBy(key: string): void {
        if (root.sortKey === key) {
            root.descending = !root.descending;
        } else {
            root.sortKey = key;
            // Words read best from A, figures from the largest.
            root.descending = key !== "name";
        }
    }

    Label {
        x: Appearance.s.xl
        y: (root.manager.barHeight - height) / 2
        text: qsTr("Processes")
        role: Label.Role.Subtitle
    }

    SearchField {
        id: filter
        x: Appearance.s.xl
        y: root.manager.barHeight + Appearance.s.lg
        width: root.width - Appearance.s.xl * 2
        placeholder: qsTr("Search processes…")
        onEscaped: Overlay.close()
    }

    Row {
        id: headings

        x: Appearance.s.md
        anchors.top: filter.bottom
        anchors.topMargin: Appearance.s.sm
        width: list.rowWidth

        ColumnHeading {
            width: headings.width - root.columns.reduce((sum, c) => sum + c.width, 0) - Appearance.m.touchTarget
            title: qsTr("Name")
            alignRight: false
            active: root.sortKey === "name"
            descending: root.descending
            onClicked: root.sortBy("name")
        }

        Repeater {
            model: root.columns

            ColumnHeading {
                required property var modelData

                width: this.modelData.width
                title: this.modelData.title
                active: root.sortKey === this.modelData.key
                descending: root.descending
                onClicked: root.sortBy(this.modelData.key)
            }
        }
    }

    ListView {
        id: list

        x: Appearance.s.md
        anchors.top: headings.bottom
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.s.md
        width: root.width - Appearance.s.md * 2
        clip: true

        /*! Clear of the scrollbar, which floats over the list's edge. */
        readonly property real rowWidth: list.width - scrollbar.footprint
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel { values: root.pids }

        delegate: ProcessRow {
            width: list.rowWidth
            columns: root.columns
            onMenuRequested: (row, process) => {
                const entries = root.manager.menuFor(process, EarlyOom.available, EarlyOom.preference(process.name));
                if (entries.length > 0)
                    Overlay.openMenu(row, entries);
            }
        }
    }

    Label {
        anchors.centerIn: list
        visible: Processes.samples > 0 && root.pids.length === 0
        text: qsTr("Nothing matches")
        muted: true
    }

    ThinScrollBar { id: scrollbar; flickable: list }
}
