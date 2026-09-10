pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The session lock.

    Uses the Wayland session-lock protocol, so the compositor keeps the screen
    covered even if this process dies while locked — that is the point of the
    protocol, and it is why the surface itself is kept deliberately plain.
    Authentication goes through PAM directly; there is no external locker to
    depend on.
*/
Scope {
    id: root

    property string password: ""
    property string status: ""
    property bool statusIsError: false
    property bool busy: false

    function submit(): void {
        if (root.busy || root.password === "")
            return;
        root.busy = true;
        root.status = qsTr("Authenticating…");
        root.statusIsError = false;
        pam.start();
    }

    function fail(message: string): void {
        root.busy = false;
        root.password = "";
        root.status = message;
        root.statusIsError = true;
    }

    Connections {
        target: Session
        function onLockRequested(): void {
            root.password = "";
            root.status = "";
            root.statusIsError = false;
            lock.locked = true;
        }
    }

    PamContext {
        id: pam

        config: "login"

        function start(): void {
            // Restarting the conversation is how a second attempt is made.
            this.active = false;
            this.active = true;
        }

        onResponseRequiredChanged: {
            if (pam.responseRequired)
                pam.respond(root.password);
        }

        onCompleted: result => {
            pam.active = false;
            if (result === PamResult.Success) {
                root.password = "";
                root.status = "";
                root.busy = false;
                lock.locked = false;
            } else if (result === PamResult.MaxTries) {
                root.fail(qsTr("Too many attempts"));
            } else {
                root.fail(qsTr("Incorrect password"));
            }
        }

        onError: error => {
            pam.active = false;
            root.fail(qsTr("Authentication unavailable (%1)").arg(PamError.toString(error)));
        }
    }

    WlSessionLock {
        id: lock

        locked: false

        surface: WlSessionLockSurface {
            id: surface

            color: Appearance.c.base

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height * 0.28)
                spacing: Appearance.s.xs

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Time.time
                    font.pixelSize: Appearance.font.clock
                    font.weight: Font.Light
                    font.features: ({ "tnum": 1 })
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Time.dateLong
                    role: Label.Role.Subtitle
                    muted: true
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: Math.round(parent.height * 0.14)
                spacing: Appearance.s.lg

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64
                    height: 64
                    radius: 32
                    color: Appearance.c.raised

                    Icon {
                        anchors.centerIn: parent
                        name: "user"
                        size: 32
                        color: Appearance.c.textMuted
                    }
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // PamContext only reports a user once a conversation is
                    // running, so the name shown comes from the environment.
                    text: String(Quickshell.env("USER") ?? "")
                    role: Label.Role.Subtitle
                }

                Item {
                    width: 300
                    height: Appearance.m.fieldHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.r.sm
                        color: Appearance.c.surface
                        border.width: 1
                        border.color: field.activeFocus ? Appearance.c.accent : Appearance.c.border
                    }

                    Icon {
                        id: keyIcon
                        anchors.verticalCenter: parent.verticalCenter
                        x: Appearance.s.lg
                        name: "password"
                        size: Appearance.m.icon
                        color: Appearance.c.textMuted
                    }

                    TextInput {
                        id: field

                        anchors.verticalCenter: parent.verticalCenter
                        x: keyIcon.x + keyIcon.width + Appearance.s.md
                        width: parent.width - x - Appearance.s.lg - (root.busy ? 24 : 0)
                        focus: true
                        enabled: !root.busy
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Appearance.c.text
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.font.body
                        selectionColor: Appearance.c.accent
                        selectedTextColor: Appearance.c.accentText
                        clip: true
                        renderType: Text.NativeRendering

                        onTextChanged: root.password = field.text
                        onAccepted: root.submit()

                        Connections {
                            target: root
                            function onPasswordChanged(): void {
                                if (field.text !== root.password)
                                    field.text = root.password;
                            }
                        }
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        x: field.x
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
                    }
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 320
                    height: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: root.status
                    role: Label.Role.Small
                    color: root.statusIsError ? Appearance.c.danger : Appearance.c.textMuted
                }
            }

            Component.onCompleted: field.forceActiveFocus()
        }
    }
}
