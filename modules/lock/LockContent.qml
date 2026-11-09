pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Item {
    id: root

    property string password: ""
    property string status: ""
    property bool statusIsError: false
    property bool busy: false
    property alias input: field
    signal edited(value: string)
    signal submitted

    // Fixed dark ink/wells over the dimmed wallpaper, in either desktop theme.
    readonly property ColorScheme scheme: Appearance.night

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * LockStyle.clockPosition)
        spacing: Appearance.s.xs

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            scheme: root.scheme
            text: Time.time
            font.pixelSize: Appearance.font.clock
            font.weight: Font.Light
            font.features: ({ "tnum": 1 })
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            scheme: root.scheme
            text: Time.dateLong
            role: Label.Role.Subtitle
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Math.round(parent.height * LockStyle.formOffset)
        spacing: Appearance.s.lg

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: LockStyle.avatar
            height: width
            radius: width / 2
            color: root.scheme.surface

            Icon {
                anchors.centerIn: parent
                name: "user"
                size: LockStyle.avatarIcon
                color: root.scheme.textMuted
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            scheme: root.scheme
            text: String(Quickshell.env("USER") ?? "")
            role: Label.Role.Subtitle
        }

        FieldWell {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(LockStyle.fieldWidth, root.width - Appearance.s.xxl)
            color: root.scheme.surface
            focused: field.activeFocus

            Icon {
                id: keyIcon
                anchors.verticalCenter: parent.verticalCenter
                x: Appearance.s.lg
                name: "password"
                size: Appearance.m.icon
                color: root.scheme.textMuted
            }

            TextInput {
                id: field
                anchors.verticalCenter: parent.verticalCenter
                x: keyIcon.x + keyIcon.width + Appearance.s.md
                width: parent.width - x - Appearance.s.lg - (root.busy ? Appearance.s.xxl : 0)
                focus: true
                enabled: !root.busy && Keyboard.lockReady
                text: root.password
                echoMode: TextInput.Password
                passwordCharacter: "•"
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhLatinOnly
                color: root.scheme.text
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.font.body
                selectionColor: root.scheme.accent
                selectedTextColor: root.scheme.accentText
                clip: true
                renderType: Text.NativeRendering
                // A steady caret avoids the normal blink waking the renderer
                // twice a second while the unattended lock stays on screen.
                cursorDelegate: Rectangle {
                    width: Appearance.m.controlBorder
                    color: root.scheme.text
                }

                onTextEdited: root.edited(field.text)
                onAccepted: root.submitted()
                onEnabledChanged: if (enabled) field.forceActiveFocus()
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                x: field.x
                scheme: root.scheme
                visible: field.text === "" && !root.busy
                text: qsTr("Password")
                role: Label.Role.Subtitle
                faint: true
            }

            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Appearance.s.lg
                visible: root.busy
                size: Appearance.m.icon
                color: root.scheme.accent
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            scheme: root.scheme
            text: Keyboard.code
            role: Label.Role.Small
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(LockStyle.statusWidth, root.width - Appearance.s.xxl)
            height: LockStyle.statusHeight
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.status || Keyboard.lockFailure
            role: Label.Role.Small
            color: root.statusIsError ? root.scheme.danger : root.scheme.textMuted
        }
    }

    Component.onCompleted: field.forceActiveFocus()
}
