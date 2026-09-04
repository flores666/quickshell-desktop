pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    The arbiter for full-screen shell surfaces.

    Exactly one of the launcher, the overview, quick settings or the date menu
    can be open at a time, and each opens on one specific screen.  Routing every
    open/close through here is what makes that invariant hold without any of the
    surfaces knowing about each other.
*/
Singleton {
    id: root

    readonly property string none: ""
    readonly property string launcher: "launcher"
    readonly property string quickSettings: "quickSettings"
    readonly property string dateMenu: "dateMenu"
    readonly property string trayMenu: "trayMenu"
    readonly property string dockMenu: "dockMenu"

    property string active: root.none
    property ShellScreen screen: null
    /*!
        Where a popover should point, in the coordinates of the screen it opens
        on. Set by whichever bar button opened it.
    */
    property real anchorX: 0
    /*! Subject of the surface, where it has one — e.g. the tray item whose menu is up. */
    property var payload: null

    readonly property bool anyOpen: root.active !== root.none

    /*!
        Which of the shell's own surfaces the pointer is currently over.

        Used to tell an outside click from a click on the popup — or on the bar
        button that would toggle it straight back open. Keyed by surface so
        several monitors' bars and docks can report independently, and written
        from continuously-maintained hover state rather than from event order.
    */
    property var pointerRegions: ({})
    readonly property bool pointerOverShell: Object.keys(root.pointerRegions).length > 0

    function setPointerOver(key: string, over: bool): void {
        if (Boolean(root.pointerRegions[key]) === over)
            return;
        const next = Object.assign({}, root.pointerRegions);
        if (over)
            next[key] = true;
        else
            delete next[key];
        root.pointerRegions = next;
    }

    /*!
        A pointer press landed somewhere in the session.

        Hyprland reports these through a non-consuming bind, so the click still
        reaches whatever is under it; all this has to decide is whether it
        happened outside the popup.
    */
    function dismissOnOutsideClick(): void {
        if (root.anyOpen && !root.pointerOverShell)
            root.close();
    }

    function isOpen(name: string): bool {
        return root.active === name;
    }

    Connections {
        target: Quickshell

        // A surface whose monitor was just unplugged has nowhere to be.
        function onScreensChanged(): void {
            if (root.anyOpen && Quickshell.screens.indexOf(root.screen) === -1)
                root.close();
        }
    }

    function open(name: string, onScreen: ShellScreen): void {
        root.screen = onScreen ?? Compositor.focusedScreen;
        root.active = name;
    }

    /*!
        Open a popover without a bar button having placed it — from a keybinding,
        say. It lands where its bar button would have put it.
    */
    function openUnanchored(name: string): void {
        const s = Compositor.focusedScreen;
        const w = s ? s.width : 1920;
        root.anchorX = name === root.quickSettings ? w - 140 : w / 2;
        root.open(name, s);
    }

    function openWith(name: string, onScreen: ShellScreen, subject: var): void {
        root.payload = subject;
        root.open(name, onScreen);
    }

    function close(): void {
        root.active = root.none;
        root.payload = null;
    }

    function toggle(name: string, onScreen: ShellScreen): void {
        if (root.active === name)
            root.close();
        else
            root.open(name, onScreen);
    }
}
