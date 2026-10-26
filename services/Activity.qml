pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    Which processes have used each thing most over the last minute, for the
    task manager's "Using it most": CPU, GPU and disk I/O over the samples of
    the last `Usage.span` seconds that read the processes, and memory and
    open connections as they stand in the latest.

    It reads nothing itself: it hears every Processes sample, records each
    that read the processes (only what was above 0, so a record is a few
    dozen entries), and drops a record once it is older than the span —
    heard on every sample, the machine's counters' too, so a ranking empties
    within a minute of the last watch. The history is not emptied when the
    watch ends: a tab come back to within the minute shows what was busy.

    A process that has gone quiet, or ended, stays ranked, by the name it
    last had, until its last busy sample falls out of the window. A mean is
    over the samples in the window that read that figure, each counting
    once whatever time it spans, a sample in which the process was not busy
    counting 0. Ranking is done once a sample, whole, into `ranked`: a
    binding to `top` hears `ranked` alone and is evaluated once a sample.
*/
Singleton {
    id: root

    readonly property var keys: ["cpu", "gpu", "io", "rss", "connections"]

    /*! Each sample that read the processes in the window, oldest first:
        `{ t, names, cpu, gpu, io, rss, connections }`, each figure a map of
        pid to what was above 0, null where the sample did not read it; rss
        and connections only in the latest. */
    property var records: []
    /*! Each key's whole ranking, as `rank` gives it, replaced once a
        sample. */
    property var ranked: ({ cpu: [], gpu: [], io: [], rss: [], connections: [] })
    /*! Bumped as `ranked` is replaced. */
    property int revision: 0

    /*! The `count` processes that used `key` most over the last minute —
        "cpu" and "gpu" (mean %), "io" (mean bytes a second), "rss" (KiB now),
        "connections" (now) — as `rank` gives them. */
    function top(key: string, count: int): var {
        return (root.ranked[key] ?? []).slice(0, count);
    }

    /*! What a listed sample at `t` is recorded as: each figure's pids above
        0, the figure null where no process has a reading of it (-1 for all:
        not asked for, or the first sample of a watch). */
    function record(list: var, t: real): var {
        const record = { t, names: {}, cpu: null, gpu: null, io: null, rss: null, connections: null };
        for (const p of list) {
            for (const key of root.keys) {
                const value = p[key] ?? -1;
                if (value < 0)
                    continue;
                record[key] = record[key] ?? {};
                if (value > 0) {
                    record[key][p.pid] = value;
                    record.names[p.pid] = p.name;
                }
            }
        }
        return record;
    }

    /*! `records`' processes ranked by `key` over the `span` seconds up to
        `now`: `[{ pid, name, value, now }]`, best first, ties by pid, those
        above 0 alone, at most `count` (all if negative). Percentages to a
        tenth, bytes a second whole. `now`: in the latest record, busy at it
        — always, for what is held (rss, connections). */
    function rank(records: var, key: string, now: real, span: real, count: int): var {
        const window = records.filter(r => r.t >= now - span && r.t <= now);
        const latest = window[window.length - 1];
        if (!latest)
            return [];
        const held = key === "rss" || key === "connections";
        const sums = {};
        const names = {};
        let samples = 0;
        for (const r of held ? [latest] : window) {
            if (!r[key])
                continue;
            samples++;
            for (const pid in r[key]) {
                sums[pid] = (sums[pid] ?? 0) + r[key][pid];
                names[pid] = r.names[pid];
            }
        }
        const out = [];
        for (const pid in sums) {
            const mean = sums[pid] / samples;
            const value = held ? mean : key === "io" ? Math.round(mean) : Math.round(mean * 10) / 10;
            if (value > 0)
                out.push({ pid: Number(pid), name: names[pid] ?? "", value,
                           now: held || (latest[key]?.[pid] ?? 0) > 0 });
        }
        out.sort((a, b) => b.value - a.value || a.pid - b.pid);
        return count < 0 ? out : out.slice(0, count);
    }

    function take(current: var): void {
        const t = current.uptime;
        const kept = root.records.filter(r => r.t >= t - Usage.span);
        if (current.list.length > 0) {
            // What is held is ranked from the latest alone.
            const last = kept.length - 1;
            if (last >= 0)
                kept[last] = Object.assign({}, kept[last], { rss: null, connections: null });
            kept.push(root.record(Processes.list, t));
        } else if (kept.length === root.records.length) {
            return;
        }
        root.records = kept;
        const ranked = {};
        for (const key of root.keys)
            ranked[key] = root.rank(kept, key, t, Usage.span, -1);
        root.ranked = ranked;
        root.revision++;
    }

    Connections {
        target: Processes

        function onSampled(previous: var, current: var): void {
            root.take(current);
        }
    }
}
