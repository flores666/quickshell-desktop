pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"

/*!
    The menu of a system-tray item, drawn by the shell rather than handed to the
    platform, so it matches everything else.

    Submenus replace the current level instead of cascading — at this size that
    is easier to hit and needs no positioning logic.
*/
ShellOverlay {
    id: root

    overlayId: Overlay.trayMenu
    cardWidth: 240
    cardHeight: column.implicitHeight + Appearance.s.md * 2

    /*! Menu handles from the root of the item's menu down to the visible level. */
    property var stack: []

    readonly property var entries: opener.children.values.filter(e => e)

    onShownChanged: if (root.shown) root.stack = root.subject?.menu ? [root.subject.menu] : []

    // Emptied only once the surface is gone: resetting it as the popup starts
    // closing would collapse the card in the middle of its fade-out.
    onRenderedChanged: if (!root.rendered) root.stack = []

    QsMenuOpener {
        id: opener
        menu: root.stack.length > 0 ? root.stack[root.stack.length - 1] : null
    }

    function descend(handle: var): void {
        root.stack = root.stack.concat([handle]);
    }

    function ascend(): void {
        root.stack = root.stack.slice(0, -1);
    }

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.s.md
        spacing: 1

        MenuItemRow {
            width: parent.width
            visible: root.stack.length > 1
            icon: "chevron-left"
            label: qsTr("Back")
            onClicked: root.ascend()
        }

        Repeater {
            model: root.entries

            Loader {
                id: entryLoader
                required property var modelData

                width: column.width
                sourceComponent: entryLoader.modelData.isSeparator ? separator : item

                Component {
                    id: separator
                    Item {
                        height: Appearance.s.sm * 2 + 1
                        Divider {
                            width: parent.width
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Component {
                    id: item
                    MenuItemRow {
                        readonly property var entry: entryLoader.modelData

                        label: entry.text
                        enabled: entry.enabled
                        submenu: entry.hasChildren
                        checkable: entry.buttonType !== QsMenuButtonType.None
                        checked: entry.checkState === Qt.Checked

                        onClicked: {
                            if (entry.hasChildren) {
                                root.descend(entry);
                            } else {
                                entry.triggered();
                                Overlay.close();
                            }
                        }
                    }
                }
            }
        }

        Label {
            width: parent.width
            height: 32
            visible: root.entries.length === 0
            text: qsTr("No menu items")
            role: Label.Role.Small
            faint: true
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
