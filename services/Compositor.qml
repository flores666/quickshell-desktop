pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

/*!
    A normalised view of Hyprland's workspaces and windows.

    Quickshell keeps these models up to date from the compositor event socket, so
    everything here is push-driven.  All lookups tolerate a null focused monitor
    or workspace, which is the state during monitor hotplug.
*/
Singleton {
    id: root

    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandToplevel activeToplevel: Hyprland.activeToplevel

    readonly property var workspaces: Hyprland.workspaces.values.filter(w => w && w.id > 0)
    readonly property var toplevels: Hyprland.toplevels.values.filter(t => t)

    readonly property ShellScreen focusedScreen: {
        const name = root.focusedMonitor?.name ?? "";
        for (const s of Quickshell.screens)
            if (s.name === name)
                return s;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    /*!
        Resolve a Quickshell screen to its Hyprland monitor.  Written as a lookup
        over the monitor model rather than Hyprland.monitorFor() so that bindings
        re-evaluate when monitors are plugged in or removed.
    */
    function monitorFor(screen: ShellScreen): HyprlandMonitor {
        if (!screen)
            return null;
        for (const m of Hyprland.monitors.values)
            if (m && m.name === screen.name)
                return m;
        return null;
    }

    /*!
        Workspaces to show for a monitor: everything that exists there, plus the
        next empty slot so there is always somewhere to move a window to.
    */
    function workspacesFor(monitor: HyprlandMonitor): var {
        if (!monitor)
            return [];
        const mine = root.workspaces
            .filter(w => w.monitor === monitor)
            .sort((a, b) => a.id - b.id);
        return mine;
    }

    /*!
        The application id of a window.

        Prefers the Wayland toplevel's own app id, which is always present, and
        falls back to Hyprland's window class — that arrives over IPC and is
        briefly empty for a window the shell has only just heard about.
    */
    function appIdOf(toplevel: HyprlandToplevel): string {
        if (!toplevel)
            return "";
        const wayland = toplevel.wayland;
        if (wayland && wayland.appId !== "")
            return wayland.appId;
        const ipc = toplevel.lastIpcObject;
        return String(ipc.class ?? ipc.initialClass ?? "");
    }

    /*!
        The workspace overview.

        Provided by the hyprexpo compositor plugin rather than drawn by the
        shell: it renders live workspace contents, which a layer surface cannot
        do. The dispatcher is a no-op when the plugin is not loaded.
    */
    function toggleOverview(): void {
        Hyprland.dispatch("hyprexpo:expo toggle");
    }

    function focusWindow(toplevel: HyprlandToplevel): void {
        if (toplevel && toplevel.address !== "")
            Hyprland.dispatch(`focuswindow address:0x${toplevel.address}`);
    }

    function closeWindow(toplevel: HyprlandToplevel): void {
        if (toplevel && toplevel.address !== "")
            Hyprland.dispatch(`closewindow address:0x${toplevel.address}`);
    }

    /*! Silent: the window moves, the workspace you are looking at does not. */
    function moveWindowToWorkspace(toplevel: HyprlandToplevel, id: int): void {
        if (toplevel && toplevel.address !== "")
            Hyprland.dispatch(`movetoworkspacesilent ${id},address:0x${toplevel.address}`);
    }

    function switchToWorkspace(id: int): void {
        Hyprland.dispatch(`workspace ${id}`);
    }

    /*! Cycle within the monitor's own workspaces, without wrapping onto another. */
    function cycleWorkspace(monitor: HyprlandMonitor, delta: int): void {
        const list = root.workspacesFor(monitor);
        if (list.length === 0)
            return;
        const active = monitor.activeWorkspace;
        const i = list.indexOf(active);
        const next = i === -1 ? 0 : Math.max(0, Math.min(list.length - 1, i + delta));
        if (list[next] !== active)
            root.switchToWorkspace(list[next].id);
    }

    /*! True when the given monitor is showing a fullscreen window right now. */
    function isFullscreenOn(monitor: HyprlandMonitor): bool {
        return Boolean(monitor?.activeWorkspace?.hasFullscreen ?? false);
    }
}
