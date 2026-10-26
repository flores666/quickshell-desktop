import QtQuick
import "root:/services"
import "root:/modules/common"
import "root:/modules/panels"
import "root:/modules/tasks"

/*!
    The date menu's CPU and memory cards: sampling runs exactly while they
    are tracked, they read "–" before a reading, and a click opens the task
    manager on its Performance tab.
*/
Item {
    id: root

    Check {
        id: check
    }

    OverlaySurface {
        TaskManager {}
    }

    UsageCards {
        id: cards
        width: 259
    }

    Component.onCompleted: {
        check.equal("untracked: unwatched", Processes.watched, false);
        check.equal("CPU reads – before a reading", cards.cpuFigure, "–");
        check.equal("Memory reads – before a reading", cards.memoryFigure, "–");
        check.equal("it has a height", cards.implicitHeight > 0, true);
        cards.tracking = true;
        check.equal("tracked: watched", Processes.watched, true);
        cards.tracking = false;
        check.equal("untracked again: unwatched", Processes.watched, false);
        cards.openPerformance();
        check.equal("a click opens the task manager", Overlay.active, Overlay.taskManager);
        check.equal("on Performance", Overlay.payload ? Overlay.payload.tab : "", "performance");
        check.done();
    }
}
