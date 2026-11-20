pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    id: root

    required property var task
    required property Item returnFocus
    property var draft: null
    property Component editor: null
    signal editRequested(int index)

    readonly property var entries: root.task?.annotations ?? []
    readonly property int editingIndex: root.draft?.index ?? -1
    readonly property int slotCount: Math.max(root.entries.length, root.editingIndex + 1)

    visible: root.slotCount > 0
    spacing: Appearance.s.xxs

    function openActions(source: Item, index: int, event: var): void {
        if (!Overlay.isOpen(Overlay.dailyNotes))
            return;
        // Pair the index with its list so duplicate text and stale positions cannot target a different note.
        const id = root.task.id;
        const snapshot = root.task.annotations;
        const position = event ? source.mapToItem(null, event.x, event.y) : undefined;
        Overlay.openMenu(source, [
            { label: qsTr("Edit note"), icon: "settings", run: () => {
                if (root.task?.id === id && root.task.annotations === snapshot)
                    root.editRequested(index);
            } },
            { label: qsTr("Delete note"), icon: "trash", danger: true, run: () => {
                root.returnFocus.forceActiveFocus();
                DailyNotes.saveAnnotation(id, snapshot, index, null);
            } }
        ], position);
    }

    Repeater {
        // The draft occupies its slot before the first save, keeping the editor and its caret in place.
        model: root.slotCount

        Clickable {
            id: annotation

            required property int index
            readonly property bool editing: annotation.index === root.editingIndex
            readonly property string text: root.entries[annotation.index] ?? ""

            width: root.width
            height: contents.implicitHeight
            acceptedButtons: annotation.editing ? Qt.NoButton : Qt.RightButton
            focusable: !annotation.editing
            showStateLayer: !annotation.editing
            cursorShape: Qt.ArrowCursor
            Accessible.role: annotation.editing ? Accessible.Grouping : Accessible.Button
            Accessible.name: annotation.text
            Accessible.description: qsTr("Open note actions")
            Accessible.onPressAction: root.openActions(annotation, annotation.index, null)
            onClicked: root.openActions(annotation, annotation.index, null)
            onRightClicked: event => root.openActions(annotation, annotation.index, event)

            Row {
                id: contents
                width: annotation.width
                spacing: Appearance.s.xs

                Label {
                    id: bullet
                    text: "•"
                    role: Label.Role.Small
                    muted: true
                    Accessible.ignored: true
                }

                DailyNoteText {
                    width: Math.max(0, contents.width - bullet.width - contents.spacing)
                    labelName: "taskAnnotation"
                    text: annotation.text
                    role: Label.Role.Small
                    muted: true
                    editor: annotation.editing ? root.editor : null
                    onEditRequested: root.editRequested(annotation.index)
                }
            }
        }
    }
}
