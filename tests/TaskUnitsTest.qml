import QtQuick
import "root:/services"

/*!
    A scheduled task as systemd units (TaskUnits): its schedule as a timer's
    OnCalendar, its command quoted for ExecStart, the units' text, and the
    task read back from it.
*/
Item {
    id: root

    Check {
        id: check
    }

    function lines(text: string): var {
        return text.split("\n");
    }

    Component.onCompleted: {
        check.attempt("calendar", () => {
            check.equal("calendar: once", TaskUnits.calendar("once 2026-10-27 09:00"), "2026-10-27 09:00:00");
            check.equal("calendar: hourly", TaskUnits.calendar("hourly 15"), "*-*-* *:15:00");
            check.equal("calendar: daily", TaskUnits.calendar("daily 09:00"), "*-*-* 09:00:00");
            check.equal("calendar: weekly", TaskUnits.calendar("weekly Mon,Wed 09:00"), "Mon,Wed *-*-* 09:00:00");
            check.equal("calendar: custom", TaskUnits.calendar("calendar Sat *-*-1..7 18:00"), "Sat *-*-1..7 18:00");
            check.equal("calendar: at login, none", TaskUnits.calendar("login"), "");
        });

        check.attempt("schedules", () => {
            check.equal("schedule: once", TaskUnits.validSchedule("once 2026-10-27 09:00"), true);
            check.equal("schedule: no 31 November", TaskUnits.validSchedule("once 2026-11-31 09:00"), false);
            check.equal("schedule: no hour 24", TaskUnits.validSchedule("daily 24:00"), false);
            check.equal("schedule: no minute 60", TaskUnits.validSchedule("hourly 60"), false);
            check.equal("schedule: weekly, no day", TaskUnits.validSchedule("weekly  09:00"), false);
            check.equal("schedule: weekly, a made-up day", TaskUnits.validSchedule("weekly Mon,Fun 09:00"), false);
            check.equal("schedule: custom, something", TaskUnits.validSchedule("calendar daily"), true);
            check.equal("schedule: at login", TaskUnits.validSchedule("login"), true);
            check.equal("schedule: nonsense", TaskUnits.validSchedule("sometimes"), false);
        });

        check.attempt("exec", () => {
            check.equal("exec: plain", TaskUnits.exec("echo hi"), "/bin/sh -c \"echo hi\"");
            check.equal("exec: quoted", TaskUnits.exec("echo \"$HOME\" 100% \\n"),
                "/bin/sh -c \"echo \\\"$$HOME\\\" 100%% \\\\n\"");
            check.equal("command: something", TaskUnits.validCommand("true"), true);
            check.equal("command: nothing", TaskUnits.validCommand("  "), false);
            check.equal("command: two lines", TaskUnits.validCommand("a\nb"), false);
            check.equal("command: a continuation", TaskUnits.validCommand("a \\"), false);
        });

        check.attempt("units", () => {
            const task = { id: "qs-task-x1", name: "Back up", command: "rsync -a ~/a /b # 50%", schedule: "weekly Mon,Fri 21:30" };
            const files = TaskUnits.files(task);
            const service = root.lines(files.service);
            check.report("units: a oneshot", service.includes("Type=oneshot"), files.service);
            check.report("units: the command", service.includes("ExecStart=" + TaskUnits.exec(task.command)), files.service);
            check.report("units: the name", service.includes("Description=Back up"), files.service);
            const timer = root.lines(files.timer);
            check.report("units: when", timer.includes("OnCalendar=Mon,Fri *-*-* 21:30:00"), files.timer);
            check.report("units: missed runs caught up", timer.includes("Persistent=true"), files.timer);
            check.report("units: a timer's install", timer.includes("WantedBy=timers.target"), files.timer);
            const back = TaskUnits.read(files.service);
            check.equal("read back: name", back.name, task.name);
            check.equal("read back: command", back.command, task.command);
            check.equal("read back: schedule", back.schedule, task.schedule);

            const login = TaskUnits.files({ id: "qs-task-x2", name: "Hello", command: "true", schedule: "login" });
            check.equal("at login: no timer", login.timer, "");
            check.report("at login: wanted by the login target",
                root.lines(login.service).includes("WantedBy=quickshell-login.target"), login.service);
            check.equal("at login: read back", TaskUnits.read(login.service).schedule, "login");
        });

        check.attempt("in words", () => {
            check.equal("words: daily", TaskUnits.describe("daily 09:00"), "Every day at 09:00");
            check.equal("words: hourly", TaskUnits.describe("hourly 5"), "Every hour at :05");
            check.equal("words: weekly", TaskUnits.describe("weekly Mon,Wed 09:00"), "Mon, Wed at 09:00");
            check.equal("words: at login", TaskUnits.describe("login"), "At login");
            check.equal("words: custom", TaskUnits.describe("calendar Sat *-*-1..7 18:00"), "Sat *-*-1..7 18:00");
        });

        check.done();
    }
}
