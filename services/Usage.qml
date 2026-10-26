pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    The machine's usage as the task manager and the date menu show it: rates
    between two consecutive samples of Processes, the facts beside them, and
    the last `span` seconds of each rate for the charts.

    It reads nothing itself and asks for no sample: it hears every one
    Processes takes, which read the machine's counters for as long as the
    shell runs (hard rule 3), so the history holds the last minute whenever a
    chart opens. A rate is -1 until the shell's first two samples are in.
    shell.qml brings it up at the start, for that minute to be there.

    Rates are in percent (CPU to a tenth) or bytes a second; sizes in bytes.
*/
Singleton {
    id: root

    /*! How much sample time the history keeps, in seconds. */
    readonly property int span: 60
    /*! The least time a rate is said over, in seconds: a sample taken sooner
        after the last one rated — a watch's first, asked for a moment after
        the clock's — is passed over, its rates mostly noise (2.7% then 25%
        of the CPU, 10 ms apart). */
    readonly property real least: Processes.firstInterval / 1000
    readonly property var series: ["cpu", "memory", "gpu", "disk", "diskRead", "diskWrite", "netDown", "netUp"]

    /*! Busy ticks of all CPUs, in percent. */
    property real cpu: -1
    /*! Memory not available, in percent of the total: from one sample. */
    property real memory: -1
    /*! The GPU's busy share, in percent. */
    property real gpu: -1
    /*! The busiest disk's busy time, in percent. */
    property real disk: -1
    property real diskRead: -1
    property real diskWrite: -1
    property real netDown: -1
    property real netUp: -1

    /*! The CPUs' mean current frequency, in MHz; 0 unknown. */
    property int cpuFreq: 0
    property real memoryUsed: 0
    property real memoryTotal: 0
    /*! Whether a GPU reports how busy it is: the GPU tab and card follow. */
    property bool hasGpu: false
    /*! The GPU's device name as lspci gives it; "" until it has. */
    property string gpuName: ""
    property real vramUsed: 0
    property real vramTotal: 0
    /*! In °C; -1 where the GPU reports none. */
    property real gpuTemp: -1
    /*! The root filesystem. */
    property real fsUsed: 0
    property real fsTotal: 0
    /*! The largest disk's model. */
    property string diskModel: ""

    /*! Each series' points `{ t, v }` (t the sample's uptime, in seconds)
        over the last `span`, replaced whole on every sample. */
    property var history: root.empty()
    /*! The newest sample's t: where every chart ends. */
    property real now: 0

    property string gpuSlot: ""
    /*! The sample the rates were last said from. */
    property var from: null

    /*! The rates between two samples, as `Processes.parse` gives them;
        `previous` null for none, which leaves only memory. */
    function rates(previous: var, current: var): var {
        const out = { cpu: -1, gpu: -1, disk: -1, diskRead: -1, diskWrite: -1, netDown: -1, netUp: -1, memory: -1 };
        const memory = current.memory;
        if (memory && memory.total > 0)
            out.memory = Math.round((memory.total - memory.available) * 1000 / memory.total) / 10;
        const span = previous ? current.uptime - previous.uptime : 0;
        if (span <= 0)
            return out;
        const ticks = previous.cpuTicks && current.cpuTicks ? current.cpuTicks.total - previous.cpuTicks.total : 0;
        if (ticks > 0)
            out.cpu = Math.round(Math.max(0, current.cpuTicks.busy - previous.cpuTicks.busy) * 1000 / ticks) / 10;
        if (previous.gpu && current.gpu)
            out.gpu = current.gpu.busy;
        const disks = root.deltas(previous.disks, current.disks, ["read", "written", "ioTicks"]);
        if (disks.length > 0) {
            const busiest = Math.max(...disks.map(d => d.ioTicks));
            out.disk = Math.round(Math.min(100, busiest / span / 10) * 10) / 10;
            out.diskRead = Math.round(disks.reduce((sum, d) => sum + d.read, 0) / span);
            out.diskWrite = Math.round(disks.reduce((sum, d) => sum + d.written, 0) / span);
        }
        const nets = root.deltas(previous.nets, current.nets, ["rx", "tx"]);
        if (nets.length > 0) {
            out.netDown = Math.round(nets.reduce((sum, n) => sum + n.rx, 0) / span);
            out.netUp = Math.round(nets.reduce((sum, n) => sum + n.tx, 0) / span);
        }
        return out;
    }

    /*! What each device named in both lists counted between them, a counter
        that went back (a device reset) counting nothing. */
    function deltas(before: var, after: var, keys: var): var {
        const out = [];
        for (const device of after ?? []) {
            const was = (before ?? []).find(d => d.name === device.name);
            if (!was)
                continue;
            const delta = { name: device.name };
            for (const key of keys)
                delta[key] = Math.max(0, device[key] - was[key]);
            out.push(delta);
        }
        return out;
    }

    /*! The points no older than `span` before `now`. */
    function trim(points: var, now: real, span: real): var {
        return points.filter(p => p.t >= now - span);
    }

    function empty(): var {
        const history = {};
        for (const key of root.series)
            history[key] = [];
        return history;
    }

    /*! The device's name in what `lspci -mm` prints: its third quoted field,
        after the class and the vendor. */
    function deviceName(text: string): string {
        const fields = (text.split("\n")[0].match(/"[^"]*"/g) ?? []).map(f => f.slice(1, -1));
        return fields[2] ?? "";
    }

    /*! A size in bytes, in binary units as Processes.formatSize writes one. */
    function formatBytes(bytes: real): string {
        const units = [qsTr("%1 B"), qsTr("%1 KiB"), qsTr("%1 MiB"), qsTr("%1 GiB"), qsTr("%1 TiB")];
        let unit = 0;
        while (bytes >= 1024 && unit < units.length - 1) {
            bytes /= 1024;
            unit++;
        }
        return units[unit].arg(unit < 3 ? Math.round(bytes) : bytes.toFixed(1));
    }

    /*! Bytes a second, a tenth from MiB/s up; "–" for no reading. */
    function formatRate(perSecond: real): string {
        if (perSecond < 0)
            return "–";
        const units = [qsTr("%1 B/s"), qsTr("%1 KiB/s"), qsTr("%1 MiB/s"), qsTr("%1 GiB/s")];
        let unit = 0;
        while (perSecond >= 1024 && unit < units.length - 1) {
            perSecond /= 1024;
            unit++;
        }
        return units[unit].arg(unit < 2 ? Math.round(perSecond) : perSecond.toFixed(1));
    }

    function take(current: var): void {
        if (root.from !== null && current.uptime - root.from.uptime < root.least)
            return;
        const rates = root.rates(root.from, current);
        root.from = current;

        root.cpuFreq = current.cpuFreq;
        if (current.memory) {
            root.memoryTotal = current.memory.total * 1024;
            root.memoryUsed = (current.memory.total - current.memory.available) * 1024;
        }
        const gpu = current.gpu;
        root.hasGpu = gpu !== null;
        root.vramUsed = gpu?.vramUsed ?? 0;
        root.vramTotal = gpu?.vramTotal ?? 0;
        root.gpuTemp = gpu?.temp ?? -1;
        if (gpu && gpu.slot !== "" && gpu.slot !== root.gpuSlot) {
            root.gpuSlot = gpu.slot;
            namer.run();
        }
        root.fsUsed = current.fs?.used ?? 0;
        root.fsTotal = current.fs?.total ?? 0;
        const largest = current.disks.reduce((most, d) => !most || d.size > most.size ? d : most, null);
        root.diskModel = largest?.model ?? "";

        const t = current.uptime;
        const history = {};
        for (const key of root.series)
            history[key] = root.trim(rates[key] < 0 ? root.history[key]
                                     : root.history[key].concat([{ t, v: rates[key] }]), t, root.span);
        root.now = t;
        root.history = history;
        // The rates last, so whatever hears one finds the facts and the
        // history of this sample in.
        for (const key of root.series)
            root[key] = rates[key];
    }

    Connections {
        target: Processes

        function onSampled(previous: var, current: var): void {
            root.take(current);
        }
    }

    Probe {
        id: namer
        command: ["lspci", "-mm", "-s", root.gpuSlot]
        stdout: StdioCollector { onStreamFinished: root.gpuName = root.deviceName(this.text) }
    }
}
