pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    How Settings is kept: settings.json under the Quickshell state directory,
    read into `adapter` and watched, so an edit by hand is picked up live; on a
    first run, started from profile/ (tools/save-profile.sh).

    Written at once, on this thread, a moment after a burst of changes, and
    never before the file is read. Written on a thread, as FileView does by
    default, a write still under way when the next began was waited for and
    read back into the adapter, taking back every key set since (Quickshell
    0.3.2's saveAsync): two keys set together read as the first alone until
    the second write landed, and on a first run the second could be lost.
*/
Scope {
    id: root

    required property SettingsStore adapter
    /*!
        Whether what the file holds is in the adapter. Not FileView's own
        `loaded`, which turns true a moment before the data goes in — a key
        set then was overwritten by the file — and which a first write leaves
        false, the writer having looked for the file before writing it.
    */
    property bool loaded: false

    FileView {
        id: file

        path: Quickshell.statePath("settings.json")
        adapter: root.adapter
        watchChanges: true
        printErrors: false
        blockWrites: true

        onFileChanged: file.reload()
        // Not before the file is read: the defaults would be written over it.
        onAdapterUpdated: {
            if (root.loaded)
                saveLater.restart();
        }
        onLoaded: root.loaded = true
        // On a first run, what was written is what was read.
        onSaved: root.loaded = true
        // None on first run: start from profile/, or the defaults, written out
        // to edit by hand. Deferred: see AGENTS.md, FileView.
        onLoadFailed: Qt.callLater(() => profile.text() !== ""
            ? file.setText(profile.text()) : file.writeAdapter())
    }

    FileView {
        id: profile
        path: Quickshell.shellPath("profile/settings.json")
        blockAllReads: true
        printErrors: false
    }

    // One write for a burst of changes: a slider dragged, or a colour, would
    // otherwise write the file at every step.
    Timer {
        id: saveLater
        interval: 250
        onTriggered: file.writeAdapter()
    }

    // A reload of the shell keeps what was set just before it.
    Component.onDestruction: {
        if (saveLater.running)
            file.writeAdapter();
    }
}
