pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*! A single-line search input styled as an inset well. */
FocusScope {
    id: root

    property alias text: input.text
    property alias placeholder: placeholderLabel.text
    property alias input: input

    signal accepted
    signal escaped
    /*! Arrow keys and Tab are forwarded so a results list can own navigation. */
    signal navigate(int key)

    implicitWidth: 320
    implicitHeight: Appearance.m.fieldHeight

    function clear(): void { input.text = ""; }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.r.sm
        color: Appearance.c.sunken
        border.width: 1
        border.color: input.activeFocus ? Appearance.c.accent : Appearance.c.border

        Behavior on border.color {
            ColorAnimation { duration: Appearance.t.fast }
        }
    }

    Icon {
        id: searchIcon
        anchors.verticalCenter: parent.verticalCenter
        x: Appearance.s.lg
        name: "search"
        size: Appearance.m.icon
        color: Appearance.c.textMuted
    }

    TextInput {
        id: input
        anchors.verticalCenter: parent.verticalCenter
        x: searchIcon.x + searchIcon.width + Appearance.s.md
        width: (clearButton.visible ? clearButton.x : root.width - Appearance.s.lg) - x - Appearance.s.md
        focus: true
        color: Appearance.c.text
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.font.body
        selectionColor: Appearance.c.accent
        selectedTextColor: Appearance.c.accentText
        selectByMouse: true
        clip: true
        renderType: Text.NativeRendering
        inputMethodHints: Qt.ImhNoPredictiveText

        onAccepted: root.accepted()

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                InputMode.keyboardUsed();
                root.escaped();
                event.accepted = true;
                break;
            case Qt.Key_Down:
            case Qt.Key_Up:
            case Qt.Key_Tab:
            case Qt.Key_Backtab:
            case Qt.Key_PageDown:
            case Qt.Key_PageUp:
                InputMode.keyboardUsed();
                root.navigate(event.key);
                event.accepted = true;
                break;
            default:
                if (event.text !== "")
                    InputMode.keyboardUsed();
                break;
            }
        }
    }

    Label {
        id: placeholderLabel
        anchors.verticalCenter: parent.verticalCenter
        x: input.x
        width: input.width
        visible: input.text === ""
        faint: true
    }

    IconButton {
        id: clearButton
        anchors.verticalCenter: parent.verticalCenter
        x: root.width - width - Appearance.s.sm
        visible: input.text !== ""
        icon: "clear"
        size: 26
        iconSize: Appearance.m.iconSm
        focusable: false
        onClicked: {
            root.clear();
            input.forceActiveFocus();
        }
    }
}
