pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import "root:/config"
import "root:/components"
import "root:/services"

/*! The pictures in the wallpaper folder, and which of them is up. */
Column {
    id: root

    spacing: Appearance.s.lg

    Filmstrip {
        id: strip

        width: root.width
        cellHeight: 84
        visible: Wallpaper.available
        model: Wallpaper.items
        currentIndex: Math.max(0, Wallpaper.items.indexOf(Wallpaper.current))

        delegate: Clickable {
            id: tile

            required property string modelData

            implicitWidth: 132
            height: strip.cellHeight
            radius: Appearance.r.md
            focusable: false
            showStateLayer: false
            /*! The strip is a Flickable, so without this a click that drifts a
                few pixels is taken for a scroll — the same reason a launcher
                tile keeps the press it was given. */
            preventStealing: true
            selected: tile.modelData === Wallpaper.current
            onClicked: Wallpaper.set(tile.modelData)

            ClippingRectangle {
                anchors.fill: parent
                radius: Appearance.r.md
                color: Appearance.c.sunken
                scale: tile.down ? 0.96 : 1
                border.width: tile.selected ? 2 : Appearance.m.border
                border.color: tile.selected ? Appearance.c.accent
                    : tile.hovered ? Appearance.c.borderStrong : Appearance.c.border

                Behavior on scale {
                    NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
                }

                Image {
                    anchors.fill: parent
                    source: "file://" + tile.modelData
                    fillMode: Image.PreserveAspectCrop
                    // Twice the tile, so it stays sharp on a scaled screen and
                    // no further: these are thumbnails of 4K photographs.
                    sourceSize.width: 264
                    asynchronous: true
                    cache: true
                }
            }
        }
    }

    Label {
        width: root.width
        text: !Wallpaper.available
            ? qsTr("Put pictures in %1 and they show up here.").arg(Wallpaper.folderPath)
            : strip.overflowing
                ? qsTr("Pictures come from %1. Scroll sideways for the rest.").arg(Wallpaper.folderPath)
                : qsTr("Pictures come from %1.").arg(Wallpaper.folderPath)
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }

    Label {
        width: root.width
        text: qsTr("The choice is remembered and set again at login; the wallpaper daemon forgets it on its own.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
