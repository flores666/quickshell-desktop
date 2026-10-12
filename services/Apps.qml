pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    The application index behind the launcher and the dock.

    Entries come from the XDG desktop database via Quickshell, which watches it
    for changes, so nothing polls.  Search is a small scored match over name,
    generic name, keywords and executable, with launch frequency used only to
    break ties between equally good matches.
*/
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values
        .filter(e => e && !e.noDisplay && e.name !== "")
        .sort((a, b) => a.name.localeCompare(b.name))

    /*!
        The launcher's categories: the freedesktop main categories, folded into
        the groups a person browses by. Only the groups something is filed
        under are listed, and an application filed under several is in each.
    */
    readonly property var categoryGroups: [
        { key: "development", title: qsTr("Development"), icon: "cat-development", match: ["Development"] },
        { key: "internet", title: qsTr("Internet"), icon: "cat-internet", match: ["Network"] },
        { key: "office", title: qsTr("Office"), icon: "cat-office", match: ["Office"] },
        { key: "graphics", title: qsTr("Graphics"), icon: "cat-graphics", match: ["Graphics"] },
        { key: "multimedia", title: qsTr("Multimedia"), icon: "cat-multimedia", match: ["AudioVideo", "Audio", "Video"] },
        { key: "games", title: qsTr("Games"), icon: "cat-games", match: ["Game"] },
        { key: "education", title: qsTr("Education"), icon: "cat-education", match: ["Education", "Science"] },
        { key: "system", title: qsTr("System"), icon: "cat-system", match: ["System"] },
        { key: "settings", title: qsTr("Settings"), icon: "cat-settings", match: ["Settings"] },
        { key: "utilities", title: qsTr("Accessories"), icon: "cat-utilities", match: ["Utility"] }
    ]
    readonly property var categories: root.categoryGroups
        .filter(group => root.all.some(e => root.filedUnder(e, group)))

    function filedUnder(entry: var, group: var): bool {
        return (entry?.categories ?? []).some(c => group.match.includes(c));
    }

    /*! Whether an entry is in the category keyed `key`; "" is every application. */
    function inCategory(entry: var, key: string): bool {
        if (key === "")
            return true;
        const group = root.categoryGroups.find(g => g.key === key);
        return group !== undefined && root.filedUnder(entry, group);
    }

    function byId(id: string): var {
        if (!id)
            return null;
        return DesktopEntries.byId(id) ?? null;
    }

    /*!
        Best-effort mapping from a Wayland app id / X11 class to a desktop entry.
        Compositor-reported ids are frequently not exact desktop file ids, so
        this falls back through the heuristic lookup and then a name match.
    */
    function byAppId(appId: string): var {
        if (!appId)
            return null;
        const direct = DesktopEntries.byId(appId);
        if (direct)
            return direct;
        const heuristic = DesktopEntries.heuristicLookup(appId);
        if (heuristic)
            return heuristic;

        const needle = appId.toLowerCase();
        const tail = needle.split(".").pop();
        for (const e of root.all) {
            if (e.name.toLowerCase() === needle || e.name.toLowerCase() === tail)
                return e;
            if (e.startupClass !== "" && e.startupClass.toLowerCase() === needle)
                return e;
        }
        return null;
    }

    function iconFor(appId: string): string {
        const entry = root.byAppId(appId);
        return entry ? entry.icon : appId;
    }

    function launch(entry: var): void {
        if (!entry)
            return;
        root.recordUse(entry.id);
        Compositor.exec(entry.command, entry.workingDirectory);
    }

    function launchAction(entry: var, action: var): void {
        if (!action)
            return;
        root.recordUse(entry?.id ?? "");
        Compositor.exec(action.command, entry?.workingDirectory ?? "");
    }

    // ---------------------------------------------------------------- search

    function score(entry: var, needle: string): int {
        const name = entry.name.toLowerCase();
        if (name === needle)
            return 1000;
        if (name.startsWith(needle))
            return 800 - Math.min(100, name.length);
        // Match the start of any word, so "fire" finds "Mozilla Firefox".
        if (new RegExp("\\b" + root.escapeRegExp(needle)).test(name))
            return 600;
        if (name.includes(needle))
            return 400;

        const generic = (entry.genericName ?? "").toLowerCase();
        if (generic.includes(needle))
            return 300;
        for (const k of entry.keywords ?? [])
            if (k.toLowerCase().includes(needle))
                return 250;
        if ((entry.comment ?? "").toLowerCase().includes(needle))
            return 150;
        if ((entry.execString ?? "").toLowerCase().includes(needle))
            return 100;
        return 0;
    }

    function escapeRegExp(s: string): string {
        return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }

    function search(query: string): var {
        const needle = query.trim().toLowerCase();
        if (needle === "")
            return root.all.slice().sort((a, b) => (root.uses(b.id) - root.uses(a.id))
                || a.name.localeCompare(b.name));

        const scored = [];
        for (const e of root.all) {
            const s = root.score(e, needle);
            if (s > 0)
                scored.push({ entry: e, score: s });
        }
        scored.sort((a, b) => (b.score - a.score)
            || (root.uses(b.entry.id) - root.uses(a.entry.id))
            || a.entry.name.localeCompare(b.entry.name));
        return scored.map(x => x.entry);
    }

    // ------------------------------------------------------------ frequency

    property var usage: ({})

    function uses(id: string): int {
        return id ? (root.usage[id] ?? 0) : 0;
    }

    function recordUse(id: string): void {
        if (!id)
            return;
        const next = Object.assign({}, root.usage);
        next[id] = (next[id] ?? 0) + 1;
        root.usage = next;
        usageFile.save();
    }

    FileView {
        id: usageFile
        path: Quickshell.statePath("app-usage.json")
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(this.text() || "{}");
                root.usage = (parsed && typeof parsed === "object") ? parsed : ({});
            } catch (e) {
                root.usage = ({});
            }
        }
        onLoadFailed: root.usage = ({})

        function save(): void {
            this.setText(JSON.stringify(root.usage));
        }
    }
}
