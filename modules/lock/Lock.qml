pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "root:/config"
import "root:/services"

/*!
    The session lock.

    Uses the Wayland session-lock protocol, so the compositor keeps the screen
    covered even if this process dies while locked — that is the point of the
    protocol. The backdrop is a cached image of the wallpaper, never a view
    through to the desktop.
    Authentication goes through PAM directly; there is no external locker to
    depend on.
*/
Scope {
    id: root

    property string password: ""
    property string status: ""
    property bool statusIsError: false
    property bool busy: false

    // Keep intent through hot reload, independently of WlSessionLock.locked:
    // Quickshell 0.3.2 omits its change signal on a successful unlock.
    PersistentProperties {
        id: state
        property bool locked: false
    }

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
            if (lock.locked) return;
            root.password = "";
            root.status = "";
            root.statusIsError = false;
            root.busy = false;
            state.locked = true;
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
                state.locked = false;
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

        locked: state.locked

        surface: WlSessionLockSurface {
            id: surface

            color: Appearance.night.base

            LockBackdrop {
                anchors.fill: parent
                source: Wallpaper.current
            }

            LockContent {
                anchors.fill: parent
                password: root.password
                status: root.status
                statusIsError: root.statusIsError
                busy: root.busy
                onEdited: value => root.password = value
                onSubmitted: root.submit()
            }
        }
    }

    Binding {
        target: Keyboard
        property: "lockEnglish"
        value: state.locked
    }
}
