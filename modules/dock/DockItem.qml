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

    implicitWidth: Appearance.m.dockCell
    implicitHeight: Appearance.m.dockCell
    radius: Appearance.r.md
    focusable: false
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    selected: root.item.active

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
