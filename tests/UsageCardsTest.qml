import QtQuick
import "root:/services"
import "root:/modules/common"
import "root:/modules/panels"
import "root:/modules/tasks"

/*!
    The date menu's CPU and memory cards: they read "–" before a reading,
    watch no process (the machine's counters are read always), and a click
    opens the task manager on the tab of what was clicked: CPU on CPU, RAM on
    RAM.
*/
Item {
    id: root

    Check {
        id: check
    }

    OverlaySurface {
        TaskManager {
            id: manager
        }
    }

    UsageCards {
        id: cards
        width: 259
    }

    Component.onCompleted: {
        check.equal("CPU reads – before a reading", cards.cpuFigure, "–");
        check.equal("Memory reads – before a reading", cards.memoryFigure, "–");
        check.equal("named as the reference does: CPU and RAM", cards.cards.map(c => c.title).join(" "), "CPU RAM");
        check.equal("each opens its own tab", cards.cards.map(c => c.tab).join(" "), "cpu ram");
        check.equal("it has a height", cards.implicitHeight > 0, true);
        check.equal("they watch no process", Processes.watched, false);
        cards.open("cpu");
        check.equal("a click opens the task manager", Overlay.active, Overlay.taskManager);
        check.equal("CPU's: on CPU", Overlay.payload ? Overlay.payload.tab : "", "cpu");
        check.equal("CPU's: the CPU tab shown", manager.tab, "cpu");
        cards.open("ram");
        check.equal("RAM's: on RAM", Overlay.payload ? Overlay.payload.tab : "", "ram");
        check.done();
    }
}
