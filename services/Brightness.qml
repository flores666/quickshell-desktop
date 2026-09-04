pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    Display backlight, driven directly through sysfs.

    The device is discovered once at startup and only reported as available if a
    backlight exists *and* its brightness file is writable by this user (a udev
    rule normally grants that).  On machines without a backlight — or without the
    permission — nothing here becomes available and the UI omits the control
    entirely, rather than offering a slider that silently does nothing.
*/
Singleton {
    id: root

    property bool available: false
    property int maxRaw: 0
    property int raw: 0

    readonly property real value: root.maxRaw > 0 ? root.raw / root.maxRaw : 0
    readonly property string icon: "brightness"

    /*! Never let the panel go fully dark: the user could not find it again. */
    readonly property real minimum: root.maxRaw > 0 ? Math.max(1 / root.maxRaw, 0.01) : 0.01

    function set(v: real): void {
        if (!root.available)
            return;
        const clamped = Math.max(root.minimum, Math.min(1, v));
        const target = Math.max(1, Math.round(clamped * root.maxRaw));
        if (target === root.raw)
            return;
        root.raw = target;
        writer.setText(String(target));
    }

    function step(delta: real): void {
        root.set(root.value + delta);
    }

    /*!
        Point the file views at a discovered device.

        Paths are assigned here rather than bound, so no read is ever issued
        against the empty path a binding would produce before discovery.
    */
    function attach(device: string): void {
        const dir = `/sys/class/backlight/${device}`;
        maxFile.path = `${dir}/max_brightness`;
        reader.path = `${dir}/brightness`;
        writer.path = `${dir}/brightness`;
        root.available = true;
    }

    Process {
        // One shot at startup: pick the first writable backlight. Nothing polls
        // afterwards; the kernel notifies us of changes through the watch below.
        running: true
        command: ["sh", "-c",
            "for d in /sys/class/backlight/*/; do "
            + "[ -w \"$d/brightness\" ] && { basename \"$d\"; exit 0; }; done; exit 1"]

        stdout: StdioCollector {
            onStreamFinished: {
                const device = this.text.trim();
                if (device !== "")
                    root.attach(device);
            }
        }
    }

    FileView {
        id: maxFile
        printErrors: false
        onLoaded: root.maxRaw = parseInt(maxFile.text().trim(), 10) || 0
    }

    FileView {
        id: reader
        watchChanges: true
        printErrors: false
        onLoaded: root.raw = parseInt(reader.text().trim(), 10) || 0
        onFileChanged: reader.reload()
    }

    FileView {
        id: writer
        // sysfs rejects the write-and-rename dance an atomic write would do.
        atomicWrites: false
        printErrors: false
        onSaveFailed: root.available = false
    }
}
