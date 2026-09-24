pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    Asks for a Wi-Fi password: to join a network for the first time, to try
    again after the one given was turned away, or to replace a saved one.
*/
Column {
    id: root

    property string networkName: ""
    /*! Replacing a saved password rather than joining. */
    property bool changing: false
    /*! Why the last attempt failed; empty on a first ask. */
    property string reason: ""

    signal accepted(string psk)
    signal cancelled

    /*! Empties the field and puts the cursor in it. */
    function open(): void {
        psk.text = "";
        reveal.selected = false;
        Qt.callLater(() => psk.forceActiveFocus());
    }

    function confirm(): void {
        if (psk.text.length < 8)
            return;
        const value = psk.text;
        psk.text = "";
        root.accepted(value);
    }

    spacing: Appearance.s.lg

    Label {
        width: parent.width
        text: root.changing ? qsTr("New password for “%1”").arg(root.networkName)
            : qsTr("Enter the password for “%1”").arg(root.networkName)
        role: Label.Role.Small
        muted: true
        wrapMode: Text.Wrap
    }

    Label {
        width: parent.width
        visible: root.reason !== ""
        text: root.reason
        role: Label.Role.Small
        color: Appearance.c.danger
        wrapMode: Text.Wrap
    }

    Item {
        width: parent.width
        height: Appearance.m.fieldHeight

        Rectangle {
            anchors.fill: parent
            radius: Appearance.r.sm
            color: Appearance.c.sunken
            border.width: 1
            border.color: psk.activeFocus ? Appearance.c.accent : Appearance.c.border
        }

        TextInput {
            id: psk

            anchors.fill: parent
            anchors.leftMargin: Appearance.s.lg
            anchors.rightMargin: Appearance.s.lg
            verticalAlignment: TextInput.AlignVCenter
            echoMode: reveal.selected ? TextInput.Normal : TextInput.Password
            passwordCharacter: "•"
            color: Appearance.c.text
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.font.body
            selectionColor: Appearance.c.accent
            selectedTextColor: Appearance.c.accentText
            clip: true
            renderType: Text.NativeRendering
            onAccepted: root.confirm()
        }
    }

    Row {
        width: parent.width
        spacing: Appearance.s.md

        IconButton {
            id: reveal
            icon: reveal.selected ? "conceal" : "reveal"
            size: 34
            selected: false
            onClicked: reveal.selected = !reveal.selected
        }

        Item {
            width: parent.width - reveal.width - cancel.width - confirmButton.width - parent.spacing * 3
            height: 1
        }

        TextButton {
            id: cancel
            text: qsTr("Cancel")
            onClicked: root.cancelled()
        }

        TextButton {
            id: confirmButton
            text: root.changing ? qsTr("Save") : qsTr("Connect")
            kind: TextButton.Kind.Accent
            // WPA's own minimum; anything shorter cannot be right.
            enabled: psk.text.length >= 8
            onClicked: root.confirm()
        }
    }
}
