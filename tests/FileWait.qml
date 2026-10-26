import QtQuick
import Quickshell.Io

/*!
    Waits on a file: `until` calls back with its text once `done(text)` holds,
    read again each time the file is written (or made, or removed), or else
    after `bound` with the text it holds then. One wait at a time.
*/
QtObject {
    id: root

    property int bound: 2000
    property var pending: null

    function until(path: string, done: var, then: var): void {
        root.pending = { done, then };
        root.timeout.restart();
        root.file.path = path;
        root.file.reload();
    }

    function text(): string {
        return root.pending?.missing ? "" : root.file.text();
    }

    function heard(missing: bool): void {
        if (root.pending === null)
            return;
        root.pending.missing = missing;
        if (root.pending.done(root.text()))
            root.answer();
    }

    function answer(): void {
        const waited = root.pending;
        if (waited === null)
            return;
        root.pending = null;
        root.timeout.stop();
        waited.then(waited.missing ? "" : root.file.text());
    }

    readonly property FileView file: FileView {
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onLoaded: root.heard(false)
        onLoadFailed: root.heard(true)
    }

    readonly property Timer timeout: Timer {
        interval: root.bound
        onTriggered: root.answer()
    }
}
