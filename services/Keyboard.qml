pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/*!
    The active keyboard layout.

    Hyprland pushes an `activelayout` event on every switch, so the indicator is
    entirely event-driven. Only the starting value has to be asked for, because
    the event stream says nothing until the first change — that is one query at
    startup, not a poll.

    The indicator hides itself when only one layout is configured; there is
    nothing to report on a single-layout machine.
*/
Singleton {
    id: root

    /*! Descriptive name from Hyprland, e.g. "English (US)". */
    property string layout: ""
    /*! Number of layouts in input:kb_layout. */
    property int layoutCount: 0

    readonly property bool available: root.layoutCount > 1 && root.layout !== ""
    readonly property string code: root.shortCode(root.layout)

    /*! Language name to its two-letter code, where the two differ. */
    readonly property var languageCodes: ({
        "German": "DE", "Spanish": "ES", "Polish": "PL", "Greek": "EL",
        "Chinese": "ZH", "Dutch": "NL", "Swedish": "SV", "Czech": "CS",
        "Turkish": "TR", "Danish": "DA", "Estonian": "ET", "Persian": "FA",
        "Croatian": "HR", "Slovenian": "SL", "Norwegian": "NB"
    })

    function shortCode(description: string): string {
        // "English (US)" -> "English" -> "EN"; the parenthesised variant is
        // dropped because the bar has room for two letters, not a country.
        const language = description.split("(")[0].trim();
        if (language === "")
            return "";
        return root.languageCodes[language] ?? language.slice(0, 2).toUpperCase();
    }

    function cycle(): void {
        Hyprland.dispatch("switchxkblayout current next");
    }

    Process {
        // One shot: the current layout and how many are configured. Everything
        // after this arrives as an event.
        running: true
        command: ["sh", "-c",
            "hyprctl getoption input:kb_layout -j; hyprctl devices -j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const text = this.text;
                    const split = text.indexOf("}") + 1;
                    const option = JSON.parse(text.slice(0, split));
                    const devices = JSON.parse(text.slice(split));
                    root.layoutCount = String(option.str ?? "").split(",")
                        .filter(x => x.trim() !== "").length;
                    const main = (devices.keyboards ?? []).find(k => k.main);
                    if (main)
                        root.layout = String(main.active_keymap ?? "");
                } catch (e) {
                    root.layoutCount = 0;
                }
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "activelayout")
                return;
            // "KEYBOARD_NAME,LAYOUT NAME" — the layout may itself contain commas,
            // so only the first field is split off.
            const data = event.data;
            const comma = data.indexOf(",");
            if (comma !== -1)
                root.layout = data.slice(comma + 1);
        }
    }
}
