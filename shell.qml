pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "root:/services"
import "root:/modules/bar"
import "root:/modules/dock"
import "root:/modules/panels"
import "root:/modules/common"
import "root:/modules/launcher"
import "root:/modules/settings"
import "root:/modules/tasks"
import "root:/modules/osd"
import "root:/modules/switcher"
import "root:/modules/lock"
import "root:/modules/notifications"
import "root:/modules/polkit"

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
              Compositor.workspaces.length, Settings.ready, Osd.shown, Keyboard.available,
              Vpn.available, V2rayn.available,
              // Not for a first paint: the switcher's order is every focus
              // change since the shell started.
              Switcher.active,
              // Likewise: this hands the window plugin the hidden title bars.
              TitleBars.hidden,
              // Not for the sake of a first paint: this is what puts the
              // remembered wallpaper back up after the daemon restarted.
              Wallpaper.available,
              // Likewise: this is what re-applies the Hyprland overrides.
              CompositorOptions.hasTouchpad,
              // Likewise: this tells every other application light or dark.
              DesktopScheme.scheme,
              // Likewise: this posts earlyoom's kills as notifications.
              EarlyOom.available,
              // Likewise: this registers the shell as the session's polkit
              // agent, before anything asks for a password.
              Polkit.available,
              // Likewise: this keeps the machine's last minute of usage,
              // there whenever a chart opens.
              Usage.span];
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

    CompositorTheme {}

    DesktopTheme {}

    // Every popup's card is drawn in this one window.
    OverlaySurface {
        QuickSettings {}
        DateMenu {}
        Launcher {}
        SettingsPanel {}
        TaskManager {}
        TrayMenu {}
        VpnMenu {}
        DockMenu {}
    }

    // The password prompt, above the popups: what asks is often one of them.
    AuthWindow {
        flow: Polkit.flow
    }

    Lock {}

    OsdWindow {}

    SwitcherWindow {}

    Toasts {}
}
