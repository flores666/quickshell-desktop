import QtQuick
import Quickshell
import "root:/services"

/*!
    earlyoom from the shell's side (EarlyOom): memory as earlyoom reckons it,
    the process it would stop next, its kills read from its journal — the
    ones that happen while the shell watches posted as notifications, the
    ones from before not — the file the RAM tab writes, and whether it is
    there at all. Only against tools/test.sh's notify-send, which notes what
    it is asked in a file of the run's own: anywhere else the test posts
    nothing and fails.
*/
Item {
    id: root

    Check {
        id: check
    }

    Command {
        id: sh
    }

    FileWait {
        id: notes
    }

    function same(name: string, actual: var, expected: var): void {
        check.equal(name, JSON.stringify(actual), JSON.stringify(expected));
    }

    /*! A journal entry as `journalctl -o json` gives it. */
    function entry(ms: real, message: string): string {
        return JSON.stringify({ __REALTIME_TIMESTAMP: String(ms * 1000), MESSAGE: message });
    }

    function process(pid: int, oomScore: int, rss: int, more: var): var {
        return Object.assign({ pid, uid: 1000, ppid: 1, ticks: 0, rss, oomScore, oomAdj: 0, name: "p" + pid }, more);
    }

    readonly property var lists: ({
        memTerm: 10, memKill: 5, swapTerm: 10, swapKill: 5,
        avoid: ["guarded"], prefer: ["doomed"], rest: []
    })

    Component.onCompleted: {
        check.attempt("memory", () => {
            const noSwap = EarlyOom.memory({ total: 16e6, available: 3e6, anon: 3e6, swapTotal: 0, swapFree: 0 });
            check.near("memory: available over available and anonymous", noSwap.memPercent, 50);
            check.near("memory: no swap reads as none free", noSwap.swapPercent, 0);
            const swap = EarlyOom.memory({ total: 16e6, available: 1e6, anon: 3e6, swapTotal: 4e6, swapFree: 1e6 });
            check.near("memory: a quarter available", swap.memPercent, 25);
            check.near("memory: a quarter of swap free", swap.swapPercent, 25);
        });

        check.attempt("victim", () => {
            const list = [
                root.process(1, 900, 10),
                root.process(40, 990, 0, { ppid: 2, name: "kworker" }),
                root.process(41, 980, 50, { oomAdj: -1000 }),
                root.process(42, 970, 50, { name: "earlyoom" }),
                root.process(50, 600, 100),
                root.process(51, 600, 300),
                root.process(52, 500, 10)
            ];
            check.equal("victim: the highest score, ties by memory", EarlyOom.victim(list, EarlyOomArgs.parse("")), 51);
            list.push(root.process(53, 400, 10, { name: "doomed" }));
            check.equal("victim: a preferred one gains 300", EarlyOom.victim(list, root.lists), 53);
            list.push(root.process(54, 650, 10, { name: "guarded" }));
            check.equal("victim: an avoided one loses 300", EarlyOom.victim(list, root.lists), 53);
            check.equal("victim: none among the spared", EarlyOom.victim(list.slice(0, 4), root.lists), -1);
        });

        check.attempt("preferences", () => {
            const avoid = EarlyOom.withPreference(root.lists, "doomed", "avoid");
            root.same("protected: out of prefer, into avoid", [avoid.avoid, avoid.prefer], [["guarded", "doomed"], []]);
            const prefer = EarlyOom.withPreference(root.lists, "guarded", "prefer");
            root.same("kill first: out of avoid, into prefer", [prefer.avoid, prefer.prefer], [[], ["doomed", "guarded"]]);
            const none = EarlyOom.withPreference(root.lists, "guarded", "");
            root.same("no preference: out of both", [none.avoid, none.prefer], [[], ["doomed"]]);
            check.equal("preference: avoided", EarlyOom.preferenceIn(root.lists, "guarded"), "avoid");
            check.equal("preference: preferred", EarlyOom.preferenceIn(root.lists, "doomed"), "prefer");
            check.equal("preference: neither", EarlyOom.preferenceIn(root.lists, "other"), "");
        });

        check.attempt("the file", () => {
            const text = EarlyOom.fileText(root.lists);
            check.report("the file: marked as the project's", text.split("\n").includes("# quickshell-desktop"), text);
            check.report("the file: the arguments",
                text.split("\n").includes(`EARLYOOM_ARGS="${EarlyOomArgs.format(root.lists)}"`), text);
        });

        check.attempt("kills", () => {
            const start = Date.now();
            EarlyOom.kills = [];
            EarlyOom.readEntry(root.entry(start - 60000, "sending SIGTERM to process 4242 uid 1000 \"stress ng\": "
                + "oom_score 812, oom_score_adj 0, VmRSS 3021 MiB, cmdline \"stress-ng --vm 1\""), start);
            root.same("kills: read", EarlyOom.kills, [{
                time: start - 60000, pid: 4242, uid: 1000, name: "stress ng", signal: "SIGTERM", rss: 3021
            }]);
            EarlyOom.readEntry(root.entry(start - 59000, "escalating to SIGKILL after 0.500 seconds"), start);
            check.equal("kills: escalated", EarlyOom.kills[0]?.signal, "SIGKILL");
            EarlyOom.readEntry(root.entry(start - 58000, "mem avail: 1201 of 15822 MiB ( 7.59%)"), start);
            check.equal("kills: other lines ignored", EarlyOom.kills.length, 1);
            EarlyOom.readEntry(root.entry(start + 1, "sending SIGTERM to process 77 uid 1000 \"hog\": "
                + "oom_score 700, oom_score_adj 0, VmRSS 900 MiB, cmdline \"hog\""), start);
            check.equal("kills: newest first", EarlyOom.kills[0]?.pid, 77);
            for (let i = 0; i < 60; ++i)
                EarlyOom.readEntry(root.entry(start - 50000 + i, `sending SIGKILL to process ${i + 100} uid 0 "x": `
                    + "oom_score 1, oom_score_adj 0, VmRSS 1 MiB, cmdline \"x\""), start + 1e9);
            check.equal("kills: fifty at most", EarlyOom.kills.length, 50);
        });

        sh.run("command -v notify-send; test -e /usr/lib/systemd/system/earlyoom.service && echo installed", [], out => {
            const lines = out.trim().split("\n");
            check.equal("installed: as its unit file says", EarlyOom.available, lines.includes("installed"));
            if (!lines[0].startsWith(Quickshell.shellPath("tests/bin"))) {
                check.report("the tests' own notify-send", false, "got " + lines[0]);
                check.done();
                return;
            }
            // The kill at start + 1 above was live, those before it not.
            notes.until(Quickshell.env("TEST_NOTIFY"), text => text.includes("hog"), text => {
                const posted = text.trim().split("\n").filter(l => l !== "");
                check.equal("notified: the live kill alone", posted.length, 1);
                check.report("notified: as earlyoom, critical",
                    posted[0]?.includes("-a earlyoom") && posted[0]?.includes("-u critical"), posted[0]);
                check.done();
            });
        });
    }
}
