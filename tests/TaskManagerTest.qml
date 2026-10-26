import QtQuick
import "root:/services"
import "root:/modules/common"
import "root:/modules/tasks"

/*!
    The task manager popup: toggled by its action, opening on Processes, the
    process list sampled exactly while it shows Processes or Memory, a row's
    menu offering only what applies to that process, and the ways in — the
    bind and the launcher's entry.
*/
Item {
    id: root

    Check {
        id: check
    }

    Command {
        id: sh
    }

    ShellIpc {
        id: ipc
    }

    OverlaySurface {
        TaskManager {
            id: manager
        }
    }

    function labels(entries: var): var {
        return entries.map(e => e.label);
    }

    Component.onCompleted: {
        check.equal("an action", ipc.actions.includes("taskManager"), true);
        check.equal("closed: unwatched", Processes.watched, false);

        check.attempt("open", () => {
            ipc.run("taskManager");
            check.equal("open: it is the one open", Overlay.active, Overlay.taskManager);
            check.equal("open: on Processes", manager.tab, "processes");
            check.equal("open: watched", Processes.watched, true);
        });
        check.attempt("tabs", () => {
            manager.tab = "scheduled";
            check.equal("Scheduled: unwatched", Processes.watched, false);
            manager.tab = "memory";
            check.equal("Memory: watched", Processes.watched, true);
        });
        check.attempt("close", () => {
            ipc.run("taskManager");
            check.equal("closed again", Overlay.active, Overlay.none);
            check.equal("closed again: unwatched", Processes.watched, false);
        });

        check.attempt("menus", () => {
            const own = { pid: 4242, uid: Processes.uid, own: true, name: "sleep" };
            const theirs = { pid: 1, uid: 0, own: false, name: "systemd" };
            const odd = { pid: 7, uid: Processes.uid, own: true, name: "a\\b" };
            check.equal("own, no earlyoom", JSON.stringify(root.labels(manager.menuFor(own, false, ""))),
                JSON.stringify(["End", "Force Kill"]));
            check.equal("another user's, no earlyoom", manager.menuFor(theirs, false, "").length, 0);
            check.equal("another user's, earlyoom", JSON.stringify(root.labels(manager.menuFor(theirs, true, ""))),
                JSON.stringify(["Protect from earlyoom", "Kill First"]));
            check.equal("protected", JSON.stringify(root.labels(manager.menuFor(own, true, "avoid"))),
                JSON.stringify(["End", "Force Kill", "Kill First", "No earlyoom Preference"]));
            check.equal("killed first", JSON.stringify(root.labels(manager.menuFor(own, true, "prefer"))),
                JSON.stringify(["End", "Force Kill", "Protect from earlyoom", "No earlyoom Preference"]));
            check.equal("a name no list can hold", JSON.stringify(root.labels(manager.menuFor(odd, true, ""))),
                JSON.stringify(["End", "Force Kill"]));
        });

        sh.run("grep -c '^bind = CTRL SHIFT, Escape, global, shell:taskManager$' \"$1\"; "
            + "grep -c '^Exec=qs -c shell ipc call shell taskManager$' \"$2\"",
            [Qt.resolvedUrl("../hyprland.conf").toString().replace("file://", ""),
             Qt.resolvedUrl("../applications/quickshell-task-manager.desktop").toString().replace("file://", "")],
            out => {
                check.equal("the ways in: the bind and the launcher's entry", out.trim().split("\n").join(" "), "1 1");
                check.done();
            });
    }
}
