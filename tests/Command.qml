import QtQuick
import Quickshell.Io

/*! One shell command at a time, what it prints handed to a callback. */
QtObject {
    id: root

    property var pending: null

    readonly property Process process: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const then = root.pending;
                root.pending = null;
                then(this.text);
            }
        }
    }

    /*! `args` are the script's $1, $2…, never spliced into it. */
    function run(script: string, args: var, then: var): void {
        root.pending = then;
        root.process.command = ["sh", "-c", script, "sh"].concat(args);
        root.process.running = true;
    }
}
