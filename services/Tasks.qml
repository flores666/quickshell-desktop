pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    The task manager's scheduled tasks: commands systemd's user manager runs
    on a timer, or at login (TaskUnits has their units). systemd does the
    waiting, so a task runs whether the shell is up or not, and a run missed
    while the machine was off happens at the next start.

    The units are files of the user's (`~/.config/systemd/user`, named
    `<prefix><id>`), so they are this machine's and not the project's. Each
    change is one script, run one after another, and the list is read again
    after each. What happens on its own — a timer firing, a run ending — is
    heard from the user journal of the tasks' units, followed, and the list
    read again then: never asked about on a schedule.

    The user's other timers are listed too, read-only (`others`).
*/
Singleton {
    id: root

    /*! The units' names start with it; the tests use their own. */
    property string prefix: "qs-task-"
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
        + "/systemd/user"

    /*! `{ id, name, command, schedule, enabled, next, last, result, status }`:
        next and last in ms (0 for none), result "success", "failed",
        "running" or "" before it first ran, status its exit status. */
    property var tasks: []
    /*! The user's other timers: `{ unit, activates, next, last }`. */
    property var others: []

    /*! Changes waiting their turn: `{ script, args }`. */
    property var queue: []

    /*! journalctl reports a run as several lines. */
    readonly property int settleTime: 250

    onPrefixChanged: reader.run()
    Component.onCompleted: reader.run()

    /*! The list read again: as the Scheduled tab opens, for the timers that
        are not the shell's, which it hears nothing of. */
    function read(): void {
        reader.run();
    }

    /*! A run's time, as a row says it: the day only when it is not today. */
    function formatWhen(ms: real): string {
        if (ms <= 0)
            return "";
        const when = new Date(ms);
        return when.toDateString() === new Date().toDateString()
            ? Qt.formatDateTime(when, "HH:mm") : Qt.formatDateTime(when, "ddd d MMM, HH:mm");
    }

    function unitOf(task: var): string {
        return task.id + (TaskUnits.parts(task.schedule).kind === "login" ? ".service" : ".timer");
    }

    /*! Writes a task's units (a new one gets an id) and enables it. */
    function save(task: var): void {
        const id = task.id || root.prefix + Date.now().toString(36);
        const files = TaskUnits.files(Object.assign({}, task, { id }));
        const unit = root.unitOf({ id, schedule: task.schedule });
        root.enqueue("mkdir -p \"$1\" && cd \"$1\" || exit 1; "
            + "systemctl --user disable --now \"$2.timer\" \"$2.service\" >/dev/null 2>&1; "
            + "printf '%s' \"$3\" > \"$2.service.new\" && mv -f \"$2.service.new\" \"$2.service\" || exit 1; "
            + "if [ -n \"$4\" ]; then printf '%s' \"$4\" > \"$2.timer.new\" && mv -f \"$2.timer.new\" \"$2.timer\"; "
            + "else rm -f \"$2.timer\"; fi; "
            + "systemctl --user daemon-reload && systemctl --user enable \"$5\" "
            + "&& case $5 in *.timer) systemctl --user restart \"$5\";; esac",
            [root.dir, id, files.service, files.timer, unit]);
    }

    function runNow(id: string): void {
        root.enqueue("systemctl --user start --no-block \"$1.service\"", [id]);
    }

    function setEnabled(id: string, on: bool): void {
        const task = root.tasks.find(t => t.id === id);
        if (task)
            root.enqueue(`systemctl --user ${on ? "enable --now" : "disable --now"} "$1"`, [root.unitOf(task)]);
    }

    function remove(id: string): void {
        root.enqueue("systemctl --user disable --now \"$2.timer\" >/dev/null 2>&1; "
            + "systemctl --user disable \"$2.service\" >/dev/null 2>&1; "
            + "rm -f \"$1/$2.service\" \"$1/$2.timer\"; systemctl --user daemon-reload", [root.dir, id]);
    }

    /*! systemd's reading of an OnCalendar expression, to `then`:
        `{ valid, normalized, next }`, next in ms (0 for never). */
    function validate(expression: string, then: var): void {
        checker.pending = { expression, then };
        checker.run();
    }

    function enqueue(script: string, args: var): void {
        root.queue = root.queue.concat([{ script, args }]);
        if (!worker.running)
            root.work();
    }

    function work(): void {
        if (root.queue.length === 0) {
            reader.run();
            return;
        }
        const job = root.queue[0];
        root.queue = root.queue.slice(1);
        worker.command = ["sh", "-c", job.script, "sh"].concat(job.args);
        worker.running = true;
    }

    /*! `@<seconds>` (systemctl's --timestamp=unix) in ms; 0 for none. */
    function stamp(value: string): real {
        return value?.startsWith("@") ? Number(value.slice(1)) * 1000 : 0;
    }

    /*! The reader's output: each task's `def` lines, `systemctl show`'s
        blocks for its units, and list-timers' JSON for the rest. */
    function readAll(text: string): void {
        const [definitions, shown, timers] = text.split("\n--\n");
        const tasks = {};
        for (const line of (definitions ?? "").split("\n")) {
            const [id, key, ...value] = line.split("\t");
            if (key) {
                tasks[id] = tasks[id] ?? { id, name: "", command: "", schedule: "" };
                tasks[id][key.toLowerCase()] = value.join("\t");
            }
        }
        const units = {};
        for (const block of (shown ?? "").split("\n\n")) {
            const props = {};
            for (const line of block.split("\n")) {
                const eq = line.indexOf("=");
                if (eq > 0)
                    props[line.slice(0, eq)] = line.slice(eq + 1);
            }
            if (props.Id)
                units[props.Id] = props;
        }
        root.tasks = Object.values(tasks).map(t => {
            const service = units[t.id + ".service"] ?? {};
            const timer = units[t.id + ".timer"] ?? {};
            const login = TaskUnits.parts(t.schedule).kind === "login";
            const ended = root.stamp(service.ExecMainExitTimestamp);
            return Object.assign(t, {
                enabled: (login ? service : timer).UnitFileState === "enabled",
                next: login ? 0 : root.stamp(timer.NextElapseUSecRealtime),
                last: ended,
                result: service.ActiveState === "activating" ? "running"
                    : ended === 0 ? "" : service.Result === "success" ? "success" : "failed",
                status: Number(service.ExecMainStatus ?? 0)
            });
        }).sort((a, b) => a.name.localeCompare(b.name));
        let listed = [];
        try {
            listed = JSON.parse(timers ?? "[]");
        } catch (e) {}
        root.others = listed.filter(t => !t.unit.startsWith(root.prefix)).map(t => ({
            unit: t.unit, activates: t.activates, next: (t.next ?? 0) / 1000, last: (t.last ?? 0) / 1000
        }));
    }

    Process {
        id: worker
        onExited: root.work()
    }

    Probe {
        id: reader
        command: ["sh", "-c", "cd \"$1\" 2>/dev/null && for f in \"$2\"*.service; do [ -e \"$f\" ] || continue; "
            + "sed -n \"s/^X-QsTask-\\(Name\\|Command\\|Schedule\\)=/${f%.service}\\t\\1\\t/p\" \"$f\"; "
            + "set -- \"$@\" \"${f%.service}.service\" \"${f%.service}.timer\"; done; "
            + "shift 2; printf '\\n--\\n'; [ $# -gt 0 ] && systemctl --user show --timestamp=unix "
            + "-p Id,UnitFileState,ActiveState,Result,ExecMainStatus,ExecMainExitTimestamp,NextElapseUSecRealtime \"$@\"; "
            + "echo; echo --; systemctl --user list-timers --all -o json",
            "sh", root.dir, root.prefix]
        stdout: StdioCollector { onStreamFinished: root.readAll(this.text) }
    }

    // The user manager's own lines (a unit started, finished, failed), each
    // naming its unit: a glob in --user-unit only matches units the journal
    // has seen already, and a new task's has none.
    Process {
        id: follower
        running: true
        command: ["journalctl", "--user", "-f", "-n", "0", "-o", "json", "--output-fields=USER_UNIT",
                  "_SYSTEMD_USER_UNIT=init.scope"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("\"USER_UNIT\":\"" + root.prefix))
                    settle.restart();
            }
        }
    }

    Timer {
        id: settle
        interval: root.settleTime
        onTriggered: reader.run()
    }

    Probe {
        id: checker

        property var pending: null

        command: ["systemd-analyze", "calendar", "--", checker.pending?.expression ?? ""]
        stdout: StdioCollector {
            onStreamFinished: {
                // Asked again meanwhile, this answer is for an expression
                // gone by: the next run answers the one now pending.
                const original = /Original form: (.*)/.exec(this.text);
                if (original && original[1].trim() !== checker.pending?.expression.trim())
                    return;
                const normalized = /Normalized form: (.*)/.exec(this.text);
                const utc = /\(in UTC\): \w+ (\S+) (\S+) UTC/.exec(this.text);
                checker.pending?.then({
                    valid: normalized !== null,
                    normalized: normalized ? normalized[1].trim() : "",
                    next: utc ? Date.parse(utc[1] + "T" + utc[2] + "Z") : 0
                });
            }
        }
    }
}
