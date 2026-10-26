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
    each: the task manager's tabs that rank processes): about 43 ms for 340
    processes. A sample without them leaves `list` as it was. What a watcher
    asks for beyond them (`extras`) is read only while one asks: each own
    process's GPU time ("gpu") and its open inet sockets ("net").

    CPU, GPU and I/O are what a process used between two samples that read
    the processes, over the time between them, so a process seen once has
    none yet; the second sample of a watch, or of an extra newly asked for,
    comes sooner, to have them. A process's I/O, GPU time and sockets are
    readable for the user's own processes alone; another's are -1.

    Kernel threads (kthreadd's children) are left out: they hold no memory of
    their own, and nothing in the list is for them.
*/
Singleton {
    id: root

    /*! Whether each process is read too: while any watcher's key is on. */
    readonly property bool watched: Object.keys(root.watchers).length > 0
    /*! Each watching key's extras, replaced on every change so `watched`
        and `extras` hear it. */
    property var watchers: ({})
    /*! What the watchers ask for beyond the processes, each once, sorted:
        "gpu", "net". */
    readonly property var extras: [].concat(...Object.values(root.watchers))
        .filter((extra, i, all) => all.indexOf(extra) === i).sort()
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
        readBytes, writeBytes, gpuTime, connections, name, cpu, io, gpu, own,
        user }`: memory in KiB, cpu and gpu in percent (of the whole machine,
        of the GPU), io in bytes a second, gpuTime in ns, connections a count;
        -1 unknown or not asked for. */
    property var list: []
    property var byPid: ({})
    /*! In KiB: `{ total, available, anon, swapTotal, swapFree }`. */
    property var memory: ({ total: 0, available: 0, anon: 0, swapTotal: 0, swapFree: 0 })
    /*! The shell's own uid: whose processes it may end. */
    property int uid: -1

    /*! The latest sample as `parse` gives it. */
    property var last: null
    /*! The latest that read the processes, in this watch; and how many have,
        and since what is read last grew. */
    property var lastListed: null
    property int listed: 0
    property int fresh: 0

    /*! After every sample, with it and the one before it (null for the
        shell's first), both as `parse` gives them. */
    signal sampled(var previous, var current)

    /*! Starts (`on`) or ends one watcher's watch, asking for `extras` beside
        the processes ("gpu", "net"; none if left out): the task manager's
        tabs. A key is on or off, not counted; on again, it asks anew. */
    function watch(key: string, on: bool, extras: var): void {
        const asked = on ? (extras ?? []).filter((extra, i, all) => all.indexOf(extra) === i).sort() : null;
        if (JSON.stringify(root.watchers[key] ?? null) === JSON.stringify(asked))
            return;
        const was = root.watched;
        const before = root.extras;
        const watchers = Object.assign({}, root.watchers);
        if (on)
            watchers[key] = asked;
        else
            delete watchers[key];
        root.watchers = watchers;
        if (!root.watched || was && root.extras.every(extra => before.includes(extra)))
            return;
        // A watch's processes at once, and again soon after for their CPU;
        // likewise an extra newly asked for, the sample under way, if any,
        // without it.
        if (!was) {
            root.lastListed = null;
            root.listed = 0;
        }
        root.fresh = was && sampler.running ? -1 : 0;
        next.stop();
        sampler.run();
    }

    // The counters from the first use on: Usage keeps their last minute.
    Component.onCompleted: sampler.run()

    /*! A sample as the sampler prints it: see ProcessSampler.parse. */
    function parse(text: string): var {
        return sampler.parse(text);
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

    /*! Each pid's share of the GPU between two samples — its clients' engine
        time over the time between them — in percent to a tenth, at most 100
        (two engines busy at once are the whole GPU); -1 for one without a
        client in either. */
    function gpu(previous: var, current: var): var {
        const before = {};
        for (const p of previous.list)
            if (p.gpuTime >= 0)
                before[p.pid] = p.gpuTime;
        const span = (current.uptime - previous.uptime) * 1e9;
        const out = {};
        for (const p of current.list)
            out[p.pid] = p.pid in before && p.gpuTime >= 0 && span > 0
                ? Math.round(Math.min(1000, Math.max(0, p.gpuTime - before[p.pid]) * 1000 / span)) / 10 : -1;
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

    /*! The list a sample that read the processes gives, CPU, GPU and I/O
        against the one before it that did (`byPid` with it). */
    function listing(previous: var, sample: var): var {
        const cpu = previous ? root.cpu(previous, sample, sample.cpus) : {};
        const gpu = previous ? root.gpu(previous, sample) : {};
        const io = previous ? root.io(previous, sample) : {};
        const byPid = {};
        const list = [];
        for (const p of sample.list) {
            if (p.pid === 2 || p.ppid === 2)
                continue;
            const entry = Object.assign({}, p, {
                cpu: cpu[p.pid] ?? -1, io: io[p.pid] ?? -1, gpu: gpu[p.pid] ?? -1, own: p.uid === sample.uid,
                user: sample.users[p.uid] ?? String(p.uid)
            });
            byPid[p.pid] = entry;
            list.push(entry);
        }
        root.lastListed = sample;
        root.listed++;
        root.fresh++;
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
        gpu: root.extras.includes("gpu")
        net: root.extras.includes("net")
        onRead: text => root.take(text)
        onRunningChanged: if (!sampler.running) next.restart()
    }

    Timer {
        id: next
        interval: root.watched && root.fresh < 2 ? root.firstInterval : root.sampleInterval
        onTriggered: sampler.run()
    }
}
