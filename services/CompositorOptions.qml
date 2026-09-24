pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/*!
    The Hyprland options the settings panel lets the user change: window gaps,
    borders and rounding, the effects, and how the mouse and touchpad feel.

    hyprland.conf stays the source of every default.  A user change is an
    override in Settings like any other, and the shell pushes it with
    `hyprctl keyword` — so an untouched shell leaves the compositor exactly as
    configured, and the conf.d files are never rewritten.

    Hyprland forgets keywords whenever it reloads its config, so on every
    `configreloaded` event the configured values are read afresh and the
    overrides pushed again.  That same reload is how an override is undone:
    there is no keyword for "back to what the file said", so clearing one asks
    Hyprland to reload and lets the re-push restore the rest.

    Every value is an integer on the Settings side, negative meaning unset.
    `kind` says how it maps onto the Hyprland option:
      int      as-is (gaps are read back as "t r b l" and set as one number)
      bool     0 or 1
      percent  a float as a percentage: opacity, scroll speed (100 = 1.0)
      speed    0-200 for a -1..1 sensitivity, 100 being Hyprland's neutral 0
      accel    1 = adaptive, 0 = flat
*/
Singleton {
    id: root

    readonly property var spec: ({
        hyprGapsIn:          { option: "general:gaps_in", kind: "int", min: 0, max: 30 },
        hyprGapsOut:         { option: "general:gaps_out", kind: "int", min: 0, max: 40 },
        hyprBorder:          { option: "general:border_size", kind: "int", min: 0, max: 6 },
        hyprRounding:        { option: "decoration:rounding", kind: "int", min: 0, max: 24 },
        hyprBlur:            { option: "decoration:blur:enabled", kind: "bool" },
        hyprAnimations:      { option: "animations:enabled", kind: "bool" },
        hyprActiveOpacity:   { option: "decoration:active_opacity", kind: "percent", min: 50, max: 100 },
        hyprInactiveOpacity: { option: "decoration:inactive_opacity", kind: "percent", min: 50, max: 100 },
        hyprMouseSpeed:      { option: "input:sensitivity", kind: "speed", min: 0, max: 200 },
        hyprMouseAccel:      { option: "input:accel_profile", kind: "accel" },
        hyprMouseScroll:     { option: "input:scroll_factor", kind: "percent", min: 25, max: 300 },
        hyprTouchpadScroll:  { option: "input:touchpad:scroll_factor", kind: "percent", min: 25, max: 300 },
        hyprNaturalScroll:   { option: "input:touchpad:natural_scroll", kind: "bool" },
        hyprTapToClick:      { option: "input:touchpad:tap-to-click", kind: "bool" },
        // Per device, so the option name needs the touchpad's; see optionFor.
        hyprTouchpadSpeed:   { option: "", kind: "speed", min: 0, max: 200 }
    })

    readonly property var keys: Object.keys(root.spec)

    /*! Name of the built-in touchpad as Hyprland lists it; empty if there is none. */
    property string touchpad: ""
    readonly property bool hasTouchpad: root.touchpad !== ""

    /*! What hyprland.conf set, in the Settings encoding. A key is missing when
        Hyprland cannot report it — device options are write-only. */
    property var configured: ({})

    /*! The override if there is one, else the configured value, else -1. */
    function value(key: string): int {
        const override = Settings[key];
        if (override >= 0)
            return override;
        return root.configured[key] ?? -1;
    }

    function known(key: string): bool {
        return root.value(key) >= 0;
    }

    function set(key: string, v: int): void {
        const s = root.spec[key];
        if (s.min !== undefined)
            v = Math.max(s.min, Math.min(s.max, v));
        Settings.setOverride(key, v);
    }

    function optionFor(key: string): string {
        return key === "hyprTouchpadSpeed" ? `device[${root.touchpad}]:sensitivity` : root.spec[key].option;
    }

    function encode(key: string, v: int): string {
        switch (root.spec[key].kind) {
        case "percent": return String(v / 100);
        case "speed": return String((v - 100) / 100);
        case "accel": return v ? "adaptive" : "flat";
        default: return String(v);
        }
    }

    function decode(key: string, reply: var): int {
        switch (root.spec[key].kind) {
        case "percent": return Math.round(reply.float * 100);
        case "speed": return Math.round((reply.float + 1) * 100);
        case "accel": return reply.str === "flat" ? 0 : 1;
        default: return reply.int ?? parseInt(String(reply.custom ?? "0"));
        }
    }

    // --------------------------------------------------------------- pushing

    /*! Overrides as last pushed; cleared whenever Hyprland reloads. */
    property var applied: ({})
    property var pending: []
    property bool reloadWanted: false

    readonly property var overrides: root.keys.map(k => Settings[k])
    onOverridesChanged: root.sync()

    function sync(): void {
        if (!Settings.ready || probe.running)
            return;
        const next = {};
        for (const key of root.keys) {
            const v = Settings[key];
            if (key === "hyprTouchpadSpeed" && !root.hasTouchpad)
                continue;
            if (v >= 0) {
                next[key] = v;
                if (root.applied[key] !== v)
                    root.pending.push(`keyword ${root.optionFor(key)} ${root.encode(key, v)}`);
            } else if (root.applied[key] !== undefined) {
                root.reloadWanted = true;
            }
        }
        root.applied = next;
        root.flush();
    }

    function flush(): void {
        if (push.running)
            return;
        if (root.reloadWanted) {
            // The reload's own event re-reads and re-pushes everything.
            root.reloadWanted = false;
            root.pending = [];
            push.command = ["hyprctl", "reload"];
        } else if (root.pending.length > 0) {
            push.command = ["hyprctl", "--batch", root.pending.join(" ; ")];
            root.pending = [];
        } else {
            return;
        }
        push.running = true;
    }

    Process {
        id: push
        // A drag that outruns hyprctl queues up behind it rather than racing it.
        onExited: root.flush()
    }

    // --------------------------------------------------------------- reading

    function refresh(): void {
        root.applied = {};
        const reads = root.keys.filter(k => root.spec[k].option !== "")
            .map(k => `getoption ${root.spec[k].option}`);
        probe.command = ["sh", "-c",
            `hyprctl -j devices; hyprctl -j --batch "${reads.join(" ; ")}"`];
        probe.running = true;
    }

    Process {
        id: probe

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // A devices object followed by one bare object per getoption.
                    const replies = JSON.parse("[" + this.text.replace(/}\s*{/g, "},{") + "]");
                    const devices = replies.shift();
                    const pad = (devices.mice ?? []).find(m => /touchpad/i.test(m.name));
                    root.touchpad = pad ? pad.name : "";
                    const byOption = {};
                    for (const r of replies)
                        byOption[r.option] = r;
                    const next = {};
                    for (const key of root.keys) {
                        const reply = byOption[root.spec[key].option];
                        if (reply)
                            next[key] = root.decode(key, reply);
                    }
                    root.configured = next;
                } catch (e) {
                    root.configured = {};
                }
            }
        }
        onExited: root.sync()
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: Settings
        function onReadyChanged(): void { root.sync(); }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded")
                root.refresh();
        }
    }
}
