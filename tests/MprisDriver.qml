pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*! Real MPRIS objects, with every command confined to the runner's bus. */
Item {
    id: root
    readonly property bool isolated: Quickshell.env("TEST_MPRIS_BUS") === "private"
        && Quickshell.env("TEST_BIN") !== ""
    property bool ready: false
    property string cover: ""
    property string otherCover: ""
    property int serial: 0
    property int missing: 0
    property var pending: null
    property var delayed: null

    Process {
        id: fixture
        running: root.isolated
        command: ["python3", Qt.resolvedUrl("MprisFixture.py").toString().replace("file://", "")]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                const response = JSON.parse(line);
                if (response.ready) {
                    root.cover = response.cover;
                    root.otherCover = response.otherCover;
                    root.ready = true;
                } else if (response.missing) {
                    root.missing = response.missing;
                } else {
                    const then = root.pending;
                    root.pending = null;
                    if (then !== null) then(response);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text.trim() !== "") console.warn(this.text)
        }
    }
    Timer {
        id: delay
        onTriggered: { const then = root.delayed; root.delayed = null; then(); }
    }
    function after(ms: int, then: var): void {
        root.delayed = then;
        delay.interval = ms;
        delay.start();
    }
    function send(request: var, then: var): void {
        if (!root.isolated) throw new Error("MprisDriver requires a private test bus");
        root.pending = then;
        fixture.write(JSON.stringify(Object.assign({}, request, { serial: ++root.serial })) + "\n");
    }
    function find(item: Item, predicate: var): var {
        const found = [];
        function visit(child) {
            if (predicate(child)) found.push(child);
            for (const descendant of child.children) visit(descendant);
        }
        visit(item);
        return found;
    }
}
