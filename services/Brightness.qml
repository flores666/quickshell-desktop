pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    Display backlight: read from sysfs, written through logind.

    The brightness file is normally root's, and logind's SetBrightness is the
    unprivileged way to change it for the active session — no udev rule needed.
    The device is discovered once at startup; on machines without a backlight,
    or if logind refuses the write, nothing here is available and the UI
    disables the control rather than offering a slider that does nothing.
*/
Singleton {
    id: root

    /*! Only once the level has been read: before that there is nothing true
        to show, and a first reading is not a change to announce. */
    readonly property bool available: root.loaded && root.maxRaw > 0 && !root.refused
    property bool loaded: false
    /*! logind turned a write down; the slider would do nothing. */
    property bool refused: false
    property int maxRaw: 0
    property int raw: 0
    /*! A target not yet handed to logind; the file is stale until it has been. */
    property bool dirty: false

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
        root.dirty = true;
        root.flush();
    }

    /*!
        Send the latest target to logind. A drag produces many targets faster
        than busctl returns, so at most one call is in flight and whatever the
        slider reached meanwhile is sent when it finishes.
    */
    function flush(): void {
        if (!root.available || writer.running || !root.dirty)
            return;
        root.dirty = false;
        writer.target = root.raw;
        writer.running = true;
    }

    function step(delta: real): void {
        root.set(root.value + delta);
    }

    /*!
        Point the file views at a discovered device.

        Paths are assigned here rather than bound, so no read is ever issued
        against the empty path a binding would produce before discovery.
    */
    function attach(device: string, max: int): void {
        root.maxRaw = max;
        writer.device = device;
        reader.path = `/sys/class/backlight/${device}/brightness`;
    }

    Process {
        // One shot at startup: the first backlight and its maximum, which
        // never changes. Nothing polls afterwards; the kernel notifies us of
        // changes through the watch below.
        running: true
        command: ["sh", "-c",
            "for d in /sys/class/backlight/*/; do "
            + "[ -r \"$d/brightness\" ] && { echo \"$(basename \"$d\") $(cat \"$d/max_brightness\")\"; exit 0; }; "
            + "done; exit 1"]

        stdout: StdioCollector {
            onStreamFinished: {
                const [device, max] = this.text.trim().split(" ");
                if (device && parseInt(max, 10) > 0)
                    root.attach(device, parseInt(max, 10));
            }
        }
    }

    FileView {
        id: reader
        watchChanges: true
        printErrors: false
        // A read racing our own write would drag the value back mid-drag.
        onLoaded: {
            if (!root.dirty && !writer.running)
                root.raw = parseInt(reader.text().trim(), 10) || 0;
            root.loaded = true;
        }
        onFileChanged: reader.reload()
    }

    Process {
        id: writer

        property string device: ""
        property int target: -1

        command: ["busctl", "call", "org.freedesktop.login1",
            "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session",
            "SetBrightness", "ssu", "backlight", writer.device, String(writer.target)]

        onExited: code => {
            if (code !== 0)
                root.refused = true;
        }
        onRunningChanged: if (!writer.running)
            root.flush()
    }
}
