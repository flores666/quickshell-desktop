pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/* A temporary layout lease. Keep each keyboard's own group, enforce English
   while the lock owns input, then restore it. Reads and writes are serialized;
   an unlock during a read/write reconciles against the latest intent. */
Scope {
    id: root

    property bool active: false
    property bool ready: false
    property string failure: ""
    readonly property var saved: JSON.parse(retained.savedJson)
    property bool again: false

    PersistentProperties {
        id: retained
        // JS objects belong to one QML engine; only their JSON crosses reload.
        property string savedJson: "{}"
        onLoaded: root.refresh()
    }

    onActiveChanged: {
        root.ready = false;
        root.failure = "";
        root.refresh();
    }

    function refresh(): void {
        if (root.active || Object.keys(root.saved).length > 0 || reader.running || writer.running) {
            root.ready = false;
            if (writer.running || reader.running) {
                root.again = true;
            } else {
                root.again = false;
                reader.running = true;
            }
        } else {
            root.ready = true;
        }
    }

    function reconcile(keyboards: var): void {
        const saved = Object.assign({}, root.saved);
        let next = null;
        let missing = false;
        for (const keyboard of keyboards) {
            const layouts = String(keyboard.layout ?? "").split(",");
            const english = layouts.indexOf("us") >= 0 ? layouts.indexOf("us") : layouts.indexOf("gb");
            const index = keyboard.active_layout_index;
            if (!Number.isInteger(index)) continue;
            if (root.active) {
                const before = saved[keyboard.name];
                if (!before || before.address !== keyboard.address || before.layout !== keyboard.layout)
                    saved[keyboard.name] = { address: keyboard.address, layout: keyboard.layout, index };
                if (english < 0) missing = true;
                else if (index !== english && next === null)
                    next = { name: keyboard.name, index: english };
            } else {
                const before = saved[keyboard.name];
                // A removed/replaced device or a changed config is no longer
                // the subject whose group we saved.
                if (!before || before.address !== keyboard.address || before.layout !== keyboard.layout)
                    continue;
                if (index !== before.index && next === null)
                    next = { name: keyboard.name, index: before.index };
            }
        }
        retained.savedJson = JSON.stringify(root.active || next !== null ? saved : ({}));
        root.failure = missing ? qsTr("English layout unavailable") : "";
        if (next !== null) {
            writer.command = ["hyprctl", "switchxkblayout", next.name, String(next.index)];
            writer.running = true;
        } else {
            root.ready = true;
        }
    }

    Process {
        id: reader
        command: ["hyprctl", "devices", "-j"]
        property var keyboards: null
        onStarted: reader.keyboards = null
        stdout: StdioCollector {
            onStreamFinished: {
                try { reader.keyboards = JSON.parse(this.text).keyboards; }
                catch (e) { reader.keyboards = null; }
            }
        }
        onExited: code => {
            if (root.again)
                root.refresh();
            else if (code === 0 && Array.isArray(reader.keyboards))
                root.reconcile(reader.keyboards);
            else
                root.unavailable();
        }
    }

    function unavailable(): void {
        // Never trap someone outside their session when IPC fails. Show the
        // actual language and allow PAM to authenticate with their keyboard.
        root.failure = qsTr("Could not set English layout");
        root.ready = true;
    }

    Process {
        id: writer
        onExited: code => {
            if (code === 0) root.refresh();
            else root.unavailable();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "activelayout" || event.name === "configreloaded")
                root.refresh();
        }
    }
}
