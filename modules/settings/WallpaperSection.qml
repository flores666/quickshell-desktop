pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import "root:/config"
import "root:/components"
import "root:/services"

/*! The pictures in the wallpaper folder, and which of them is up: the one up
    shown large, every one of them in a strip beneath it. */
Column {
    id: root

    spacing: Appearance.s.md

    // The pane is built afresh on every visit, so this is every time it shows.
    Component.onCompleted: Wallpaper.rescan()

    ClippingRectangle {
        width: root.width
        height: Math.round(root.width * 9 / 16)
        visible: Wallpaper.current !== ""
        radius: Appearance.r.lg
        color: Appearance.c.sunken
        border.width: Appearance.m.border
        border.color: Appearance.c.border

        Image {
            anchors.fill: parent
            source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            // Twice the pane, as for the thumbnails: sharp on a scaled screen,
            // and no 4K decode for a picture this size.
            sourceSize.width: root.width * 2
            asynchronous: true
            cache: true
        }
    }

    Filmstrip {
        id: strip

        width: root.width
        cellHeight: 72
        visible: Wallpaper.available
        model: Wallpaper.items
        currentIndex: Math.max(0, Wallpaper.items.indexOf(Wallpaper.current))

        delegate: Clickable {
            id: tile

            required property string modelData

            implicitWidth: 120
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
                    sourceSize.width: 240
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
