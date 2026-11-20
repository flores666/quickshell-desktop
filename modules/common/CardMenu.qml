pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The context menu of the popup that is open: whatever Overlay.menu asks
    for, drawn over the card beside the item it was opened on.

    It is part of the card rather than a popup of its own because only one
    popup is ever open, and it sits above the card's content rather than in it
    because the content clips: a menu opened near the edge of a pane would be
    cut off by the very list it belongs to. While it is up, a press anywhere
    else on the card only closes it, which is how a menu behaves anywhere, and
    nothing under it is hovered.

    It is the one panel drawn over the shell's own content, where the
    compositor's blur does not reach: so it is opaque, not glass, and edged
    and shadowed like a window to stand off the card it lies on.
*/
Item {
    id: root

    /*! Whether the popup this card belongs to is the one open. */
    required property bool active
    signal backgroundPressed(point scenePosition)

    readonly property var menu: root.active ? Overlay.menu : null
    /*! The item it opens beside goes with its delegate; the menu goes too. */
    readonly property bool open: root.menu !== null && (root.menu.source ?? null) !== null
    readonly property Item customItem: custom.item as Item

    visible: root.open

    /*! Where to return focus as the menu goes away, supplied by content
        menus or remembered when opening a menu with the keyboard. */
    property Item returnFocus: null

    onMenuChanged: {
        const request = root.menu;
        if (!request?.source)
            return;
        if (request.content)
            root.returnFocus = request.returnFocus;
        else if (InputMode.keyboard)
            root.returnFocus = root.returnFocus ?? root.Window.activeFocusItem;
        else
            return;
        Qt.callLater(() => {
            if (root.menu === request)
                (request.content ? root.customItem : rows.itemAt(0))?.forceActiveFocus();
        });
    }

    onOpenChanged: if (!root.open) {
        if (root.active)
            root.returnFocus?.forceActiveFocus();
        root.returnFocus = null;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        // Takes the hover from what lies under the menu (Qt hovers the topmost
        // item and its ancestors, never the siblings beneath), so crossing to a
        // row lights nothing on the way — a launcher tile under the pointer
        // would also take the selection. A MouseArea passes hover on to its
        // ancestors, so the card still knows the pointer is over it.
        hoverEnabled: true
        onPressed: mouse => {
            if (panel.contains(panel.mapFromItem(root, mouse.x, mouse.y)))
                return;
            const scenePosition = root.mapToItem(null, mouse.x, mouse.y);
            Overlay.closeMenu();
            root.backgroundPressed(scenePosition);
        }
        onWheel: event => {
            // A list can leave the gesture unhandled at its edges or between
            // columns. Keep that scroll inside the custom menu's surface.
            event.accepted = root.customItem !== null && panel.contains(panel.mapFromItem(root, event.x, event.y));
            if (!event.accepted)
                Overlay.closeMenu();
        }
    }

    Surface {
        id: panel

        /*! Where the item it was opened on sits on the card, taken once. */
        readonly property rect at: root.open
            ? root.menu.source.mapToItem(root, 0, 0, root.menu.source.width, root.menu.source.height)
            : Qt.rect(0, 0, 0, 0)
        readonly property var cursor: root.menu?.scenePosition
        readonly property point anchor: panel.cursor
            ? root.mapFromItem(null, panel.cursor.x, panel.cursor.y) : Qt.point(panel.at.x, panel.at.y)
        readonly property int edge: Appearance.s.md
        readonly property real above: panel.anchor.y - panel.height - Appearance.s.xs
        readonly property real below: panel.anchor.y + (panel.cursor ? 0 : panel.at.height) + Appearance.s.xs

        // Give pointer menus priority above the cursor and item menus room below their source.
        x: Math.max(panel.edge, Math.min(root.width - panel.width - panel.edge, panel.anchor.x))
        y: panel.cursor && panel.above >= panel.edge ? panel.above
            : panel.below + panel.height <= root.height - panel.edge ? panel.below
            : Math.max(panel.edge, panel.above)
        width: root.customItem ? Math.max(0, Math.min(root.width - panel.edge * 2,
            root.customItem.implicitWidth + Appearance.s.xs * 2)) : Appearance.m.menuWidth
        height: root.customItem ? Math.max(0, Math.min(root.height - panel.edge * 2,
            root.customItem.implicitHeight + Appearance.s.xs * 2)) : column.implicitHeight + Appearance.s.xs * 2
        radius: Appearance.r.md
        color: Appearance.c.surface
        borderColor: Appearance.c.borderStrong
        elevation: 3

        Loader {
            id: custom
            anchors.fill: parent
            anchors.margins: Appearance.s.xs
            active: root.open
            sourceComponent: root.menu?.content ?? null
        }

        Column {
            id: column

            x: Appearance.s.xs
            y: Appearance.s.xs
            width: parent.width - Appearance.s.xs * 2

            Repeater {
                id: rows

                model: root.menu?.entries ?? []

                MenuItemRow {
                    id: row
                    required property var modelData

                    width: column.width
                    label: row.modelData.label
                    icon: row.modelData.icon ?? ""
                    danger: row.modelData.danger ?? false
                    focusable: InputMode.keyboard
                    onClicked: {
                        // Closed first: the action may well remove the item
                        // the menu was opened on.
                        const run = row.modelData.run;
                        Overlay.closeMenu();
                        run();
                    }
                }
            }
        }
    }
}
