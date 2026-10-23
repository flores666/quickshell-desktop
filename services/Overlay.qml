pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    The arbiter for the shell's popups.

    Exactly one of them — the launcher, quick settings, the date menu, the
    settings panel, or the tray, VPN or dock menu — can be open at a time, and
    it opens on one specific screen. Routing every open/close through here is
    what makes that invariant hold without any of the popups knowing about
    each other.
*/
Singleton {
    id: root

    readonly property string none: ""
    readonly property string launcher: "launcher"
    readonly property string quickSettings: "quickSettings"
    readonly property string dateMenu: "dateMenu"
    readonly property string trayMenu: "trayMenu"
    readonly property string vpnMenu: "vpnMenu"
    readonly property string dockMenu: "dockMenu"
    readonly property string settings: "settings"

    property string active: root.none
    property ShellScreen screen: null
    /*!
        Where each popover points, by name, in the coordinates of the screen it
        opens on: the bar button or dock icon that last opened it. A popup's
        own changes only as that popup opens, so one still on screen as another
        opens — fading, or holding its card for the other to take over — stays
        where it was instead of sliding towards the other's button, which it did
        when there was one anchor for all.
    */
    property var anchorXOf: ({})
    /*!
        Subject of the surface, where it has one — e.g. the tray item whose
        menu is up. Handed over only once the popup it is for is the active
        one (openWith), so that popup alone takes it; a popup opened without
        one has none.
    */
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
        happened outside the popup. A press on something covering the screen —
        slurp, dragging out a screenshot of the popup — is on top of it, not
        outside it, though the shell has lost the pointer to it.
    */
    function dismissOnOutsideClick(): void {
        if (root.anyOpen && !root.pointerOverShell && !Compositor.covered)
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

    /*!
        A popup opened straight over another on the same screen, which the two
        fly as one card (OverlayCard): `{ from, to, rect, strength, contents,
        away }`. Recorded here as the new one opens; `from` then hands over its
        card's place (in OverlaySurface, where every card is), how strongly it
        is drawn and a picture of what it shows (`depart`), `to` takes off
        from there (`arrive`, and `from` goes in that frame), and either gives
        it up when it cannot (`abandon`), both then opening and closing as
        they would alone. Each acts only on the hand-off that names it, so a
        stale one cannot disturb a newer.
    */
    property var flight: null

    function depart(name: string, rect: rect, strength: real, contents: var): void {
        if (root.flight?.from === name)
            root.flight = Object.assign({}, root.flight, { rect, strength, contents });
    }

    function arrive(name: string): void {
        if (root.flight?.to === name)
            root.flight = Object.assign({}, root.flight, { away: true });
    }

    function abandon(name: string): void {
        if (root.flight?.from === name || root.flight?.to === name)
            root.flight = null;
    }

    function open(name: string, onScreen: ShellScreen, at: real): void {
        const screen = onScreen ?? Compositor.focusedScreen;
        root.flight = root.anyOpen && root.active !== name && screen === root.screen
            ? { from: root.active, to: name, rect: null, strength: 1, contents: null, away: false } : null;
        root.payload = null;
        root.screen = screen;
        root.anchorXOf = Object.assign({}, root.anchorXOf, { [name]: at });
        root.menu = null;
        root.active = name;
    }

    /*!
        Open a popover without a bar button having placed it — from a keybinding,
        say. It lands where its bar button would have put it.
    */
    function openUnanchored(name: string): void {
        const s = Compositor.focusedScreen;
        const w = s ? s.width : 1920;
        root.open(name, s, name === root.quickSettings ? w - 140 : w / 2);
    }

    function openWith(name: string, onScreen: ShellScreen, at: real, subject: var): void {
        root.open(name, onScreen, at);
        root.payload = subject;
    }

    function close(): void {
        root.flight = null;
        root.menu = null;
        root.active = root.none;
        root.payload = null;
    }

    /*!
        A context menu inside the popup that is open: `{ source, entries }`,
        where `source` is the item it opens beside and each entry is
        `{ label, icon, danger, run }`.

        Held here rather than by a popup because there is only ever one popup
        for it to be in, and it has to go when that popup does, however the
        popup goes. OverlayCard draws it.
    */
    property var menu: null

    function openMenu(source: Item, entries: var): void {
        root.menu = { source: source, entries: entries };
    }

    function closeMenu(): void {
        root.menu = null;
    }

    /*!
        Escape: a context menu goes first, and the popup only once none is up.
        Escape into something covering the screen is its own.
    */
    function dismissOnEscape(): void {
        if (Compositor.covered)
            return;
        if (root.menu !== null)
            root.closeMenu();
        else
            root.close();
    }

    function toggle(name: string, onScreen: ShellScreen, at: real): void {
        if (root.active === name)
            root.close();
        else
            root.open(name, onScreen, at);
    }
}
