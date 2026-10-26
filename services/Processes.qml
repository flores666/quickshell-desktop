pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    Every process on the machine, as the task manager lists it, and memory as
    earlyoom reckons it.

    /proc says nothing when a process starts, ends or works, so this is read
    on a clock, the one reading besides a clock's own that is (hard rule 3):
    only while `watched` — the task manager open on Processes or Memory — and
    each sample `sampleInterval` after the last one ended, so two never
    overlap. One gawk run reads every process's stat, status and OOM score
    with uptime and meminfo, about 26 ms for 340 processes.

    CPU is the ticks a process used between two samples over the time between
    them, as a share of the whole machine, so a process seen once has none
    yet; the second sample of a watch comes sooner, to have it.

    Kernel threads (kthreadd's children) are left out: they hold no memory of
    their own, and nothing in the list is for them.
*/
Singleton {
    id: root

    /*! Whether to sample: bound by the task manager while it shows a reading. */
    property bool watched: false
    readonly property int sampleInterval: 2000
    /*! The second sample of a watch, the first with CPU. */
    readonly property int firstInterval: 500
    /*! USER_HZ, what /proc counts CPU time in: 100 on every architecture the
        desktop runs on. */
    readonly property int hz: 100

    /*! Samples taken since the shell started. */
    property int samples: 0
    /*! The processes, each `{ pid, uid, ppid, ticks, rss, oomScore, oomAdj,
        name, cpu, own, user }`: memory in KiB, cpu in percent, -1 unknown. */
    property var list: []
    property var byPid: ({})
    /*! In KiB: `{ total, available, anon, swapTotal, swapFree }`. */
    property var memory: ({ total: 0, available: 0, anon: 0, swapTotal: 0, swapFree: 0 })
    /*! The shell's own uid: whose processes it may end. */
    property int uid: -1

    property var last: null
    property int watchSamples: 0

    onWatchedChanged: {
        if (root.watched) {
            root.last = null;
            root.watchSamples = 0;
            sampler.run();
        } else {
            next.stop();
        }
    }

    /*! A sample as the sampler prints it, a field a tab:
        `{ uptime, cpus, uid, memory, users, list }`. */
    function parse(text: string): var {
        const sample = { uptime: 0, cpus: 1, uid: -1, memory: null, users: {}, list: [] };
        for (const line of text.split("\n")) {
            const f = line.split("\t");
            switch (f[0]) {
            case "uptime": sample.uptime = Number(f[1]); break;
            case "cpus": sample.cpus = Math.max(1, Number(f[1])); break;
            case "uid": sample.uid = Number(f[1]); break;
            case "user": sample.users[Number(f[1])] = f[2]; break;
            case "mem":
                sample.memory = { total: Number(f[1]), available: Number(f[2]), anon: Number(f[3]),
                                  swapTotal: Number(f[4]), swapFree: Number(f[5]) };
                break;
            case "p": {
                const name = f.slice(8).join("\t");
                if (name !== "")
                    sample.list.push({ pid: Number(f[1]), uid: Number(f[2]), ppid: Number(f[3]),
                                       ticks: Number(f[4]), rss: Number(f[5]), oomScore: Number(f[6]),
                                       oomAdj: Number(f[7]), name });
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

    function take(text: string): void {
        const sample = root.parse(text);
        const cpu = root.last ? root.cpu(root.last, sample, sample.cpus) : {};
        const byPid = {};
        const list = [];
        for (const p of sample.list) {
            if (p.pid === 2 || p.ppid === 2)
                continue;
            const entry = Object.assign({}, p, {
                cpu: cpu[p.pid] ?? -1, own: p.uid === sample.uid, user: sample.users[p.uid] ?? String(p.uid)
            });
            byPid[p.pid] = entry;
            list.push(entry);
        }
        root.last = sample;
        root.uid = sample.uid;
        if (sample.memory)
            root.memory = sample.memory;
        root.byPid = byPid;
        root.list = list;
        root.watchSamples++;
        root.samples++;
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

    readonly property string program: `
        BEGINFILE { if (ERRNO != "") nextfile }
        FILENAME == "uptime" { print "uptime\\t" $1; next }
        FILENAME == "stat" { if ($1 ~ /^cpu[0-9]/) cpus++; next }
        FILENAME == "meminfo" { mem[$1] = $2; next }
        FILENAME == "/etc/passwd" { split($0, f, ":"); print "user\\t" f[3] "\\t" f[1]; next }
        {
            split(FILENAME, path, "/")
            pid = path[1]
            if (path[2] == "stat") {
                from = index($0, "(")
                to = match($0, /\\)[^)]*$/)
                name[pid] = substr($0, from + 1, to - from - 1)
                split(substr($0, to + 2), f, " ")
                ppid[pid] = f[2]
                ticks[pid] = f[12] + f[13]
            } else if (path[2] == "status") {
                if ($1 == "Uid:") uid[pid] = $2
                else if ($1 == "VmRSS:") rss[pid] = $2
            } else if (path[2] == "oom_score") {
                score[pid] = $1
            } else {
                adj[pid] = $1
            }
        }
        END {
            print "cpus\\t" cpus
            print "uid\\t" PROCINFO["uid"]
            print "mem\\t" mem["MemTotal:"] "\\t" mem["MemAvailable:"] "\\t" mem["AnonPages:"] \\
                "\\t" mem["SwapTotal:"] "\\t" mem["SwapFree:"]
            for (pid in name)
                if (pid in uid)
                    print "p\\t" pid "\\t" uid[pid] "\\t" ppid[pid] "\\t" ticks[pid] "\\t" rss[pid] + 0 \\
                        "\\t" score[pid] + 0 "\\t" adj[pid] + 0 "\\t" name[pid]
        }`

    Probe {
        id: sampler
        command: ["sh", "-c", "cd /proc && exec gawk \"$0\" uptime stat meminfo /etc/passwd "
            + "[0-9]*/stat [0-9]*/status [0-9]*/oom_score [0-9]*/oom_score_adj", root.program]
        stdout: StdioCollector { onStreamFinished: root.take(this.text) }
        onRunningChanged: if (!sampler.running && root.watched) next.restart()
    }

    Timer {
        id: next
        interval: root.watchSamples < 2 ? root.firstInterval : root.sampleInterval
        onTriggered: sampler.run()
    }
}
