pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    Every process on the machine, as the task manager lists it, memory as
    earlyoom reckons it, and the machine's own counters, which Usage turns
    into rates.

    /proc and /sys say nothing when a process works, memory fills or a disk
    or the network moves, so this is read on a clock, the one reading besides
    a clock's own that is (hard rule 3), each sample `sampleInterval` after
    the last one ended, so two never overlap. The machine's counters — CPU,
    memory, disks, network, GPU — are read for as long as the shell runs, so
    that Usage holds the last minute whenever a chart opens; one gawk run
    without the processes (ProcessSampler) costs a few milliseconds. Each
    process is read as well only while something lists them (`watch`, a key
    each: the task manager's Processes, Disk and Memory tabs): about 43 ms
    for 340 processes. A sample without them leaves `list` as it was.

    CPU and I/O are what a process used between two samples that read the
    processes, over the time between them, so a process seen once has none
    yet; the second sample of a watch comes sooner, to have them. A process's
    I/O is readable for the user's own processes alone; another's is -1.

    Kernel threads (kthreadd's children) are left out: they hold no memory of
    their own, and nothing in the list is for them.
*/
Singleton {
    id: root

    /*! Whether each process is read too: while any watcher's key is on. */
    readonly property bool watched: Object.keys(root.watchers).length > 0
    /*! The keys watching, replaced on every change so `watched` hears it. */
    property var watchers: ({})
    readonly property int sampleInterval: 2000
    /*! The second sample of a watch, the first with each process's CPU and
        I/O. */
    readonly property int firstInterval: 500
    /*! USER_HZ, what /proc counts CPU time in: 100 on every architecture the
        desktop runs on. */
    readonly property int hz: 100

    /*! Samples taken since the shell started. */
    property int samples: 0
    /*! The processes, each `{ pid, uid, ppid, ticks, rss, oomScore, oomAdj,
        readBytes, writeBytes, name, cpu, io, own, user }`: memory in KiB, cpu
        in percent, io in bytes a second, -1 unknown. */
    property var list: []
    property var byPid: ({})
    /*! In KiB: `{ total, available, anon, swapTotal, swapFree }`. */
    property var memory: ({ total: 0, available: 0, anon: 0, swapTotal: 0, swapFree: 0 })
    /*! The shell's own uid: whose processes it may end. */
    property int uid: -1

    /*! The latest sample as `parse` gives it. */
    property var last: null
    /*! The latest that read the processes, in this watch; and how many have. */
    property var lastListed: null
    property int listed: 0

    /*! After every sample, with it and the one before it (null for the
        shell's first), both as `parse` gives them. */
    signal sampled(var previous, var current)

    /*! Starts (`on`) or ends one watcher's watch: the task manager's, the date
        menu's. A key is on or off, not counted. */
    function watch(key: string, on: bool): void {
        if ((key in root.watchers) === on)
            return;
        const watchers = Object.assign({}, root.watchers);
        if (on)
            watchers[key] = true;
        else
            delete watchers[key];
        root.watchers = watchers;
    }

    // The counters from the first use on: Usage keeps their last minute.
    Component.onCompleted: sampler.run()

    onWatchedChanged: {
        if (!root.watched)
            return;
        // A watch's processes at once, and again soon after for their CPU.
        root.lastListed = null;
        root.listed = 0;
        next.stop();
        sampler.run();
    }

    /*! A sample as the sampler prints it, a field a tab: `{ uptime, cpus,
        uid, memory, users, list, cpuTicks: { busy, total }, cpuFreq, disks:
        [{ name, model, size, read, written, ioTicks }], fs: { total, used },
        nets: [{ name, rx, tx }], gpu: { slot, busy, vramUsed, vramTotal, temp }
        }` — sizes in bytes, the frequency in MHz, io ticks in ms, the
        temperature in °C or -1. What the machine lacks is absent: no disks,
        `fs` or `gpu` null, `cpuFreq` 0. */
    function parse(text: string): var {
        const sample = { uptime: 0, cpus: 1, uid: -1, memory: null, users: {}, list: [],
                         cpuTicks: null, cpuFreq: 0, disks: [], fs: null, nets: [], gpu: null };
        for (const line of text.split("\n")) {
            const f = line.split("\t");
            const n = f.map(Number);
            switch (f[0]) {
            case "uptime": sample.uptime = n[1]; break;
            case "cpus": sample.cpus = Math.max(1, n[1]); break;
            case "uid": sample.uid = n[1]; break;
            case "user": sample.users[n[1]] = f[2]; break;
            case "mem":
                sample.memory = { total: n[1], available: n[2], anon: n[3], swapTotal: n[4], swapFree: n[5] };
                break;
            case "cpu": {
                // user nice system idle iowait irq softirq steal
                const total = n.slice(1, 9).reduce((sum, ticks) => sum + ticks, 0);
                sample.cpuTicks = { busy: total - n[4] - n[5], total };
                break;
            }
            case "freq": sample.cpuFreq = n[1]; break;
            case "fs": sample.fs = { total: n[1] * 1024, used: n[2] * 1024 }; break;
            case "disk":
                sample.disks.push({ name: f[1], model: f.slice(6).join("\t"), size: n[2] * 512,
                                    read: n[3] * 512, written: n[4] * 512, ioTicks: n[5] });
                break;
            case "net": sample.nets.push({ name: f[1], rx: n[2], tx: n[3] }); break;
            case "gpu":
                sample.gpu = { slot: f[1], busy: n[2], vramUsed: n[3], vramTotal: n[4],
                               temp: n[5] < 0 ? -1 : Math.round(n[5] / 100) / 10 };
                break;
            case "p": {
                const name = f.slice(10).join("\t");
                if (name !== "")
                    sample.list.push({ pid: n[1], uid: n[2], ppid: n[3], ticks: n[4], rss: n[5], oomScore: n[6],
                                       oomAdj: n[7], readBytes: n[8], writeBytes: n[9], name });
                break;
            }
            }
        }
        return sample;
    }

    /*! Each pid's CPU between two samples, in percent of the whole machine
        to a tenth; -1 for one the earlier sample did not have. */
    function cpu(previous: var, current: var, cpus: int): var {
        const before = {};
        for (const p of previous.list)
            before[p.pid] = p.ticks;
        const span = (current.uptime - previous.uptime) * root.hz * cpus;
        const out = {};
        for (const p of current.list)
            out[p.pid] = p.pid in before && span > 0
                ? Math.round(Math.max(0, p.ticks - before[p.pid]) * 1000 / span) / 10 : -1;
        return out;
    }

    /*! Each pid's disk I/O between two samples, read and written, in bytes a
        second; -1 for one unreadable in either, or new. */
    function io(previous: var, current: var): var {
        const before = {};
        for (const p of previous.list)
            if (p.readBytes >= 0 && p.writeBytes >= 0)
                before[p.pid] = p.readBytes + p.writeBytes;
        const span = current.uptime - previous.uptime;
        const out = {};
        for (const p of current.list)
            out[p.pid] = p.pid in before && p.readBytes >= 0 && p.writeBytes >= 0 && span > 0
                ? Math.max(0, p.readBytes + p.writeBytes - before[p.pid]) / span : -1;
        return out;
    }

    function take(text: string): void {
        const previous = root.last;
        const sample = root.parse(text);
        if (sample.list.length > 0)
            root.list = root.listing(root.lastListed, sample);
        root.last = sample;
        root.uid = sample.uid;
        if (sample.memory)
            root.memory = sample.memory;
        root.samples++;
        root.sampled(previous, sample);
    }

    /*! The list a sample that read the processes gives, CPU and I/O against
        the one before it that did (`byPid` with it). */
    function listing(previous: var, sample: var): var {
        const cpu = previous ? root.cpu(previous, sample, sample.cpus) : {};
        const io = previous ? root.io(previous, sample) : {};
        const byPid = {};
        const list = [];
        for (const p of sample.list) {
            if (p.pid === 2 || p.ppid === 2)
                continue;
            const entry = Object.assign({}, p, {
                cpu: cpu[p.pid] ?? -1, io: io[p.pid] ?? -1, own: p.uid === sample.uid,
                user: sample.users[p.uid] ?? String(p.uid)
            });
            byPid[p.pid] = entry;
            list.push(entry);
        }
        root.lastListed = sample;
        root.listed++;
        // Before the list, which the rows are kept by and read this from.
        root.byPid = byPid;
        return list;
    }

    /*! A size in KiB, as the task manager shows one. */
    function formatSize(kib: real): string {
        if (kib < 1024)
            return qsTr("%1 KiB").arg(Math.round(kib));
        if (kib < 1024 * 1024)
            return qsTr("%1 MiB").arg(Math.round(kib / 1024));
        return qsTr("%1 GiB").arg((kib / 1024 / 1024).toFixed(1));
    }

    /*! A sample now, the next timed from it. */
    function sample(): void {
        sampler.run();
    }

    /*! SIGTERM to one of the shell's own processes; false for another's. */
    function terminate(pid: int): bool {
        return root.signal(pid, "TERM");
    }

    /*! SIGKILL, likewise. */
    function forceKill(pid: int): bool {
        return root.signal(pid, "KILL");
    }

    function signal(pid: int, name: string): bool {
        if (root.byPid[pid]?.own !== true)
            return false;
        Quickshell.execDetached(["kill", "-" + name, String(pid)]);
        sampler.run();
        return true;
    }

    ProcessSampler {
        id: sampler
        processes: root.watched
        onRead: text => root.take(text)
        onRunningChanged: if (!sampler.running) next.restart()
    }

    Timer {
        id: next
        interval: root.watched && root.listed < 2 ? root.firstInterval : root.sampleInterval
        onTriggered: sampler.run()
    }
}
