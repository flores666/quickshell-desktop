pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"

/*!
    The dock's context menu: launch another window, pin or unpin, and close what
    is running.  Entries that cannot apply are simply not shown.
*/
ShellOverlay {
    id: root

    overlayId: Overlay.dockMenu
    placement: ShellOverlay.Placement.AboveDock
    cardWidth: 220
    cardHeight: column.implicitHeight + Appearance.s.md * 2

    readonly property var item: root.subject
    /*! The menu has one sub-level: the list of workspaces to send a window to. */
    property bool pickingWorkspace: false

    onRenderedChanged: if (!root.rendered) root.pickingWorkspace = false
    readonly property bool pinned: root.item?.entry ? Settings.isPinned(root.item.entry.id) : false
    readonly property bool launchable: root.item?.entry !== null && root.item?.entry !== undefined
    readonly property string launchLabel: root.item?.running ? qsTr("New Window") : qsTr("Open")

    /*!
        The entry's own actions, minus any that just duplicate the primary one —
        several browsers ship a "New Window" action identical to their default
        command.
    */
    readonly property var extraActions: (root.item?.entry?.actions ?? [])
        .filter(a => a && a.name !== root.launchLabel)

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.s.md
        spacing: 1

        Label {
            width: parent.width
            height: 26
            text: root.pickingWorkspace ? qsTr("Move to Workspace") : (root.item?.name ?? "")
            role: Label.Role.Caption
            faint: true
            leftPadding: Appearance.s.md
        }

        MenuItemRow {
            width: parent.width
            visible: root.pickingWorkspace
            icon: "chevron-left"
            label: qsTr("Back")
            onClicked: root.pickingWorkspace = false
        }

        Repeater {
            model: root.pickingWorkspace ? Compositor.workspaces : []

            MenuItemRow {
                id: wsRow
                required property var modelData

                width: column.width
                label: qsTr("Workspace %1").arg(wsRow.modelData.name)
                checkable: true
                checked: root.item?.toplevel?.workspace?.id === wsRow.modelData.id
                onClicked: {
                    Overlay.close();
                    Compositor.moveWindowToWorkspace(root.item.toplevel, wsRow.modelData.id);
                }
            }
        }

        MenuItemRow {
            width: parent.width
            visible: !root.pickingWorkspace && root.launchable
            icon: "add"
            label: root.launchLabel
            onClicked: {
                Overlay.close();
                Dock.launchNew(root.item);
            }
        }

        Repeater {
            model: root.pickingWorkspace ? [] : root.extraActions

            MenuItemRow {
                id: actionRow
                required property var modelData

                width: column.width
                label: actionRow.modelData.name
                onClicked: {
                    Overlay.close();
                    Apps.launchAction(root.item.entry, actionRow.modelData);
                }
            }
        }

        MenuItemRow {
            width: parent.width
            visible: !root.pickingWorkspace && (root.item?.toplevel ?? null) !== null
            icon: "grid"
            label: qsTr("Move to Workspace")
            submenu: true
            onClicked: root.pickingWorkspace = true
        }

        MenuItemRow {
            width: parent.width
            visible: !root.pickingWorkspace && root.launchable
            icon: "pin"
            label: root.pinned ? qsTr("Unpin from Dock") : qsTr("Pin to Dock")
            onClicked: {
                Overlay.close();
                Dock.togglePinned(root.item);
            }
        }

        MenuItemRow {
            width: parent.width
            visible: !root.pickingWorkspace && (root.item?.running ?? false)
            icon: "close"
            danger: true
            label: qsTr("Close")
            onClicked: {
                Overlay.close();
                Dock.close(root.item);
            }
        }
    }
}
