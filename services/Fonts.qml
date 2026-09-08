pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    The font families this machine has.

    Read once and never watched: Qt builds its family list when the process
    starts and raises nothing when a font is installed afterwards, so there is
    no event to be driven by.  Restarting the shell is what picks a new font up,
    which is the same deal every other font-choosing application offers.
*/
Singleton {
    id: root

    readonly property var families: Qt.fontFamilies()
    readonly property bool available: root.families.length > 0

    /*! The families whose name contains `term`, case-insensitively. */
    function search(term: string): var {
        const needle = term.trim().toLowerCase();
        if (needle === "")
            return root.families;
        return root.families.filter(f => f.toLowerCase().indexOf(needle) !== -1);
    }
}
