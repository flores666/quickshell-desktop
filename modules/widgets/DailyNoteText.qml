pragma ComponentBehavior: Bound

import QtQuick
import "root:/components"
import "root:/services"

Item {
    id: root

    property Component editor: null
    property real minimumHeight: 0
    property bool strikeout: false
    property alias labelName: label.objectName
    property alias text: label.text
    property alias role: label.role
    property alias muted: label.muted
    readonly property Item input: (loader.item as DailyNoteEditor)?.input ?? null
    signal editRequested

    implicitHeight: Math.max(root.minimumHeight, root.editor ? loader.implicitHeight : label.implicitHeight)
    height: implicitHeight

    Label {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        width: root.width
        visible: !root.editor
        font.strikeout: root.strikeout
        wrapMode: Text.Wrap
        elide: Text.ElideNone

        MouseArea {
            anchors.fill: parent
            onPressed: InputMode.pointerUsed()
            onDoubleClicked: root.editRequested()
        }
    }

    Loader {
        id: loader
        anchors.verticalCenter: parent.verticalCenter
        width: root.width
        sourceComponent: root.editor
    }
}
