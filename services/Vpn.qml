pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    The bar's VPN menu: the NetworkManager connections it offers, how long
    each takes to answer, and whether anything in it is up. v2rayN, its other
    row, is V2rayn's.

    Which connections: those `Settings.vpnConnections` names, since
    NetworkManager also keeps profiles nobody wants one click away.

    Connection states are event-driven: `nmcli monitor` reports every change
    and the list is read again after it. Latency has no event to listen to, so
    every row's is measured every five minutes, and at once when a connection
    comes up.
*/
Singleton {
    id: root

    /*! Names from Settings.vpnConnections that NetworkManager has, in that order. */
    readonly property var connections: Settings.vpnConnections.filter(n => n in root.states)
    /*! Every VPN profile NetworkManager has, name to activation state:
        "activated", "activating", "deactivating", or "" while down. */
    property var states: ({})
    /*! Name to the last round trip through it in ms, -1 for no reply. */
    property var latencies: ({})
    /*! Name to why the last switch failed, until the next one. */
    property var failures: ({})
    /*! The connection being switched on or off, if any. */
    property string switching: ""

    readonly property var upConnections: root.connections.filter(n => root.states[n] === "activated")

    readonly property bool available: root.connections.length > 0 || V2rayn.available
    readonly property bool anyActive: root.upConnections.length > 0 || V2rayn.active

    readonly property int latencyInterval: 5 * 60 * 1000
    /*! Seconds a ping may take. */
    readonly property int pingTimeout: 3
    /*! nmcli monitor reports one change as several lines. */
    readonly property int settleTime: 250

    function isActive(name: string): bool {
        return root.states[name] === "activated";
    }

    function status(name: string): string {
        const state = root.states[name] ?? "";
        if (state === "activating")
            return qsTr("Connecting…");
        if (state === "deactivating")
            return qsTr("Disconnecting…");
        if (state !== "activated")
            return root.failures[name] ?? qsTr("Off");
        const ms = root.latencies[name];
        if (ms === undefined)
            return qsTr("Connected");
        return ms < 0 ? qsTr("Connected · no reply") : qsTr("Connected · %1 ms").arg(ms);
    }

    function toggle(name: string): void {
        if (switcher.running || !(name in root.states))
            return;
        const state = root.states[name];
        switcher.up = state !== "activated" && state !== "activating";
        const failures = Object.assign({}, root.failures);
        delete failures[name];
        root.failures = failures;
        root.switching = name;
        switcher.running = true;
    }

    function measure(): void {
        if (root.upConnections.length > 0)
            pinger.run();
    }

    /*! nmcli's terse output: fields split on ':', with ':' and '\' escaped. */
    function terseFields(line: string): var {
        const fields = [""];
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length)
                fields[fields.length - 1] += line[++i];
            else if (line[i] === ":")
                fields.push("");
            else
                fields[fields.length - 1] += line[i];
        }
        return fields;
    }

    function readStates(text: string): void {
        const next = {};
        for (const line of text.split("\n")) {
            const [name, type, state] = root.terseFields(line);
            if (type === "vpn" || type === "wireguard")
                next[name] = state ?? "";
        }
        const cameUp = Object.keys(next).some(n => next[n] === "activated" && root.states[n] !== "activated");
        // A reading belongs to the session it was taken in.
        const latencies = {};
        for (const name in root.latencies)
            if (next[name] === "activated")
                latencies[name] = root.latencies[name];
        root.states = next;
        root.latencies = latencies;
        if (cameUp)
            root.measure();
    }

    function readLatencies(text: string): void {
        const next = Object.assign({}, root.latencies);
        for (const line of text.split("\n")) {
            const tab = line.lastIndexOf("\t");
            if (tab > 0)
                next[line.slice(0, tab)] = Math.round(parseFloat(line.slice(tab + 1)));
        }
        root.latencies = next;
    }

    Process {
        id: monitor
        running: Settings.vpnConnections.length > 0
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: settle.restart() }
        onRunningChanged: if (monitor.running) lister.run()
    }

    Timer {
        id: settle
        interval: root.settleTime
        onTriggered: lister.run()
    }

    Probe {
        id: lister
        command: ["nmcli", "-t", "-f", "NAME,TYPE,STATE", "connection", "show"]
        stdout: StdioCollector { onStreamFinished: root.readStates(this.text) }
    }

    Process {
        id: switcher

        property bool up: true

        command: ["nmcli", "connection", switcher.up ? "up" : "down", "id", root.switching]
        onExited: code => {
            if (code !== 0) {
                const failures = Object.assign({}, root.failures);
                failures[root.switching] = switcher.up ? qsTr("Could not connect") : qsTr("Could not disconnect");
                root.failures = failures;
            }
            root.switching = "";
        }
    }

    Probe {
        id: pinger
        // Through the tunnel to its far end, or to its first DNS server where
        // NetworkManager reports no gateway for it.
        command: ["sh", "-c", "for name; do "
            + "gw=$(nmcli -g IP4.GATEWAY connection show id \"$name\"); "
            + "[ -n \"$gw\" ] || gw=$(nmcli -g IP4.DNS connection show id \"$name\"); "
            + "ms=$(ping -n -q -c 1 -W " + root.pingTimeout + " \"${gw%% *}\" 2>/dev/null "
            + "| sed -n 's|^rtt[^=]*= [^/]*/\\([^/]*\\)/.*|\\1|p'); "
            + "printf '%s\\t%s\\n' \"$name\" \"${ms:--1}\"; done", "sh"].concat(root.upConnections)
        stdout: StdioCollector { onStreamFinished: root.readLatencies(this.text) }
    }

    // One of the shell's two repeating timers (Time's clock is the other):
    // latency changes with no event to say so. Every five minutes, and only
    // while there is something to measure.
    Timer {
        interval: root.latencyInterval
        repeat: true
        running: root.upConnections.length > 0 || V2rayn.available
        onTriggered: {
            root.measure();
            V2rayn.measure();
        }
    }
}
