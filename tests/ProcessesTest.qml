import QtQuick
import Quickshell.Io
import "root:/services"

/*!
    The process list (Processes): a sample of /proc and /sys read whole — the
    processes, and the machine's CPU, disks, root filesystem, network and GPU
    — CPU and disk I/O worked out between two samples; the machine's
    counters sampled always and each process only while something watches,
    each watcher by its own key; and ending a process — the test's own,
    never anyone else's. Starts unwatched.
*/
Item {
    id: root

    Check {
        id: check
    }

    Until {
        id: until
    }

    function same(name: string, actual: var, expected: var): void {
        check.equal(name, JSON.stringify(actual), JSON.stringify(expected));
    }

    /*! What the sampler prints, a field a tab. */
    readonly property string sample: [
        "uptime\t1234.56", "cpus\t12", "uid\t1000",
        // user nice system idle iowait irq softirq steal
        "cpu\t100\t10\t50\t800\t20\t5\t5\t10",
        "freq\t2400",
        "mem\t16000000\t4000000\t3000000\t4194300\t4194300",
        // 1 KiB blocks: size, used
        "fs\t101594104\t36960592",
        // name, size and sectors read and written (512 bytes), io ticks, model
        "disk\tnvme0n1\t1000215216\t11425781\t23221634\t193604\tSAMSUNG MZALQ512HBLU-00BL2",
        "disk\tsda\t2048\t10\t20\t30\t",
        "net\twlan0\t4313984731\t1088356446",
        // slot, busy, VRAM used and total, temperature in milli-degrees
        "gpu\t0000:04:00.0\t10\t1563443200\t2147483648\t56000",
        "user\t0\troot", "user\t1000\tme",
        "p\t1\t0\t0\t512\t12000\t0\t0\t-1\t-1\tsystemd",
        "p\t4242\t1000\t1\t7000\t250000\t667\t200\t4096\t8192\tWeb (Content) x",
        "p\t4243\t1000\t1\t5\t0\t0\t0\t0\t0"
    ].join("\n") + "\n"

    /*! What each `sampled` said: whether it had a sample before it. */
    property var heard: []

    Connections {
        target: Processes

        function onSampled(previous: var, current: var): void {
            root.heard = root.heard.concat([{ previous: previous !== null, uptime: current?.uptime ?? -1,
                                              before: previous?.uptime ?? -1 }]);
        }
    }

    // Each is the test's own, ended by the service.
    Process {
        id: termed
        command: ["sleep", "60"]
    }

    Process {
        id: killed
        command: ["sleep", "61"]
    }

    Component.onCompleted: {
        check.attempt("parse", () => {
            const s = Processes.parse(root.sample);
            root.same("parse: the header", [s.uptime, s.cpus, s.uid], [1234.56, 12, 1000]);
            root.same("parse: memory", s.memory,
                { total: 16000000, available: 4000000, anon: 3000000, swapTotal: 4194300, swapFree: 4194300 });
            check.equal("parse: users", s.users[1000], "me");
            check.equal("parse: every process with a name", s.list.length, 2);
            root.same("parse: a process", s.list[1], {
                pid: 4242, uid: 1000, ppid: 1, ticks: 7000, rss: 250000, oomScore: 667, oomAdj: 200,
                readBytes: 4096, writeBytes: 8192, name: "Web (Content) x"
            });
            root.same("parse: io unreadable", [s.list[0].readBytes, s.list[0].writeBytes], [-1, -1]);
        });

        check.attempt("parse: the machine", () => {
            const s = Processes.parse(root.sample);
            root.same("parse: CPU ticks, busy without idle and iowait", s.cpuTicks, { busy: 180, total: 1000 });
            check.equal("parse: CPU frequency", s.cpuFreq, 2400);
            root.same("parse: the root filesystem, in bytes", s.fs, { total: 101594104 * 1024, used: 36960592 * 1024 });
            root.same("parse: disks, in bytes", s.disks, [
                { name: "nvme0n1", model: "SAMSUNG MZALQ512HBLU-00BL2", size: 1000215216 * 512,
                  read: 11425781 * 512, written: 23221634 * 512, ioTicks: 193604 },
                { name: "sda", model: "", size: 2048 * 512, read: 10 * 512, written: 20 * 512, ioTicks: 30 }
            ]);
            root.same("parse: network", s.nets, [{ name: "wlan0", rx: 4313984731, tx: 1088356446 }]);
            root.same("parse: the GPU, in degrees", s.gpu,
                { slot: "0000:04:00.0", busy: 10, vramUsed: 1563443200, vramTotal: 2147483648, temp: 56 });
            const cold = Processes.parse("gpu\t0000:01:00.0\t0\t0\t0\t-1\n");
            check.equal("parse: a GPU with no temperature", cold.gpu?.temp, -1);
        });

        check.attempt("parse: a machine without", () => {
            const s = Processes.parse("uptime\t10\ncpus\t1\n");
            root.same("parse: what is not there is absent",
                [s.cpuFreq, s.fs, s.disks, s.nets, s.gpu], [0, null, [], [], null]);
        });

        check.attempt("cpu", () => {
            const before = { uptime: 100, list: [{ pid: 1, ticks: 1000 }, { pid: 2, ticks: 50 }] };
            const after = { uptime: 102, list: [{ pid: 1, ticks: 1240 }, { pid: 3, ticks: 5 }] };
            const cpu = Processes.cpu(before, after, 12);
            check.near("cpu: a share of the whole machine", cpu[1], 10);
            check.equal("cpu: none for a newcomer", cpu[3], -1);
        });

        check.attempt("io", () => {
            const before = { uptime: 100, list: [
                { pid: 1, readBytes: 1000, writeBytes: 0 }, { pid: 2, readBytes: -1, writeBytes: -1 },
                { pid: 4, readBytes: 0, writeBytes: 0 }
            ] };
            const after = { uptime: 102, list: [
                { pid: 1, readBytes: 5000, writeBytes: 2000 }, { pid: 2, readBytes: -1, writeBytes: -1 },
                { pid: 3, readBytes: 10, writeBytes: 0 }, { pid: 4, readBytes: -1, writeBytes: -1 }
            ] };
            const io = Processes.io(before, after);
            check.near("io: read and written per second", io[1], 3000);
            check.equal("io: none for one unreadable", io[2], -1);
            check.equal("io: none for a newcomer", io[3], -1);
            check.equal("io: none for one unreadable since", io[4], -1);
        });

        until.bound = Processes.sampleInterval + 500;
        until.until(Processes.samplesChanged, () => Processes.samples > 0, sampled => {
            check.equal("unwatched: the machine's counters sampled", sampled, true);
            check.report("unwatched: CPU ticks read", (Processes.last?.cpuTicks?.total ?? 0) > 0,
                JSON.stringify(Processes.last?.cpuTicks));
            check.equal("unwatched: no process read", Processes.last?.list.length, 0);
            check.equal("unwatched: none listed", Processes.list.length, 0);
            root.watch();
        });
    }

    function watch(): void {
        termed.running = true;
        killed.running = true;
        until.bound = 1000;
        check.attempt("watch", () => Processes.watch("test", true));
        check.equal("watched: by the test's key", Processes.watched, true);
        until.until(Processes.listChanged, () => Processes.list.length > 0, sampled => {
            check.equal("watched: the processes listed at once", sampled, true);
            until.bound = 2000;
            // The second sample, the first with I/O, `firstInterval` after.
            until.until(Processes.listChanged, () => (Processes.byPid[termed.processId]?.io ?? -1) >= 0,
                        io => root.read(io));
        });
    }

    function read(io: bool): void {
        const mine = Processes.byPid[termed.processId];
        check.equal("live: the test's process", mine?.name, "sleep");
        check.equal("live: its uid is the shell's", mine?.uid, Processes.uid);
        check.equal("live: own", mine?.own, true);
        check.equal("live: init is not", Processes.byPid[1]?.own, false);
        check.report("live: memory read", Processes.memory.total > 0, JSON.stringify(Processes.memory));
        check.equal("live: its own I/O read", io, true);
        check.equal("live: init's I/O unreadable", Processes.byPid[1]?.io, -1);
        const last = Processes.last;
        check.report("live: CPU ticks", (last?.cpuTicks?.total ?? 0) > 0, JSON.stringify(last?.cpuTicks));
        check.report("live: the root filesystem", (last?.fs?.total ?? 0) > 0, JSON.stringify(last?.fs));
        check.report("live: whole disks alone", Array.isArray(last?.disks)
            && last.disks.every(d => !/^(loop|zram|ram|sr|dm-|md)/.test(d.name)), JSON.stringify(last?.disks));
        check.report("live: physical interfaces alone", Array.isArray(last?.nets)
            && last.nets.every(n => n.name !== "lo"), JSON.stringify(last?.nets));

        check.equal("end: not another user's", Processes.terminate(1), false);
        const samples = Processes.samples;
        check.equal("end: the test's own", Processes.terminate(termed.processId), true);
        until.until(termed.runningChanged, () => !termed.running, ended => {
            check.equal("end: it ended", ended, true);
            until.until(Processes.samplesChanged, () => Processes.samples > samples, again => {
                check.equal("end: sampled again at once", again, true);
                // Heard by now: each goes out once its sample is in, after `list`.
                root.same("sampled: the shell's first had none before it, the next one",
                    root.heard.slice(0, 2).map(h => h.previous), [false, true]);
                check.equal("sampled: each after the one before",
                    root.heard.length > 1 && root.heard[1].before === root.heard[0].uptime, true);
                check.equal("force kill: not another user's", Processes.forceKill(1), false);
                check.equal("force kill: the test's own", Processes.forceKill(killed.processId), true);
                until.until(killed.runningChanged, () => !killed.running, gone => {
                    check.equal("force kill: it ended", gone, true);
                    root.watchers();
                });
            });
        });
    }

    /*! Two readers at once: watched while either is on. */
    function watchers(): void {
        check.attempt("watchers", () => {
            Processes.watch("other", true);
            Processes.watch("test", false);
            check.equal("watchers: watched while the other is on", Processes.watched, true);
            Processes.watch("other", true);
            Processes.watch("other", false);
            check.equal("watchers: a key is on or off, not counted", Processes.watched, false);
        });
        // Unwatched again, the samples read the counters alone — once the one
        // the watch began, if any, is in — and leave the list as it was.
        until.bound = Processes.sampleInterval * 3;
        until.until(Processes.samplesChanged, () => Processes.last.list.length === 0, alone => {
            check.equal("unwatched again: the counters alone", alone, true);
            const list = Processes.list;
            const samples = Processes.samples;
            until.until(Processes.samplesChanged, () => Processes.samples > samples, sampled => {
                check.equal("unwatched again: still sampled", sampled, true);
                check.equal("unwatched again: the list left as it was", Processes.list === list, true);
                check.done();
            });
        });
    }
}
