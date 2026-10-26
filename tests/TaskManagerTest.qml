import QtQuick
import "root:/services"
import "root:/modules/common"
import "root:/modules/tasks"

/*!
    The task manager popup: toggled by its action, opening on Processes or on
    the tab its subject names, its tabs in order with the GPU's only while
    there is a GPU, every pane loading, the process list sampled exactly while
    it shows a reading (every tab but Scheduled), the process table's columns
    and first sort, a row's menu offering only what applies to that process,
    and the ways in — the bind and the launcher's entry.
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
        id: wait
    }

    ShellIpc {
        id: ipc
    }

    OverlaySurface {
        TaskManager {
            id: manager
        }
    }

    readonly property var withGpu: ["processes", "performance", "disk", "network", "gpu", "memory", "scheduled"]

    function labels(entries: var): var {
        return entries.map(e => e.label);
    }

    function keys(): string {
        return manager.tabs.map(t => t.key).join(" ");
    }

    /*! The panes built since it was last counted. */
    property int built: 0

    Connections {
        target: manager.pane

        function onLoaded(): void {
            root.built++;
        }
    }

    function loaded(): bool {
        return manager.pane.status === Loader.Ready && manager.pane.item !== null;
    }

    /*! Calls `then` once the pane is built, after an open. */
    function whenBuilt(then: var): void {
        wait.until(manager.pane.loaded, () => root.loaded(), ok => {
            check.equal("its pane built", ok, true);
            then();
        });
    }

    /*! Calls `then` once the card has gone, after a close. */
    function whenGone(then: var): void {
        wait.until(manager.renderedChanged, () => !manager.rendered, ok => {
            check.equal("gone", ok, true);
            then();
        });
    }

    Component.onCompleted: {
        check.equal("an action", ipc.actions.includes("taskManager"), true);
        check.equal("closed: unwatched", Processes.watched, false);

        check.attempt("tabs", () => {
            Usage.hasGpu = true;
            check.equal("tabs with a GPU", root.keys(), root.withGpu.join(" "));
            Usage.hasGpu = false;
            check.equal("tabs without a GPU", root.keys(), root.withGpu.filter(k => k !== "gpu").join(" "));
            check.equal("every tab has a glyph", manager.tabs.every(t => t.icon !== ""), true);
        });

        check.attempt("open", () => {
            ipc.run("taskManager");
            check.equal("open: it is the one open", Overlay.active, Overlay.taskManager);
            check.equal("open: on Processes", manager.tab, "processes");
            check.equal("open: watched", Processes.watched, true);
        });
        root.whenBuilt(root.panes);
    }

    function panes(): void {
        check.attempt("panes", () => {
            Usage.hasGpu = true;
            for (const key of root.withGpu) {
                manager.tab = key;
                check.equal(key + ": its pane loaded", root.loaded(), true);
                check.equal(key + ": " + (key === "scheduled" ? "unwatched" : "watched"), Processes.watched,
                    key !== "scheduled");
            }
        });

        check.attempt("the GPU going", () => {
            manager.tab = "gpu";
            Usage.hasGpu = false;
            check.equal("its tab falls back to Processes", manager.tab, "processes");
            check.equal("Processes loaded", root.loaded(), true);
        });

        check.attempt("the process table", () => {
            manager.tab = "processes";
            const pane = manager.pane.item;
            check.equal("columns after the name", pane.columns.map(c => c.key).join(" "), "cpu rss io pid");
            check.equal("sorted by CPU", pane.sortKey, "cpu");
            check.equal("highest first", pane.descending, true);
            pane.sortBy("pid");
            check.equal("a heading sorts by its column", pane.sortKey, "pid");
            pane.sortBy("name");
            check.equal("names from A", pane.descending, false);
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

        root.whenGone(root.subjects);
    }

    /*! Opened with a subject naming a tab (the date menu's cards), it shows
        that tab, and builds no other pane first; opened plainly once it has
        gone, Processes again; for a tab it does not have, Processes. */
    function subjects(): void {
        check.attempt("opened for a tab", () => {
            root.built = 0;
            Overlay.openWith(Overlay.taskManager, null, 0, { tab: "performance" });
            check.equal("on the tab asked for", manager.tab, "performance");
            check.equal("for a tab: watched", Processes.watched, true);
        });
        root.whenBuilt(() => {
            check.equal("for a tab: that pane built first, and no other", root.built, 1);
            Overlay.close();
            root.whenGone(() => {
                check.attempt("opened plainly", () => {
                    ipc.run("taskManager");
                    check.equal("plainly: on Processes", manager.tab, "processes");
                    Overlay.close();
                });
                root.whenGone(() => {
                    check.attempt("a tab it lacks", () => {
                        Usage.hasGpu = false;
                        Overlay.openWith(Overlay.taskManager, null, 0, { tab: "gpu" });
                        check.equal("no GPU: on Processes", manager.tab, "processes");
                        Overlay.close();
                    });
                    root.waysIn();
                });
            });
        });
    }

    function waysIn(): void {
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
