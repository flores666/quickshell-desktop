pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "root:/config"
import "root:/components"
import "root:/services"

/*! StatusNotifierItem tray icons. Collapses to nothing when the tray is empty. */
Row {
    id: root

    required property ShellScreen screen
    /*! The colours its icons are drawn in (Bar). */
    property ColorScheme scheme: Appearance.c

    readonly property var items: SystemTray.items.values
        .filter(i => i && i.status !== Status.Passive)

    spacing: 0
    visible: root.items.length > 0

    Repeater {
        model: root.items

        Clickable {
            id: entry

            required property SystemTrayItem modelData

            implicitWidth: Appearance.m.barItemHeight
            implicitHeight: Appearance.m.barItemHeight
            radius: Appearance.r.capsule(Appearance.m.barItemHeight)
            focusable: false
            scheme: root.scheme
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            selected: Overlay.isOpen(Overlay.trayMenu) && Overlay.payload === entry.modelData

            onClicked: {
                if (entry.modelData.onlyMenu || !entry.modelData.hasMenu)
                    entry.openMenuOrActivate();
                else
                    entry.modelData.activate();
            }
            onRightClicked: entry.openMenuOrActivate()
            onMiddleClicked: entry.modelData.secondaryActivate()

            function openMenuOrActivate(): void {
                if (!entry.modelData.hasMenu) {
                    entry.modelData.activate();
                    return;
                }
                const surface = entry.QsWindow.contentItem;
                Overlay.openWith(Overlay.trayMenu, root.screen,
                    surface ? entry.mapToItem(surface, entry.width / 2, 0).x : 0, entry.modelData);
            }

            AppIcon {
                anchors.centerIn: parent
                source: entry.modelData.icon
                size: Appearance.m.icon
                fallbackIcon: "settings"
                // Applications ship their tray icons in their own brand colours,
                // which is the one place the bar would carry any, and most of
                // them light, for a dark panel. In the bar's ink they read as
                // part of the same set of glyphs as the rest of it, on the
                // wallpaper the bar's text is chosen for, their shapes as
                // legible as the author drew them.
                ink: root.scheme.text
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: event => entry.modelData.scroll(event.angleDelta.y, false)
            }
        }
    }
}
