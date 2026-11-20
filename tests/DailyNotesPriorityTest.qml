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

    function add(day: string, title: string, deadline: string): string {
        check.equal("priority fixture saves: " + title, DailyNotes.save(day, "", title, deadline, "Work"), true);
        return DailyNotes.document.notes[0].id;
    }

    function expect(label: string, day: string, time: string, id: string): void {
        check.equal(label, DailyNotes.previewAt(root.at(day, time))?.id ?? "", id);
    }

    function start(): void {
        for (const day of ["2024-05-31", root.day, root.tomorrow])
            DailyNotes.addCategory(day, "Work");
        const expired = root.add("2024-05-31", "Expired", "2024-05-31T09:00");
        const tomorrow = root.add(root.tomorrow, "Tomorrow", "2024-06-02T08:00");
        const upcoming = root.add(root.day, "Upcoming", "2024-06-01T11:00");
        const untimed = root.add(root.day, "Untimed", "");
        root.expect("nearest deadline beats newer unset deadline and later date", root.day, "09:30", upcoming);
        const earlier = root.add(root.day, "Earlier deadline", "2024-06-01T10:00");
        root.expect("earlier deadline becomes priority", root.day, "09:30", earlier);
        const tied = root.add(root.day, "Newest tied deadline", "2024-06-01T10:00");
        root.expect("deadline ties retain newest-first order", root.day, "09:30", tied);
        root.expect("exact deadline minute is inclusive", root.day, "10:00", tied);
        const lastSecond = root.at(root.day, "10:00");
        lastSecond.setSeconds(59, 999);
        check.equal("deadline stays current through its full minute", DailyNotes.previewAt(lastSecond)?.id, tied);
        root.expect("deadline expires on the next minute", root.day, "10:01", upcoming);
        root.expect("selected category falls back to newest when all its deadlines passed", root.day, "12:00", tied);
        root.expect("next day's exact deadline is inclusive", root.tomorrow, "08:00", tomorrow);
        root.expect("all expired deadlines fall back to newest addition", "2024-06-03", "09:00", tied);

        DailyNotes.addCategory(root.day, "Personal");
        DailyNotes.save(root.day, "", "Other category deadline", "2024-06-01T09:45", "Personal");
        const other = DailyNotes.document.notes[0].id;
        root.expect("selected category beats an earlier competing deadline", root.day, "09:30", tied);
        DailyNotes.selectCategory(root.day, "Personal");
        root.expect("changing category changes the deadline priority", root.day, "09:30", other);
        DailyNotes.toggleDone(other);
        root.expect("completed category falls back to general priority", root.day, "09:30", tied);
        root.expect("general fallback considers deadlines on other dates", root.day, "12:00", tomorrow);
        const crossDay = root.add("2024-05-31", "Older board, future deadline", "2024-06-01T09:40");
        root.expect("board membership does not determine the deadline", root.day, "09:30", crossDay);
        DailyNotes.toggleDone(crossDay);
        DailyNotes.selectCategory(root.day, "Work");

        DailyNotes.toggleDone(tied);
        root.expect("completed deadline task is skipped", root.day, "09:30", earlier);
        root.expect("completed newest task is skipped by fallback", root.day, "12:00", earlier);
        DailyNotes.toggleDone(expired);
        DailyNotes.toggleDone(earlier);
        root.expect("completed nearest deadline yields next candidate", root.day, "09:30", upcoming);
        DailyNotes.toggleDone(upcoming);
        root.expect("selected category's untimed task precedes a later date", root.day, "09:30", untimed);
        root.expect("without a category choice general priority considers other dates", "2024-05-30", "09:30", tomorrow);
        DailyNotes.toggleDone(tomorrow);
        root.expect("no deadline candidate yields unfinished untimed", root.day, "09:30", untimed);
        DailyNotes.toggleDone(untimed);
        root.expect("all completed yields no preview", root.day, "09:30", "");
    }
}
