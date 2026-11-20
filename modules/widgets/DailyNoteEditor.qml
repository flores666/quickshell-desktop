pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

Item {
    id: root

    required property var draft
    property var annotationSnapshot
    readonly property bool editingAnnotation: !!root.draft?.annotation
    readonly property alias input: taskTitle
    signal finished

    implicitHeight: taskTitle.implicitHeight

    function persistAnnotation(annotation: var, text: string): bool {
        if (text === "") {
            // Clearing a new draft can undo its own autosave. Existing notes
            // retain their last valid text and are deleted through their menu.
            if (annotation.index < (annotation.snapshot?.length ?? 0))
                return false;
            if (annotation.index === (root.annotationSnapshot?.length ?? 0))
                return true;
        }
        if (!DailyNotes.saveAnnotation(root.draft.id, root.annotationSnapshot, annotation.index, text === "" ? null : text))
            return false;
        root.annotationSnapshot = DailyNotes.find(root.draft.id).annotations;
        return true;
    }

    function persist(): bool {
        const text = taskTitle.text.trim();
        if (root.editingAnnotation)
            return root.persistAnnotation(root.draft.annotation, text);
        if (text === "")
            return false;
        const note = DailyNotes.find(root.draft?.id ?? "");
        if (!note)
            return false;
        return DailyNotes.save(note.day, note.id, text, note.deadline);
    }

    TextEdit {
        id: taskTitle
        property bool initialized: false
        objectName: root.editingAnnotation ? "taskAnnotationInput" : "noteTitle"
        width: root.width
        height: implicitHeight
        color: Appearance.c.text
        font.family: Appearance.fontFamily
        font.pixelSize: root.editingAnnotation ? Appearance.font.small : Appearance.font.body
        selectionColor: Appearance.c.accent
        selectedTextColor: Appearance.c.accentText
        selectByMouse: true
        activeFocusOnTab: true
        textFormat: TextEdit.PlainText
        wrapMode: TextEdit.Wrap
        renderType: Text.NativeRendering
        Accessible.name: root.editingAnnotation ? qsTr("Task note") : qsTr("Task name")

        Component.onCompleted: {
            root.annotationSnapshot = root.draft?.annotation?.snapshot;
            taskTitle.text = root.draft?.text ?? "";
            taskTitle.initialized = true;
        }
        onTextChanged: if (taskTitle.initialized) root.persist()
        Keys.onPressed: event => {
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                if (root.persist())
                    root.finished();
                event.accepted = true;
            }
        }

        Label {
            anchors.fill: parent
            visible: taskTitle.text === ""
            text: root.editingAnnotation ? qsTr("Enter a note.") : qsTr("Enter a task name.")
            role: root.editingAnnotation ? Label.Role.Small : Label.Role.Body
            color: root.editingAnnotation ? Appearance.c.textMuted : PopupStyle.danger
        }
    }
}
