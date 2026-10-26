import QtQuick
import Quickshell.Io

/*!
    Waits on a service's step where what it sets says nothing itself (a
    Hyprland option, a gsettings key): `until` runs `script` now and each time
    `busy` falls, the step done, and calls back with what it prints once
    `done(output)` holds with no step under way, or with what it prints after
    `bound`. One wait at a time.
*/
QtObject {
    id: root

    property bool busy: false
    property int bound: 2000
    property var pending: null
    property bool again: false

    onBusyChanged: {
        if (!root.busy)
            root.look();
    }

    /*! `args` are the script's $1, $2…, never spliced into it. */
    function until(script: string, args: var, done: var, then: var): void {
        root.pending = { script, args, done, then };
        root.timeout.restart();
        root.look();
    }

    function look(): void {
        if (root.pending === null)
            return;
        if (root.reader.running) {
            root.again = true;
            return;
        }
        root.reader.command = ["sh", "-c", root.pending.script, "sh"].concat(root.pending.args);
        root.reader.running = true;
    }

    function heard(output: string): void {
        const waited = root.pending;
        if (waited === null)
            return;
        if ((waited.done(output) && !root.busy) || !root.timeout.running) {
            root.pending = null;
            root.again = false;
            root.timeout.stop();
            waited.then(output);
        } else if (root.again) {
            root.again = false;
            root.look();
        }
    }

    readonly property Process reader: Process {
        stdout: StdioCollector {
            onStreamFinished: root.heard(this.text)
        }
    }

    readonly property Timer timeout: Timer {
        interval: root.bound
        onTriggered: root.look()
    }
}
