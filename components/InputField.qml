pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    A line of text to type: a FieldWell with an input in it and a placeholder
    while it is empty. SearchField is the same with a glyph and a clear
    button, for filtering; this is for a value the user is giving.
*/
FieldWell {
    id: root

    property alias text: field.text
    property alias placeholder: placeholderLabel.text
    property alias placeholderColor: placeholderLabel.color
    property alias input: field
    /*! TextInput.Password for a secret: dots in place of what is typed. */
    property alias echoMode: field.echoMode
    /*! Space for controls placed in the well's trailing layer. */
    property real rightInset: Appearance.s.lg

    signal accepted

    focused: field.activeFocus

    TextInput {
        id: field

        anchors.verticalCenter: parent.verticalCenter
        x: Appearance.s.lg
        width: Math.max(0, root.width - x - root.rightInset)
        color: Appearance.c.text
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.font.body
        selectionColor: Appearance.c.accent
        selectedTextColor: Appearance.c.accentText
        selectByMouse: true
        activeFocusOnTab: true
        clip: true
        renderType: Text.NativeRendering
        inputMethodHints: Qt.ImhNoPredictiveText
        passwordCharacter: "•"
        onAccepted: root.accepted()
    }

    Label {
        id: placeholderLabel
        anchors.verticalCenter: parent.verticalCenter
        x: field.x
        width: field.width
        visible: field.text === ""
        elide: Text.ElideRight
        faint: true
    }
}
