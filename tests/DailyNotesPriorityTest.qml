pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/services"

/*! Fixed local timestamps exercise the public scheduler without advancing
    the desktop clock or waiting for minute boundaries. */
Item {
    id: root

    Check { id: check }
    Until { id: ready }
    readonly property string day: "2024-06-01"
    readonly property string tomorrow: "2024-06-02"

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated test runner required", false, "run tools/test.sh DailyNotesPriorityTest");
            check.done();
            return;
        }
        ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
            check.equal("priority service becomes ready", ok, true);
            if (ok)
                check.attempt("automatic priority", root.start);
            check.done();
        });
    }

    function at(day: string, time: string): date {
        const date = DailyNotes.dateFor(day);
        const [hours, minutes] = time.split(":").map(Number);
        date.setHours(hours, minutes, 0, 0);
        return date;
    }

    function add(day: string, title: string, start: string, end: string): string {
        check.equal("priority fixture saves: " + title, DailyNotes.save(day, "", title, start, end, "Work"), true);
        return DailyNotes.document.notes[0].id;
    }

    function expect(label: string, day: string, time: string, id: string): void {
        check.equal(label, DailyNotes.previewAt(root.at(day, time))?.id ?? "", id);
    }

    function start(): void {
        for (const day of ["2024-05-31", root.day, root.tomorrow])
            DailyNotes.addCategory(day, "Work");
        const expired = root.add("2024-05-31", "Expired", "08:00", "09:00");
        const tomorrow = root.add(root.tomorrow, "Tomorrow", "08:00", "09:00");
        const upcoming = root.add(root.day, "Upcoming", "10:00", "11:00");
        const untimed = root.add(root.day, "Untimed", "", "");
        root.expect("nearest upcoming beats newer untimed and later date", root.day, "09:30", upcoming);
        const long = root.add(root.day, "Long active", "09:00", "12:00");
        root.expect("active task beats nearest upcoming", root.day, "09:30", long);
        const short = root.add(root.day, "Short active", "09:00", "10:00");
        root.expect("active priority uses earliest end", root.day, "09:30", short);
        const tied = root.add(root.day, "Newest tied active", "09:30", "10:00");
        root.expect("tied active ranges retain newest-first order", root.day, "09:30", tied);
        root.expect("range start is inclusive", root.day, "09:00", short);
        root.expect("future task cannot become active before its start", root.day, "09:29", short);
        root.expect("range end is exclusive and next start is inclusive", root.day, "10:00", upcoming);
        root.expect("all expired today falls forward across dates", root.day, "12:00", tomorrow);
        root.expect("next day's exact start becomes active", root.tomorrow, "08:00", tomorrow);
        root.expect("all expired ranges fall back to latest addition", root.tomorrow, "09:00", tied);
        root.expect("upcoming ties retain newest-first order", "2024-05-31", "23:59", short);

        DailyNotes.toggleDone(tied);
        root.expect("completed active task is skipped", root.day, "09:30", short);
        root.expect("completed newest task is skipped by fallback", root.tomorrow, "09:00", short);
        DailyNotes.toggleTracking(expired);
        root.expect("manual tracking overrides active priority", root.day, "09:30", expired);
        root.expect("manual tracking overrides upcoming priority", root.day, "12:00", expired);
        DailyNotes.toggleDone(expired);
        check.equal("completion clears manual override", DailyNotes.trackedId, "");
        root.expect("completion resumes timed priority", root.day, "09:30", short);
        DailyNotes.toggleDone(short);
        root.expect("completed earliest-ending task yields remaining active", root.day, "09:30", long);
        DailyNotes.toggleDone(long);
        root.expect("no active task yields upcoming", root.day, "09:30", upcoming);
        DailyNotes.toggleDone(upcoming);
        root.expect("completed nearest upcoming yields later date", root.day, "09:30", tomorrow);
        DailyNotes.toggleDone(tomorrow);
        root.expect("no timed candidate yields unfinished untimed", root.day, "09:30", untimed);
        DailyNotes.toggleDone(untimed);
        root.expect("all completed yields no preview", root.day, "09:30", "");
    }
}
