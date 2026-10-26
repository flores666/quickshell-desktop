import QtQuick
import Quickshell
import "root:/services"

/*!
    Scheduled tasks against the real user manager (Tasks): saved as units,
    listed with their next run, run at once with their result noticed from
    the journal, switched off and on, and deleted. Under a prefix of the
    test's own, everything it made removed again — what an earlier run left
    first — so nothing of it outlasts the test or shows among the user's
    tasks. Its commands write into the run's state directory.
*/
Item {
    id: root

    Check {
        id: check
    }

    Command {
        id: sh
    }

    Until {
        id: until
        bound: 8000
    }

    FileWait {
        id: file
        bound: 8000
    }

    readonly property string prefix: "qs-tasktest-"
    readonly property string units: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/systemd/user"
    readonly property string out: Quickshell.env("XDG_STATE_HOME") + "/tasks-test"

    /*! Every unit the test's prefix names, stopped, disabled and deleted. */
    readonly property string sweep: "cd \"$1\" 2>/dev/null || exit 0; "
        + "for unit in \"$2\"*.service \"$2\"*.timer; do [ -e \"$unit\" ] || continue; "
        + "systemctl --user disable --now \"$unit\" >/dev/null 2>&1; rm -f \"$unit\"; done; "
        + "systemctl --user daemon-reload"

    function task(name: string): var {
        return Tasks.tasks.find(t => t.name === name);
    }

    Component.onCompleted: {
        Tasks.prefix = root.prefix;
        sh.run(root.sweep + "; mkdir -p \"$3\"", [root.units, root.prefix, root.out], () => {
            Tasks.read();
            until.until(Tasks.tasksChanged, () => Tasks.tasks.length === 0, () => root.calendars());
        });
    }

    function calendars(): void {
        Tasks.validate("Mon,Wed *-*-* 09:00", good => {
            check.equal("validate: a good one", good.valid, true);
            check.equal("validate: normalized", good.normalized, "Mon,Wed *-*-* 09:00:00");
            check.report("validate: next run ahead", good.next > Date.now(), String(good.next));
            Tasks.validate("garbage", bad => {
                check.equal("validate: a bad one", bad.valid, false);
                root.once();
            });
        });
    }

    function once(): void {
        Tasks.save({ name: "test once", command: `echo ran > '${root.out}/ran'`, schedule: "once 2099-01-01 09:00" });
        until.until(Tasks.tasksChanged, () => root.task("test once")?.next > 0, listed => {
            const t = root.task("test once");
            check.equal("save: listed", listed, true);
            check.equal("save: under the prefix", t?.id.startsWith(root.prefix), true);
            check.equal("save: its next run", t?.next, new Date(2099, 0, 1, 9, 0).getTime());
            check.equal("save: enabled", t?.enabled, true);
            check.equal("others: not among them", Tasks.others.some(o => o.unit.startsWith(root.prefix)), false);
            Tasks.runNow(t.id);
            file.until(`${root.out}/ran`, text => text.trim() === "ran", text => {
                check.equal("run now: it ran", text.trim(), "ran");
                until.until(Tasks.tasksChanged, () => root.task("test once")?.result === "success", done => {
                    check.equal("run now: succeeded", done, true);
                    check.report("run now: when", root.task("test once")?.last > 0, JSON.stringify(root.task("test once")));
                    root.failing();
                });
            });
        });
    }

    function failing(): void {
        Tasks.save({ name: "test fails", command: "exit 3", schedule: "daily 09:00" });
        until.until(Tasks.tasksChanged, () => root.task("test fails") !== undefined, () => {
            const id = root.task("test fails").id;
            Tasks.runNow(id);
            until.until(Tasks.tasksChanged, () => root.task("test fails")?.result === "failed", failed => {
                check.equal("run now: failed", failed, true);
                check.equal("run now: its exit status", root.task("test fails")?.status, 3);
                Tasks.setEnabled(id, false);
                until.until(Tasks.tasksChanged, () => root.task("test fails")?.enabled === false, off => {
                    check.equal("disabled", off, true);
                    check.equal("disabled: no next run", root.task("test fails")?.next, 0);
                    Tasks.setEnabled(id, true);
                    until.until(Tasks.tasksChanged, () => root.task("test fails")?.next > 0, on => {
                        check.equal("enabled again: a next run", on, true);
                        root.login();
                    });
                });
            });
        });
    }

    function login(): void {
        Tasks.save({ name: "test login", command: "true", schedule: "login" });
        until.until(Tasks.tasksChanged, () => root.task("test login")?.enabled === true, listed => {
            check.equal("at login: listed, enabled", listed, true);
            check.equal("at login: no next run", root.task("test login")?.next, 0);
            root.remove();
        });
    }

    function remove(): void {
        for (const t of Tasks.tasks)
            Tasks.remove(t.id);
        until.until(Tasks.tasksChanged, () => Tasks.tasks.length === 0, gone => {
            check.equal("remove: none listed", gone, true);
            sh.run("ls \"$1\" | grep -c \"^$2\"", [root.units, root.prefix], count => {
                check.equal("remove: no unit left", count.trim(), "0");
                sh.run(root.sweep, [root.units, root.prefix], () => check.done());
            });
        });
    }
}
