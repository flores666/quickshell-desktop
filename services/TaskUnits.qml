pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    A scheduled task as systemd user units: what Tasks writes and reads back.

    A task is `{ id, name, command, schedule }`. Its schedule is one line, a
    kind and what that kind needs:

        once 2026-10-27 09:00     hourly 15      daily 09:00
        weekly Mon,Wed 09:00      calendar <an OnCalendar expression>
        login

    The service runs the command with /bin/sh once (oneshot) and holds the
    task itself in keys systemd ignores (`X-QsTask-*`), so the task is read
    back as it was written rather than worked out of ExecStart. Every kind
    but `login` has a timer of the same name, persistent, so a run missed
    while the machine was off happens at the next start; a `login` service is
    wanted by quickshell-login.target, which Hyprland restarts as it starts
    (hypr/conf.d/20-autostart.conf).
*/
Singleton {
    id: root

    readonly property var days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property string loginTarget: "quickshell-login.target"

    /*! A schedule's kind and the rest of its line. */
    function parts(schedule: string): var {
        const space = schedule.indexOf(" ");
        return space < 0 ? { kind: schedule, rest: "" }
                         : { kind: schedule.slice(0, space), rest: schedule.slice(space + 1) };
    }

    function validTime(time: string): bool {
        const m = /^(\d\d):(\d\d)$/.exec(time);
        return m !== null && Number(m[1]) < 24 && Number(m[2]) < 60;
    }

    function validDate(date: string): bool {
        const m = /^(\d{4})-(\d\d)-(\d\d)$/.exec(date);
        if (m === null)
            return false;
        const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
        return d.getMonth() === Number(m[2]) - 1 && d.getDate() === Number(m[3]);
    }

    /*! Whether a schedule is one of the kinds, well formed. A custom
        expression is only known good by asking systemd (Tasks.validate). */
    function validSchedule(schedule: string): bool {
        const { kind, rest } = root.parts(schedule);
        const words = rest.split(" ");
        switch (kind) {
        case "once": return words.length === 2 && root.validDate(words[0]) && root.validTime(words[1]);
        case "hourly": return /^\d{1,2}$/.test(rest) && Number(rest) < 60;
        case "daily": return root.validTime(rest);
        case "weekly":
            return words.length === 2 && words[0] !== ""
                && words[0].split(",").every(d => root.days.includes(d)) && root.validTime(words[1]);
        case "calendar": return rest.trim() !== "";
        case "login": return rest === "";
        }
        return false;
    }

    /*! The timer's OnCalendar; "" for `login`, which has no timer. */
    function calendar(schedule: string): string {
        const { kind, rest } = root.parts(schedule);
        const words = rest.split(" ");
        switch (kind) {
        case "once": return words[0] + " " + words[1] + ":00";
        case "hourly": return "*-*-* *:" + rest.padStart(2, "0") + ":00";
        case "daily": return "*-*-* " + rest + ":00";
        case "weekly": return words[0] + " *-*-* " + words[1] + ":00";
        case "calendar": return rest;
        }
        return "";
    }

    /*! A schedule in words, for its row. */
    function describe(schedule: string): string {
        const { kind, rest } = root.parts(schedule);
        const words = rest.split(" ");
        switch (kind) {
        case "once": return qsTr("Once, %1 at %2").arg(words[0]).arg(words[1]);
        case "hourly": return qsTr("Every hour at :%1").arg(rest.padStart(2, "0"));
        case "daily": return qsTr("Every day at %1").arg(rest);
        case "weekly": return qsTr("%1 at %2").arg(words[0].split(",").join(", ")).arg(words[1]);
        case "login": return qsTr("At login");
        }
        return rest;
    }

    /*! A command systemd can hold on one line: something, on one line, not
        ending in a backslash, which would continue it onto the next. */
    function validCommand(command: string): bool {
        return command.trim() !== "" && !command.includes("\n") && !/\\\s*$/.test(command);
    }

    /*! ExecStart= for a command: /bin/sh with it as one quoted word, the
        quotes and backslashes in it escaped, `%` and `$` doubled so that
        systemd leaves them for the shell. */
    function exec(command: string): string {
        const quoted = command.replace(/\\/g, "\\\\").replace(/"/g, "\\\"")
            .replace(/%/g, "%%").replace(/\$/g, "$$$$");
        return "/bin/sh -c \"" + quoted + "\"";
    }

    /*! The units' text: `{ service, timer }`, the timer "" for `login`. */
    function files(task: var): var {
        const login = root.parts(task.schedule).kind === "login";
        const description = "Description=" + task.name.replace(/%/g, "%%");
        const service = ["[Unit]", description,
            "X-QsTask-Name=" + task.name,
            "X-QsTask-Command=" + task.command,
            "X-QsTask-Schedule=" + task.schedule,
            "", "[Service]", "Type=oneshot", "ExecStart=" + root.exec(task.command)]
            .concat(login ? ["", "[Install]", "WantedBy=" + root.loginTarget] : []);
        const timer = login ? [] : ["[Unit]", description,
            "", "[Timer]", "OnCalendar=" + root.calendar(task.schedule), "Persistent=true",
            "", "[Install]", "WantedBy=timers.target"];
        return { service: service.join("\n") + "\n", timer: login ? "" : timer.join("\n") + "\n" };
    }

    /*! The task a service's text holds: `{ name, command, schedule }`. */
    function read(text: string): var {
        const task = { name: "", command: "", schedule: "" };
        for (const line of text.split("\n")) {
            const m = /^X-QsTask-(Name|Command|Schedule)=(.*)$/.exec(line);
            if (m)
                task[m[1].toLowerCase()] = m[2];
        }
        return task;
    }
}
