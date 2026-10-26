pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    The accent handed to applications outside the shell while it follows the
    wallpaper: GTK's (`accent-color`, one of libadwaita's names) and the
    terminal's (terminal/palette.conf's `accent` and `accent_bright`, laid
    over it by a file of this machine's state). What to hand over is worked
    out from the design system by modules/common/DesktopTheme — a service
    cannot read config/ — and set here; emptied, each goes back to its own.

    GTK's accent from before the shell first set one is kept
    (Settings.gtkAccentBefore) and given back, as Fonts does the font. The
    terminal's file is read by kitty-colors.py, which kitty runs at every
    start and config reload, and by neovim as it starts; running kittys are
    told to reload whenever it changes, and only then.

    Nothing is done before the settings are read: until then the accent
    reads as not following, and a login would take the terminal's colours
    away and give them back.
*/
Singleton {
    id: root

    /*! The libadwaita accent GTK takes, by name; empty leaves GTK its own. */
    property string gtk: ""
    /*! `{ accent, accent_bright }` for the terminal; null leaves it
        palette.conf's. */
    property var terminal: null

    /*! terminal/palette.conf, name → colour: what the terminal's own accents
        are, which the wallpaper's colour is laid at the lightness of. */
    readonly property var palette: {
        const out = {};
        for (const line of paletteFile.text().split("\n")) {
            const words = line.trim().split(/\s+/);
            if (words.length === 2 && !words[0].startsWith("#"))
                out[words[0]] = words[1];
        }
        return out;
    }

    /*! The machine's palette lines, read after palette.conf's. */
    readonly property string stateFile:
        (Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`)
        + "/quickshell-desktop/palette.conf"

    onGtkChanged: root.pushGtk()
    onTerminalChanged: root.pushTerminal()

    Connections {
        target: Settings

        function onReadyChanged(): void {
            root.pushGtk();
            root.pushTerminal();
        }
    }

    // ------------------------------------------------------------------ GTK

    // Both take their values as arguments, never spliced into the script.
    readonly property string gtkKey: "org.gnome.desktop.interface accent-color"
    readonly property string applyGtk: `
        before=$(gsettings get ${root.gtkKey} | tr -d "'")
        printf '%s\\n' "$before"
        gsettings set ${root.gtkKey} "$1"`
    readonly property string restoreGtk: `gsettings set ${root.gtkKey} "$1"`

    property bool gtkDirty: false
    property bool restoring: false
    /*! GTK's accent is being set; this falling is when it is, the one it
        replaced kept or given back. */
    readonly property bool settingGtk: gtkSetter.running

    function pushGtk(): void {
        if (!Settings.ready)
            return;
        if (gtkSetter.running) {
            root.gtkDirty = true;
            return;
        }
        root.gtkDirty = false;
        if (root.gtk !== "") {
            gtkSetter.command = ["sh", "-c", root.applyGtk, "sh", root.gtk];
        } else if (Settings.gtkAccentBefore !== "") {
            gtkSetter.command = ["sh", "-c", root.restoreGtk, "sh", Settings.gtkAccentBefore];
            root.restoring = true;
        } else {
            return;
        }
        gtkSetter.running = true;
    }

    Process {
        id: gtkSetter

        stdout: StdioCollector {
            onStreamFinished: {
                // Only the apply script prints: the accent it is replacing.
                // The first one is the user's own and is what goes back.
                const before = this.text.trim();
                if (before !== "" && Settings.gtkAccentBefore === "")
                    Settings.setGtkAccentBefore(before);
            }
        }
        onExited: exitCode => {
            // Forgotten only once it is back: a failed restore keeps it for
            // the next attempt.
            if (root.restoring && exitCode === 0)
                Settings.setGtkAccentBefore("");
            root.restoring = false;
            if (root.gtkDirty)
                root.pushGtk();
        }
    }

    // ------------------------------------------------------------- terminal

    /*! What the state file holds for `terminal`, empty for no file. */
    function terminalText(): string {
        if (!root.terminal)
            return "";
        return "# The shell's accent, from the wallpaper (services/DesktopAccent.qml):\n"
            + "# laid over terminal/palette.conf while it follows the wallpaper.\n"
            + `accent ${root.terminal.accent}\naccent_bright ${root.terminal.accent_bright}`;
    }

    // $1 the file, $2 what it should hold or empty for none. kitty is told
    // only of a change: a reload redraws every window.
    readonly property string writeTerminal: `
        if [ -n "$2" ]; then
            [ "$(cat "$1" 2>/dev/null)" = "$2" ] && exit 0
            mkdir -p "$(dirname "$1")"
            printf '%s\\n' "$2" > "$1.new" && mv "$1.new" "$1"
        else
            [ -e "$1" ] || exit 0
            rm -f "$1"
        fi
        pkill -USR1 -x kitty
        exit 0`

    property bool terminalDirty: false

    function pushTerminal(): void {
        if (!Settings.ready)
            return;
        if (terminalWriter.running) {
            root.terminalDirty = true;
            return;
        }
        root.terminalDirty = false;
        terminalWriter.command = ["sh", "-c", root.writeTerminal, "sh", root.stateFile, root.terminalText()];
        terminalWriter.running = true;
    }

    Process {
        id: terminalWriter

        onExited: {
            if (root.terminalDirty)
                root.pushTerminal();
        }
    }

    FileView {
        id: paletteFile
        path: Quickshell.shellPath("terminal/palette.conf")
        blockLoading: true
        printErrors: false
    }
}
