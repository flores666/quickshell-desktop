pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    Persisted user preferences.

    Backed by a single JSON file under the Quickshell state directory.  Writes
    are debounced by the adapter itself (one write per property change batch) and
    the file is watched so an external edit is picked up live.
*/
Singleton {
    id: root

    readonly property bool effectiveDark: adapter.theme !== "light"
    readonly property bool doNotDisturb: adapter.doNotDisturb
    readonly property var pinnedApps: adapter.pinnedApps
    readonly property string accentColor: adapter.accentColor
    readonly property string backgroundLight: adapter.backgroundLight
    readonly property string backgroundDark: adapter.backgroundDark

    function setTheme(name: string): void {
        adapter.theme = name === "light" ? "light" : "dark";
    }

    function toggleTheme(): void {
        root.setTheme(root.effectiveDark ? "light" : "dark");
    }

    function setDoNotDisturb(on: bool): void {
        adapter.doNotDisturb = on;
    }

    function setAccentColor(value: string): void {
        adapter.accentColor = value;
    }

    /*! Applies to whichever theme is active; the other keeps its own colour. */
    function setBackgroundColor(value: string): void {
        if (adapter.theme === "light")
            adapter.backgroundLight = value;
        else
            adapter.backgroundDark = value;
    }

    function isPinned(id: string): bool {
        return id !== "" && adapter.pinnedApps.indexOf(id) !== -1;
    }

    function pin(id: string): void {
        if (id === "" || root.isPinned(id))
            return;
        adapter.pinnedApps = adapter.pinnedApps.concat([id]);
    }

    function unpin(id: string): void {
        if (!root.isPinned(id))
            return;
        adapter.pinnedApps = adapter.pinnedApps.filter(x => x !== id);
    }

    readonly property bool ready: file.loaded

    JsonAdapter {
        id: adapter

        property string theme: "dark"
        property bool doNotDisturb: false
        property list<string> pinnedApps: []
        /*! Empty means "use the built-in colour for the current theme". */
        property string accentColor: ""
        property string backgroundLight: ""
        property string backgroundDark: ""
    }

    FileView {
        id: file

        path: Quickshell.statePath("settings.json")
        adapter: adapter
        watchChanges: true
        printErrors: false

        onFileChanged: file.reload()
        onAdapterUpdated: file.writeAdapter()
        // A missing file on first run is expected; write the defaults out so the
        // user has something to edit by hand if they want to.
        onLoadFailed: file.writeAdapter()
    }
}
