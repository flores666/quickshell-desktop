pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*! One application in the dock: its icon in the slot every dock item has
    (see Metrics), a dot under it for each window it has open, and the slot's
    highlight while one of them has focus. */
Clickable {
    id: root

    required property var item
    required property ShellScreen screen

    /*! Whether one of its windows has focus; read here, not in the model. */
    readonly property bool active: root.item.windows.some(w => w?.activated ?? false)
    /*! Reported to the dock, which owns the tooltip and the preview. */
    signal hoverChanged(string key, string label, real centerX, bool entered)

    /*! How far the dock wants this icon shifted to make room for a drag. */
    property real slide: 0
    /*! Whether a drag is still in flight somewhere in the dock. */
    property bool rearranging: false
    readonly property bool dragging: dragging_.active
    /*!
        How far the icon has been carried, measured from where the drag became
        active. `activeTranslation` cannot be used for this: it counts from the
        press, so it opens a whole drag threshold wide — 15px, measured — and
        the icon would leap that far sideways the moment it is picked up.
    */
    readonly property real dragX: dragging_.centroid.scenePosition.x - root.dragOrigin
    /*! Where the pointer was when the drag became active. */
    property real dragOrigin: 0

    signal dragMoved(real dx)
    signal dragEnded

    implicitWidth: Appearance.m.dockSlot
    implicitHeight: Appearance.m.dockSlot
    // Round, so at either end of the row the highlight is concentric with the
    // dock's round edge.
    radius: Appearance.r.capsule(Appearance.m.dockSlot)
    focusable: false
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    selected: root.active

    // Above its neighbours while it is being carried, so it is never clipped by
    // the icon it is passing over.
    z: root.dragging ? 1 : 0

    transform: Translate {
        x: root.dragging ? root.dragX : root.slide

        Behavior on x {
            // Only while a drag is in flight, and never for the icon under the
            // pointer — that one has to track the hand exactly. At the drop the
            // dock's order changes in the same frame, so every offset has to
            // vanish with it; animating them away instead leaves the icons
            // sliding out of a layout that no longer exists.
            enabled: root.rearranging && !root.dragging
            NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
        }
    }

    /*!
        Rearranging the dock. `target: null` because the icon is moved by the
        transform above, which leaves the Row's layout alone — the dock decides
        where the icon lands, and only when the drag ends.
    */
    DragHandler {
        id: dragging_

        target: null
        yAxis.enabled: false
        cursorShape: Qt.ClosedHandCursor
        onActiveChanged: {
            if (dragging_.active)
                root.dragOrigin = dragging_.centroid.scenePosition.x;
            else
                root.dragEnded();
        }
        onCentroidChanged: if (dragging_.active) root.dragMoved(root.dragX)
    }

    onClicked: Dock.activate(root.item)
    onMiddleClicked: Dock.launchNew(root.item)
    onRightClicked: {
        const surface = root.QsWindow.contentItem;
        Overlay.anchorX = surface ? root.mapToItem(surface, root.width / 2, 0).x : 0;
        Overlay.openWith(Overlay.dockMenu, root.screen, root.item);
    }

    onHoveredChanged: root.hoverChanged(root.item.key, root.item.name,
        root.mapToItem(root.parent.parent, root.width / 2, 0).x, root.hovered)

    AppIcon {
        id: icon
        x: Appearance.m.dockInset
        y: Appearance.m.dockInset
        source: root.item.icon
        size: Appearance.m.dockIcon
        optical: true
        scale: root.down ? 0.9 : root.hovered ? 1.06 : 1

        Behavior on scale {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }
    }

    // A dot for each window, three at most, just under the slot. Which
    // application has focus is the highlight's to say, so the dots only ever
    // count.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height + Appearance.m.dockDotGap
        spacing: Appearance.s.xs

        Repeater {
            model: Math.min(root.item.windows.length, 3)

            Rectangle {
                width: Appearance.m.dockDot
                height: Appearance.m.dockDot
                radius: Appearance.m.dockDot / 2
                color: Appearance.c.text
            }
        }
    }
}
