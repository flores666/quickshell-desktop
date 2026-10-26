import QtQuick
import Quickshell.Io
import "root:/services"

/*!
    The process list (Processes): a sample of /proc read whole, CPU worked
    out between two samples, sampling only while watched, and ending a
    process — the test's own, never anyone else's. Starts unwatched.
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
        "mem\t16000000\t4000000\t3000000\t4194300\t4194300",
        "user\t0\troot", "user\t1000\tme",
        "p\t1\t0\t0\t512\t12000\t0\t0\tsystemd",
        "p\t4242\t1000\t1\t7000\t250000\t667\t200\tWeb (Content) x",
        "p\t4243\t1000\t1\t5\t0\t0\t0"
    ].join("\n") + "\n"

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
                pid: 4242, uid: 1000, ppid: 1, ticks: 7000, rss: 250000, oomScore: 667, oomAdj: 200, name: "Web (Content) x"
            });
        });

        check.attempt("cpu", () => {
            const before = { uptime: 100, list: [{ pid: 1, ticks: 1000 }, { pid: 2, ticks: 50 }] };
            const after = { uptime: 102, list: [{ pid: 1, ticks: 1240 }, { pid: 3, ticks: 5 }] };
            const cpu = Processes.cpu(before, after, 12);
            check.near("cpu: a share of the whole machine", cpu[1], 10);
            check.equal("cpu: none for a newcomer", cpu[3], -1);
        });

        check.equal("unwatched: nothing sampled", Processes.samples, 0);
        // Past the interval, so a sample it should not take would be in.
        until.bound = Processes.sampleInterval + 500;
        until.until(Processes.samplesChanged, () => Processes.samples > 0, sampled => {
            check.equal("unwatched: still nothing sampled", sampled, false);
            root.watch();
        });
    }

    function watch(): void {
        termed.running = true;
        killed.running = true;
        until.bound = 1000;
        Processes.watched = true;
        until.until(Processes.samplesChanged, () => Processes.samples > 0, sampled => {
            check.equal("watched: a sample at once", sampled, true);
            until.until(Processes.listChanged, () => Processes.byPid[termed.processId] !== undefined, () => root.read());
        });
    }

    function read(): void {
        const mine = Processes.byPid[termed.processId];
        check.equal("live: the test's process", mine?.name, "sleep");
        check.equal("live: its uid is the shell's", mine?.uid, Processes.uid);
        check.equal("live: own", mine?.own, true);
        check.equal("live: init is not", Processes.byPid[1]?.own, false);
        check.report("live: memory read", Processes.memory.total > 0, JSON.stringify(Processes.memory));

        check.equal("end: not another user's", Processes.terminate(1), false);
        const samples = Processes.samples;
        check.equal("end: the test's own", Processes.terminate(termed.processId), true);
        until.until(termed.runningChanged, () => !termed.running, ended => {
            check.equal("end: it ended", ended, true);
            until.until(Processes.samplesChanged, () => Processes.samples > samples, again => {
                check.equal("end: sampled again at once", again, true);
                check.equal("force kill: not another user's", Processes.forceKill(1), false);
                check.equal("force kill: the test's own", Processes.forceKill(killed.processId), true);
                until.until(killed.runningChanged, () => !killed.running, gone => {
                    check.equal("force kill: it ended", gone, true);
                    Processes.watched = false;
                    check.done();
                });
            });
        });
    }
}
