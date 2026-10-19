pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    One window in the dock's preview: its title over a live picture of it, and
    a button that closes it, shown while the pointer is on the window.

    The picture is the window as the compositor draws it, on another workspace
    too, and streams only for as long as this exists — the preview makes these
    only while it is open. Until the first frame arrives, or where the
    compositor cannot capture a window, the box holds the application's icon.
*/
Clickable {
    id: root

    required property HyprlandToplevel window
    required property string icon
    required property int boxWidth
    required property int boxHeight

    // Over the whole window, its close button included, which the Clickable's
    // own hover is not: the button shows only while the pointer is here.
    HoverHandler { id: pointer }

    radius: Appearance.r.md
    focusable: false
    implicitWidth: root.boxWidth + Appearance.s.sm * 2
    implicitHeight: column.implicitHeight + Appearance.s.sm * 2

    Column {
        id: column

        x: Appearance.s.sm
        y: Appearance.s.sm
        spacing: Appearance.s.sm

        Row {
            height: Appearance.m.iconLg
            spacing: Appearance.s.sm

            AppIcon {
                anchors.verticalCenter: parent.verticalCenter
                source: root.icon
                size: Appearance.m.icon
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: root.boxWidth - Appearance.m.icon - closeButton.width - Appearance.s.sm * 2
                text: root.window?.title ?? ""
                role: Label.Role.Small
                elide: Text.ElideRight
            }

            IconButton {
                id: closeButton
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                size: Appearance.m.iconLg
                iconSize: Appearance.m.iconSm
                focusable: false
                // Faded rather than hidden, so the title beside it keeps its
                // width; Clickable eases the fade.
                opacity: pointer.hovered ? 1 : 0
                onClicked: Compositor.closeWindow(root.window)
            }
        }

        Rectangle {
            width: root.boxWidth
            height: root.boxHeight
            radius: Appearance.r.xs
            color: Appearance.c.sunken

            ScreencopyView {
                id: picture

                anchors.centerIn: parent
                captureSource: root.window?.wayland ?? null
                live: true
                constraintSize: Qt.size(root.boxWidth, root.boxHeight)
                visible: picture.hasContent
            }

            AppIcon {
                anchors.centerIn: parent
                visible: !picture.hasContent
                source: root.icon
                size: Appearance.m.iconXl
            }
        }
    }
}
