pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    The shell's light or dark, handed to every other application: GNOME's
    `color-scheme`, which xdg-desktop-portal-gtk serves as the portal's
    org.freedesktop.appearance color-scheme. Browsers read it for their own
    look and a page's prefers-color-scheme, and libadwaita follows it, each as
    it changes. IconThemes supplies the matching application artwork. Both GTK
    keys are set whenever the theme does, once the settings are read.
*/
Singleton {
    id: root

    /*! What GNOME's key says for the shell's theme. */
    readonly property string scheme: Settings.effectiveDark ? "prefer-dark" : "prefer-light"
    readonly property string iconTheme: IconThemes.themeName
    /*! It is being set; this falling is when it is. */
    readonly property bool setting: setter.running

    property bool dirty: false

    function push(): void {
        if (!Settings.ready)
            return;
        if (setter.running) {
            root.dirty = true;
            return;
        }
        root.dirty = false;
        setter.command = ["sh", "-c",
            'gsettings set org.gnome.desktop.interface color-scheme "$1"'
            + ' && gsettings set org.gnome.desktop.interface icon-theme "$2"',
            "sh", root.scheme, root.iconTheme];
        setter.running = true;
    }

    onSchemeChanged: root.push()
    Component.onCompleted: root.push()

    Connections {
        target: Settings

        function onReadyChanged(): void {
            root.push();
        }
    }

    Process {
        id: setter
        // A theme switched again while the last one was being set.
        onExited: {
            if (root.dirty)
                root.push();
        }
    }
}
