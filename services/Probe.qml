pragma ComponentBehavior: Bound

import Quickshell.Io

/*!
    A one-shot command a service runs on demand. Asked for again while it
    runs, it runs once more after, so every ask is answered by a reading
    taken after it.
*/
Process {
    id: root

    property bool again: false

    function run(): void {
        if (root.running)
            root.again = true;
        else
            root.running = true;
    }

    onRunningChanged: if (!root.running && root.again) {
        root.again = false;
        root.running = true;
    }
}
