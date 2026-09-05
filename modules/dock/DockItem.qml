pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*! One application in the dock, with its running and focused indicators. */
Clickable {
    id: root

    required property var item
    required property ShellScreen screen

    /*!
        What the hover tooltip says. Several windows of one application need
        telling apart, so it names the window as well as the application; the
        title is read here rather than in the dock model so a changing title
        costs one binding instead of a model rebuild.
    */
    readonly property string label: {
        if (!root.item.grouped)
            return root.item.name;
        const title = String(root.item.toplevel?.title ?? "");
        return title !== "" ? `${root.item.name} — ${title.slice(0, 60)}` : root.item.name;
    }
    /*! Reported to the dock, which owns the one shared tooltip. */
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

    implicitWidth: Appearance.m.dockCell
    implicitHeight: Appearance.m.dockCell
    radius: Appearance.r.md
    focusable: false
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    selected: root.item.active

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

    onHoveredChanged: root.hoverChanged(root.item.key, root.label,
        root.mapToItem(root.parent.parent, root.width / 2, 0).x, root.hovered)

    AppIcon {
        id: icon
        anchors.horizontalCenter: parent.horizontalCenter
        y: Appearance.m.dockPadding - 1
        source: root.item.icon
        size: Appearance.m.dockIcon
        scale: root.down ? 0.9 : root.hovered ? 1.06 : 1

        Behavior on scale {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }
    }

    // Running / focused indicator.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        width: root.item.active ? 14 : root.item.running ? 4 : 0
        height: 3
        radius: 1.5
        color: root.item.active ? Appearance.c.accent : Appearance.c.textFaint

        Behavior on width {
            NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
        }
        Behavior on color {
            ColorAnimation { duration: Appearance.t.fast }
        }
    }
}
