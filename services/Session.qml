pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

/*!
    Session actions.

    Power actions go through systemd; logging out goes through whatever actually
    started the session (uwsm when present, otherwise the compositor's own exit).
*/
Singleton {
    id: root

    /*! Raised for the lock surface to pick up; see modules/lock. */
    signal lockRequested

    readonly property bool usingUwsm: String(Quickshell.env("DESKTOP_SESSION") ?? "").includes("uwsm")

    function lock(): void {
        // Nothing should be left hanging behind the lock surface.
        Overlay.close();
        root.lockRequested();
    }

    function suspend(): void {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function reboot(): void {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function shutdown(): void {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    function logout(): void {
        if (root.usingUwsm)
            Quickshell.execDetached(["uwsm", "stop"]);
        else
            Hyprland.dispatch("exit");
    }
}
