pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

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

    /*! Where a title bar's minimize button puts a window (hypr/windows):
        Hyprland has no minimized state, and a special workspace is its idiom. */
    readonly property string minimizedWorkspace: "special:minimized"

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
        Quickshell.execDetached(["hyprctl", "eval",
            'if hl.plugin.hyprexpo then hl.plugin.hyprexpo.expo("toggle") end']);
    }

    /*! A Lua string literal for Hyprland's eval/dispatch API (0.57+). */
    function luaString(value: string): string {
        return '"' + value.replace(/[\u0000-\u001f\\"]/g, c =>
            c === "\\" || c === '"' ? "\\" + c : "\\" + String(c.charCodeAt(0)).padStart(3, "0")) + '"';
    }

    /*!
        Focus a window, on its own workspace and monitor, leaving the pointer
        where it is.

        `focuswindow` always warps the pointer onto the window, and only
        cursor:no_warps stops it — for everything, so on for good it would also
        leave a keyboard `movefocus` with the pointer over the window it left.
        It is on for this one dispatch: Hyprland runs a batch with nothing in
        between, and the batch puts it back as it found it.

        A minimized window comes back to the workspace in front of you first;
        focusing it where it is would bring its whole special workspace over
        the screen instead. And it is raised: only a click raises a window in
        Hyprland, so a floating one focused under another stayed hidden.
    */
    function focusWindow(toplevel: HyprlandToplevel): void {
        if (!toplevel || toplevel.address === "")
            return;
        const address = root.luaString(`address:0x${toplevel.address}`);
        const restore = toplevel.workspace?.name === root.minimizedWorkspace && root.focusedWorkspace
            ? `hl.dispatch(hl.dsp.window.move({ workspace = ${root.focusedWorkspace.id}, window = ${address}, follow = false })); ` : "";
        Quickshell.execDetached(["hyprctl", "eval",
            'local warp = hl.get_config("cursor.no_warps"); hl.config({ cursor = { no_warps = true } }); '
            + restore + `hl.dispatch(hl.dsp.focus({ window = ${address} })); `
            + `hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = ${address} })); `
            + 'hl.config({ cursor = { no_warps = warp } })']);
    }

    function closeWindow(toplevel: HyprlandToplevel): void {
        if (toplevel && toplevel.address !== "")
            Hyprland.dispatch(`hl.dsp.window.close({ window = ${root.luaString(`address:0x${toplevel.address}`)} })`);
    }

    /*! Each dock owns one monitor's resting artwork and pin membership, keyed
        by window address and application identity (pins have no window yet).
        Publish whole snapshots serially: late writes cannot resurrect removed targets. */
    property var dockTargets: ({})
    property bool dockTargetsDirty: false

    function setDockTargets(screen: string, targets: var): void {
        if (screen === "") return;
        const next = Object.assign({}, root.dockTargets);
        if (targets === null) delete next[screen];
        else next[screen] = targets;
        if (JSON.stringify(next) === JSON.stringify(root.dockTargets)) return;
        root.dockTargets = next;
        root.dockTargetsDirty = true;
        Qt.callLater(root.pushDockTargets);
    }

    function pushDockTargets(): void {
        if (dockPush.running || !root.dockTargetsDirty) return;
        root.dockTargetsDirty = false;
        const monitors = Object.entries(root.dockTargets).map(([screen, targets]) => {
            const rows = targets.map(t => {
                const key = t.address ? `address=${root.luaString(t.address)}` : `appId=${root.luaString(t.appId)}`;
                return `{${key},pinned=${Boolean(t.pinned)},x=${t.x},y=${t.y},width=${t.width},height=${t.height}}`;
            });
            return `[${root.luaString(screen)}]={${rows.join(",")}}`;
        });
        dockPush.command = ["hyprctl", "eval", "if hl.plugin.windows and hl.plugin.windows.dock_targets then "
            + `hl.plugin.windows.dock_targets({${monitors.join(",")}}) end`];
        dockPush.running = true;
    }

    Process {
        id: dockPush
        onExited: root.pushDockTargets()
    }

    /*! Silent: the window moves, the workspace you are looking at does not. */
    function moveWindowToWorkspace(toplevel: HyprlandToplevel, id: int): void {
        if (toplevel && toplevel.address !== "")
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${id}, window = ${root.luaString(`address:0x${toplevel.address}`)}, follow = false })`);
    }

    /*!
        Start a program through Hyprland rather than as a child of the shell.

        Hyprland's `misc:initial_workspace_tracking` then opens its window on
        the workspace it was launched from, even if you have moved on by the
        time it maps; a process the shell spawns itself opens wherever you are.
    */
    function exec(command: var, workingDirectory: string): void {
        if (!command || command.length === 0)
            return;
        const quote = s => `'${String(s).replace(/'/g, "'\\''")}'`;
        const run = "exec " + command.map(quote).join(" ");
        Hyprland.dispatch(`hl.dsp.exec_cmd(${root.luaString(workingDirectory ? `cd ${quote(workingDirectory)} && ${run}` : run)})`);
    }

    function switchToWorkspace(id: int): void {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
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

    /*!
        Whether something other than the shell covers a whole screen on the
        overlay layer, the popups' own: slurp dragging out a screenshot over
        hyprpicker's freeze, or any picker like them. Every press and key is
        its while it is up, wherever the pointer is.
    */
    property bool covered: false

    function readLayers(): void {
        if (layers.running)
            layers.stale = true;
        else
            layers.running = true;
    }

    Component.onCompleted: root.readLayers()

    Process {
        id: layers

        // A layer that opens or closes while the last reading is under way is
        // read again after it, not lost.
        property bool stale

        command: ["hyprctl", "-j", "layers"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const monitors = JSON.parse(this.text);
                    root.covered = Quickshell.screens.some(s => (monitors[s.name]?.levels["3"] ?? []).some(l =>
                        !l.namespace.startsWith("shell-") && l.w >= s.width && l.h >= s.height));
                } catch (e) {
                    root.covered = false;
                }
            }
        }
        onExited: {
            if (stale) {
                stale = false;
                running = true;
            }
        }
    }

    Connections {
        target: Hyprland

        // Hyprland names the layer that opened or closed and nothing more, so
        // a foreign one has them all read; the shell's own, which open with
        // every popup and toast, are skipped.
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded") {
                root.dockTargetsDirty = true;
                Qt.callLater(root.pushDockTargets);
            }
            if ((event.name === "openlayer" || event.name === "closelayer") && !event.data.startsWith("shell-"))
                root.readLayers();
        }
    }
}
