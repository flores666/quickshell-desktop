pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    The font families this machine has, and the family applications use.

    Read once and never watched: Qt builds its family list when the process
    starts and raises nothing when a font is installed afterwards, so there is
    no event to be driven by.  Restarting the shell is what picks a new font up,
    which is the same deal every other font-choosing application offers.

    The family picked in settings is the system's too, not only the shell's.
    There is no one switch for that on a Hyprland desktop, so it goes through
    the two places applications look: the GTK interface font, which GTK apps
    read through the settings portal, and a fontconfig preference for
    sans-serif and system-ui, which is what Qt apps, browsers and the rest ask
    for.  Only the size of the GTK font is kept; the family is the shell's.

    An untouched setting leaves the system exactly as it was.  The GTK font the
    shell first replaced is remembered, and going back to Default restores it
    and removes the fontconfig file, which the shell owns outright.  Apps that
    are already open pick a change up when they are restarted.
*/
Singleton {
    id: root

    readonly property var families: Qt.fontFamilies()
    readonly property bool available: root.families.length > 0

    /*! The family in force for applications; empty means the system's own. */
    readonly property string chosen: Settings.fontFamily

    /*! The families whose name contains `term`, case-insensitively. */
    function search(term: string): var {
        const needle = term.trim().toLowerCase();
        if (needle === "")
            return root.families;
        return root.families.filter(f => f.toLowerCase().indexOf(needle) !== -1);
    }

    function fontconfigFor(family: string): string {
        const name = family.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const alias = generic => `  <alias binding="strong">
    <family>${generic}</family>
    <prefer><family>${name}</family></prefer>
  </alias>
`;
        return `<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<!-- Written by the shell's font setting; removed when it goes back to Default. -->
<fontconfig>
${alias("sans-serif")}${alias("system-ui")}</fontconfig>
`;
    }

    // Both take their values as arguments, never spliced into the script.
    readonly property string confFile:
        '"${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d/50-quickshell-font.conf"'
    readonly property string applyScript: `
        before=$(gsettings get org.gnome.desktop.interface font-name | tr -d "'")
        printf '%s\\n' "$before"
        size=\${before##* }
        case $size in ''|*[!0-9.]*) size=11 ;; esac
        gsettings set org.gnome.desktop.interface font-name "$1 $size"
        mkdir -p "$(dirname ${root.confFile})"
        printf '%s' "$2" > ${root.confFile}`
    readonly property string restoreScript: `
        gsettings set org.gnome.desktop.interface font-name "$1"
        rm -f ${root.confFile}`

    property bool dirty: false
    property bool restoring: false

    function push(): void {
        if (system.running) {
            root.dirty = true;
            return;
        }
        root.dirty = false;
        if (root.chosen !== "") {
            system.command = ["sh", "-c", root.applyScript, "sh",
                root.chosen, root.fontconfigFor(root.chosen)];
        } else if (Settings.systemFontBefore !== "") {
            system.command = ["sh", "-c", root.restoreScript, "sh", Settings.systemFontBefore];
            root.restoring = true;
        } else {
            return;
        }
        system.running = true;
    }

    // Keyed off the value, as Wallpaper is: the settings file loads
    // asynchronously, and the choice arriving is what a load looks like.
    onChosenChanged: root.push()

    Process {
        id: system

        stdout: StdioCollector {
            onStreamFinished: {
                // Only the apply script prints: the font it is replacing. The
                // first one is the user's own and is what Default gives back.
                const before = this.text.trim();
                if (before !== "" && Settings.systemFontBefore === "")
                    Settings.setSystemFontBefore(before);
            }
        }
        onExited: exitCode => {
            // Forgotten only once it is back: a failed restore keeps it for
            // the next attempt.
            if (root.restoring && exitCode === 0)
                Settings.setSystemFontBefore("");
            root.restoring = false;
            if (root.dirty)
                root.push();
        }
    }
}
