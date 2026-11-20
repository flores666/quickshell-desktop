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
        root.expect("a selected category falls back to its latest open task", root.day, "12:00", tied);
        root.expect("next day's exact start becomes active", root.tomorrow, "08:00", tomorrow);
        root.expect("without a selected category, all expired ranges fall back to latest addition", "2024-06-03", "09:00", tied);
        root.expect("upcoming ties retain newest-first order", root.day, "08:59", short);

        DailyNotes.addCategory(root.day, "Personal");
        DailyNotes.save(root.day, "", "Other category active", "09:30", "09:45", "Personal");
        const other = DailyNotes.document.notes[0].id;
        root.expect("the selected category takes priority over a competing active task", root.day, "09:30", tied);
        DailyNotes.selectCategory(root.day, "Personal");
        root.expect("changing category changes the time-ranked preview", root.day, "09:30", other);
        DailyNotes.toggleDone(other);
        root.expect("a completed category falls back to general priority", root.day, "09:30", tied);
        root.expect("the general fallback considers upcoming tasks on other dates", root.day, "12:00", tomorrow);
        DailyNotes.selectCategory(root.day, "Work");

        DailyNotes.toggleDone(tied);
        root.expect("completed active task is skipped", root.day, "09:30", short);
        root.expect("completed newest task is skipped by fallback", root.day, "12:00", short);
        DailyNotes.toggleDone(expired);
        DailyNotes.toggleDone(short);
        root.expect("completed earliest-ending task yields remaining active", root.day, "09:30", long);
        DailyNotes.toggleDone(long);
        root.expect("no active task yields upcoming", root.day, "09:30", upcoming);
        DailyNotes.toggleDone(upcoming);
        root.expect("the selected category's untimed task is preferred to a later date", root.day, "09:30", untimed);
        root.expect("without a category choice, completed tasks yield the later date", "2024-05-30", "09:30", tomorrow);
        DailyNotes.toggleDone(tomorrow);
        root.expect("no timed candidate yields unfinished untimed", root.day, "09:30", untimed);
        DailyNotes.toggleDone(untimed);
        root.expect("all completed yields no preview", root.day, "09:30", "");
    }
}
