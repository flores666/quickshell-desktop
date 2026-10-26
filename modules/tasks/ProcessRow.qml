pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    One process in the list: its name and what earlyoom makes of it, then
    its user, CPU, memory and OOM score under the headings. Its menu (a right
    click, the Menu key, or the button at its end) is the task manager's
    `menuFor`; another user's process with no earlyoom has none, and no
    button.

    Kept by pid: the process itself is read from Processes as it stands.
*/
Clickable {
    id: root

    required property int modelData
    required property var columns

    readonly property var process: Processes.byPid[root.modelData] ?? null
    readonly property string preference: root.process && EarlyOom.available
        ? EarlyOom.preference(root.process.name) : ""
    readonly property bool next: root.process !== null && root.process.pid === EarlyOom.next
    readonly property bool hasMenu: root.process !== null
        && (root.process.own || (EarlyOom.available && EarlyOomArgs.listable(root.process.name)))

    signal menuRequested(Item row, var process)

    implicitHeight: Appearance.m.navRowHeight
    radius: Appearance.r.sm
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onRightClicked: if (root.hasMenu) root.menuRequested(root, root.process)

    function figure(key: string): string {
        const p = root.process;
        if (p === null)
            return "";
        switch (key) {
        case "user": return p.user;
        case "cpu": return p.cpu < 0 ? "–" : qsTr("%1%").arg(p.cpu.toFixed(1));
        case "rss": return Processes.formatSize(p.rss);
        }
        return String(p[key]);
    }

    Row {
        anchors.fill: parent

        Item {
            width: root.width - root.columns.reduce((sum, c) => sum + c.width, 0) - more.width
            height: root.height

            Row {
                id: badges
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(name.x + name.implicitWidth + Appearance.s.md, parent.width - width)
                spacing: Appearance.s.xs

                Badge {
                    visible: root.next
                    text: qsTr("Next")
                    ink: Appearance.c.danger
                }

                Badge {
                    visible: root.preference === "avoid"
                    text: qsTr("Protected")
                    ink: Appearance.c.success
                }

                Badge {
                    visible: root.preference === "prefer"
                    text: qsTr("Kill first")
                    ink: Appearance.c.warning
                }
            }

            Label {
                id: name
                anchors.verticalCenter: parent.verticalCenter
                x: Appearance.s.sm
                width: Math.min(implicitWidth, badges.x - x - Appearance.s.md)
                text: root.process?.name ?? ""
                elide: Text.ElideRight
            }
        }

        Repeater {
            model: root.columns

            Label {
                required property var modelData

                anchors.verticalCenter: parent.verticalCenter
                width: this.modelData.width
                leftPadding: Appearance.s.sm
                rightPadding: Appearance.s.sm
                horizontalAlignment: this.modelData.key === "user" ? Text.AlignLeft : Text.AlignRight
                text: root.figure(this.modelData.key)
                role: Label.Role.Small
                muted: this.modelData.key === "user" && !(root.process?.own ?? false)
                font.features: { "tnum": 1 }
                elide: Text.ElideRight
            }
        }

        Item {
            id: more
            width: Appearance.m.touchTarget
            height: root.height

            IconButton {
                anchors.centerIn: parent
                visible: root.hasMenu && (root.hovered || root.activeFocus)
                icon: "more"
                size: Appearance.m.touchTarget - Appearance.s.sm
                focusable: false
                onClicked: root.menuRequested(root, root.process)
            }
        }
    }
}
