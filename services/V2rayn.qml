pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    v2rayN: its active server, how long a request through it takes, and — in
    TUN mode — a switch.

    v2rayN is an application of its own with no control from outside, so all
    of this is read from the files it writes: its settings (the proxy port,
    the delay-test URL, the active server's id, whether TUN mode is on), its
    database (the server's name) and the TUN core's config (where that core's
    Clash API listens, and the TUN's name).

    The switch is the TUN core's routing mode: Rule routes as v2rayN's
    routing says, Direct sends everything straight out. The TUN stays up
    either way, so switching needs no administrator rights and applies to
    every new connection at once; those already open finish as they are.
    sing-box keeps the mode across restarts, and nothing in v2rayN sets it.

    The core starts after its config is written, so it is measured again
    once its TUN comes up, which `ip monitor` reports.
*/
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_DATA_HOME")
        || Quickshell.env("HOME") + "/.local/share") + "/v2rayN"

    /*! Its local proxy port, 0 while v2rayN is not installed. */
    property int port: 0
    property string testUrl: ""
    property string index: ""
    property bool tun: false
    /*! The active server's name, as v2rayN's list shows it. */
    property string server: ""
    /*! "up" (a request through the proxy got an answer), "off" (nothing is
        listening: v2rayN is not running), "failing", or "" before a test. */
    property string reach: ""
    property int latency: -1
    /*! From the TUN core's config, which stays on disk after TUN mode is off. */
    property string coreApi: ""
    property string tunName: ""
    readonly property string api: root.tun ? root.coreApi : ""
    /*! The TUN core's routing mode, "Rule", "Global" or "Direct"; empty
        while it cannot be read — no TUN mode, or v2rayN not running. */
    property string mode: ""

    readonly property bool available: root.port > 0
    readonly property bool canSwitch: root.mode !== ""
    readonly property bool direct: root.mode === "Direct"
    readonly property bool active: root.reach === "up" && !root.direct

    /*! Seconds a request through the proxy, or to the core's API, may take. */
    readonly property int delayTimeout: 10
    readonly property int apiTimeout: 3
    /*! The core finishes starting a moment after its TUN is up. */
    readonly property int startupGrace: 1000
    /*! What v2rayN itself measures a server's delay with, unless set otherwise. */
    readonly property string defaultTestUrl: "https://www.google.com/generate_204"

    readonly property string status: {
        const parts = root.direct ? [qsTr("Off")] : [];
        if (root.server !== "")
            parts.push(root.server);
        if (root.reach === "up")
            parts.push(qsTr("%1 ms").arg(root.latency));
        else if (root.reach === "off")
            parts.push(qsTr("Not running"));
        else if (root.reach === "failing")
            parts.push(qsTr("No response"));
        return parts.join(" · ");
    }

    function measure(): void {
        if (!root.available)
            return;
        delay.run();
        root.readMode();
    }

    function readMode(): void {
        if (root.api !== "")
            modeReader.run();
        else
            root.mode = "";
    }

    // The two files load in no set order; whichever completes the address reads.
    onApiChanged: root.readMode()

    function toggle(): void {
        if (!root.canSwitch || switcher.running)
            return;
        switcher.target = root.direct ? "Rule" : "Direct";
        switcher.running = true;
    }

    function parse(text: string): var {
        try {
            return JSON.parse(text);
        } catch (e) {
            return null; // caught mid-write, or no answer
        }
    }

    function readSettings(text: string): void {
        const config = root.parse(text);
        if (!config)
            return;
        root.port = Number(config.Inbound?.[0]?.LocalPort ?? 0);
        root.testUrl = String(config.SpeedTestItem?.SpeedPingTestUrl || root.defaultTestUrl);
        root.tun = config.TunModeItem?.EnableTun === true;
        const index = String(config.IndexId ?? "");
        if (index !== root.index) {
            root.index = index;
            root.server = "";
            // The id goes into the query, so it must be the number it should be.
            if (/^\d+$/.test(index))
                serverReader.run();
        }
        root.measure();
    }

    function readCore(text: string): void {
        const config = root.parse(text);
        if (!config)
            return;
        const api = String(config.experimental?.clash_api?.external_controller ?? "");
        root.coreApi = api !== "" ? "http://" + api : "";
        const tun = (config.inbounds ?? []).find(i => i.type === "tun");
        root.tunName = String(tun?.interface_name ?? "");
    }

    function readDelay(text: string): void {
        const [exitCode, httpCode, seconds] = text.trim().split(" ");
        const answered = exitCode === "0" && Number(httpCode) >= 200 && Number(httpCode) < 400;
        root.reach = answered ? "up" : exitCode === "7" ? "off" : "failing";
        root.latency = answered ? Math.round(parseFloat(seconds) * 1000) : -1;
    }

    // The latency of the whole path, as v2rayN's own delay test takes it: a
    // request through its local proxy.
    Probe {
        id: delay
        command: ["curl", "-s", "-o", "/dev/null", "--max-time", String(root.delayTimeout),
            "-x", "socks5h://127.0.0.1:" + root.port,
            "-w", "%{exitcode} %{http_code} %{time_total}", root.testUrl]
        stdout: StdioCollector { onStreamFinished: root.readDelay(this.text) }
    }

    Probe {
        id: modeReader
        command: ["curl", "-s", "-f", "--max-time", String(root.apiTimeout), root.api + "/configs"]
        stdout: StdioCollector { onStreamFinished: root.mode = String(root.parse(this.text)?.mode ?? "") }
    }

    Process {
        id: switcher

        property string target: ""

        command: ["curl", "-s", "-f", "--max-time", String(root.apiTimeout), "-X", "PATCH",
            "-d", JSON.stringify({ mode: switcher.target }), root.api + "/configs"]
        // Whatever happened, the core says what it is now.
        onExited: modeReader.run()
    }

    Probe {
        id: serverReader
        command: ["sqlite3", "-readonly", root.dir + "/guiConfigs/guiNDB.db",
            "select Remarks from ProfileItem where IndexId = '" + root.index + "'"]
        stdout: StdioCollector { onStreamFinished: root.server = this.text.trim() }
    }

    Process {
        running: root.api !== "" && root.tunName !== ""
        command: ["ip", "-o", "monitor", "link"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes(" " + root.tunName + ":"))
                    started.restart();
            }
        }
    }

    Timer {
        id: started
        interval: root.startupGrace
        onTriggered: root.measure()
    }

    FileView {
        id: settings
        path: root.dir + "/guiConfigs/guiNConfig.json"
        watchChanges: true
        printErrors: false
        onFileChanged: settings.reload()
        onLoaded: root.readSettings(settings.text())
        onLoadFailed: root.port = 0
    }

    FileView {
        id: core
        path: root.dir + "/binConfigs/configPre.json"
        watchChanges: true
        printErrors: false
        onFileChanged: core.reload()
        onLoaded: root.readCore(core.text())
    }
}
