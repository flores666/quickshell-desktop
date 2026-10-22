pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

/*!
    The window plugin's title bars (hypr/windows), from the shell's side: the
    applications the user hid them for, handed to the plugin, and which windows
    have one, which only the plugin can say.
*/
Singleton {
    id: root

    /*!
        The applications whose title bar the user hid in the dock's menu,
        handed to the plugin, which holds the list: whenever it changes, and
        again after every config reload, which loading the plugin raises. An
        empty one goes only as a change — the plugin starts with none and keeps
        what it was given through a reload — so a desktop that hides nothing
        never asks a Hyprland without the plugin for its dispatcher.
    */
    readonly property string hidden: Settings.hiddenTitleBars.join(",")
    onHiddenChanged: root.push(true)

    function push(changed: bool): void {
        if (Settings.ready && (changed || root.hidden !== ""))
            Hyprland.dispatch(`windows:hidden_for ${root.hidden}`);
    }

    /*!
        Window address → whether the plugin gave that window a bar, a hidden
        one included. It goes by what each client asked for, and nothing
        announces it, so it is read when something wants to know — the dock's
        menu, as it opens. A window read before keeps its answer meanwhile.
    */
    property var byWindow: ({})

    function read(toplevels: var): void {
        const addresses = toplevels.filter(t => t && t.address !== "").map(t => t.address);
        if (addresses.length === 0)
            return;
        if (reader.running) {
            reader.next = addresses;
            return;
        }
        reader.asked = addresses;
        reader.command = ["hyprctl", "-j", "--batch", addresses.map(a => `decorations address:0x${a}`).join(" ; ")];
        reader.running = true;
    }

    Process {
        id: reader

        property var asked: []
        property var next: []

        stdout: StdioCollector {
            onStreamFinished: {
                // Only the windows still open are kept.
                const result = {};
                for (const t of Compositor.toplevels)
                    if (t.address in root.byWindow)
                        result[t.address] = root.byWindow[t.address];
                // One reply per window, blank lines apart: its decorations, or
                // "none" for one that closed meanwhile.
                const replies = this.text.split(/\n{2,}/).filter(s => s.trim() !== "");
                reader.asked.forEach((a, i) => {
                    try {
                        result[a] = JSON.parse(replies[i]).some(d => d.decorationName === "TitleBar");
                    } catch (e) {
                        result[a] = false;
                    }
                });
                root.byWindow = result;
            }
        }
        onExited: {
            if (next.length > 0) {
                const addresses = next;
                next = [];
                root.read(Compositor.toplevels.filter(t => addresses.indexOf(t.address) !== -1));
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded")
                root.push(false);
        }
    }

    Connections {
        target: Settings
        function onReadyChanged(): void { root.push(false); }
    }
}
