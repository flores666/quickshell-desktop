pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*! The card silhouettes share the board's live geometry, scroll clip and paint opacity. */
Item {
    id: root

    required property DailyNotesBoard notesBoard
    required property Flickable viewport
    required property point origin

    Item {
        x: root.origin.x + root.viewport.x
        y: root.origin.y + root.viewport.y
        width: root.viewport.width
        height: root.viewport.height
        clip: true

        Repeater {
            model: ScriptModel { values: [...root.notesBoard.tiles.values()] }

            Rectangle {
                id: silhouette
                required property DailyNoteCategory modelData

                visible: silhouette.modelData.visible
                x: root.viewport.contentItem.x + root.notesBoard.x + silhouette.modelData.x
                y: root.viewport.contentItem.y + root.notesBoard.y + silhouette.modelData.y
                width: silhouette.modelData.width
                height: silhouette.modelData.height
                radius: silhouette.modelData.radius
                color: Qt.rgba(silhouette.modelData.fill.a, 0, 0, 1)
                transform: Matrix4x4 { matrix: silhouette.modelData.cardTransform }
            }
        }
    }
}
