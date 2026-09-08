pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "root:/config"
import "root:/services"
import "root:/modules/bar"
import "root:/modules/dock"
import "root:/modules/panels"
import "root:/modules/common"
import "root:/modules/launcher"
import "root:/modules/settings"
import "root:/modules/osd"
import "root:/modules/lock"
import "root:/modules/notifications"

/*!
    Shell entry point.

    Per-monitor chrome is instantiated through Variants over Quickshell.screens,
    which handles monitors appearing and disappearing.  Single-instance surfaces
    (the overlays, the OSD, notification toasts) follow the focused monitor
    instead and live further down this file.
*/
ShellRoot {
    Component.onCompleted: {
        // Bring the state singletons up at startup rather than on first paint,
        // so the bar renders with real values instead of empty placeholders.
        void [Audio.ready, Network.available, Bt.available, Power.hasBattery,
              Brightness.available, Players.any, Apps.all.length, Notifs.count,
              Compositor.workspaces.length, Settings.ready, Osd.armed, Keyboard.available,
              // Not for the sake of a first paint: this is what puts the
              // remembered wallpaper back up after the daemon restarted.
              Wallpaper.available];
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Variants {
        model: Quickshell.screens
        DockPanel {}
    }

    ShellIpc {}

    OverviewTheme {}

    QuickSettings {}

    DateMenu {}

    Launcher {}

    SettingsPanel {}

    TrayMenu {}

    DockMenu {}

    Lock {}

    OsdWindow {}

    Toasts {}
}
