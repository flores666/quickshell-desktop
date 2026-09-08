pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "root:/services"

/*!
    The shell's external control surface.

    Every action exists exactly once, in `run()`.  Two front ends dispatch to it:
    `qs ipc call shell <action>` for scripts, and the Wayland global-shortcut
    protocol for Hyprland `global` binds.  Neither can drift from the other.
*/
QtObject {
    id: root

    readonly property var actions: [
        "launcher", "overview", "quickSettings", "dateMenu", "settings",
        "close", "dismiss", "escapeKey",
        "lock",
        "volumeUp", "volumeDown", "volumeMute", "micMute",
        "brightnessUp", "brightnessDown",
        "screenshot", "screenshotRegion",
        "playPause", "next", "previous",
        "toggleTheme", "toggleDnd"
    ]

    function run(action: string): void {
        switch (action) {
        case "launcher":
        case "quickSettings":
        case "dateMenu":
        case "settings":
            if (Overlay.isOpen(action))
                Overlay.close();
            else
                Overlay.openUnanchored(action);
            break;
        case "overview":
            Overlay.close();
            Compositor.toggleOverview();
            break;
        case "close": Overlay.close(); break;
        case "dismiss": Overlay.dismissOnOutsideClick(); break;
        // Escape arrives as a global, non-consuming bind so it closes the popup
        // whether or not the compositor gave it keyboard focus. Applications
        // still receive the key.
        case "escapeKey": Overlay.close(); break;
        case "lock": Session.lock(); break;

        case "volumeUp": Audio.stepVolume(0.05); break;
        case "volumeDown": Audio.stepVolume(-0.05); break;
        case "volumeMute": Audio.toggleMute(); break;
        case "micMute": Audio.toggleMicMute(); break;

        case "brightnessUp": Brightness.step(0.05); break;
        case "brightnessDown": Brightness.step(-0.05); break;

        case "screenshot": Screenshot.capture(); break;
        case "screenshotRegion": Screenshot.captureRegion(); break;

        case "playPause": Players.playPause(); break;
        case "next": Players.next(); break;
        case "previous": Players.previous(); break;

        case "toggleTheme": Settings.toggleTheme(); break;
        case "toggleDnd": Settings.setDoNotDisturb(!Settings.doNotDisturb); break;
        }
    }

    readonly property IpcHandler ipc: IpcHandler {
        target: "shell"

        function launcher(): void { root.run("launcher"); }
        function overview(): void { root.run("overview"); }
        function quickSettings(): void { root.run("quickSettings"); }
        function dateMenu(): void { root.run("dateMenu"); }
        function settings(): void { root.run("settings"); }
        function close(): void { root.run("close"); }
        function dismiss(): void { root.run("dismiss"); }
        function escapeKey(): void { root.run("escapeKey"); }
        function lock(): void { root.run("lock"); }

        function volumeUp(): void { root.run("volumeUp"); }
        function volumeDown(): void { root.run("volumeDown"); }
        function volumeMute(): void { root.run("volumeMute"); }
        function micMute(): void { root.run("micMute"); }

        function brightnessUp(): void { root.run("brightnessUp"); }
        function brightnessDown(): void { root.run("brightnessDown"); }

        function screenshot(): void { root.run("screenshot"); }
        function screenshotRegion(): void { root.run("screenshotRegion"); }

        function playPause(): void { root.run("playPause"); }
        function next(): void { root.run("next"); }
        function previous(): void { root.run("previous"); }

        function toggleTheme(): void { root.run("toggleTheme"); }
        function toggleDnd(): void { root.run("toggleDnd"); }
    }

    readonly property Instantiator shortcuts: Instantiator {
        model: root.actions

        delegate: GlobalShortcut {
            required property string modelData

            appid: "shell"
            name: this.modelData
            description: `Shell action: ${this.modelData}`
            onPressed: root.run(this.modelData)
        }
    }
}
