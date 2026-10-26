import QtQuick
import "root:/services"
import "root:/modules/common"
import "root:/modules/tasks"

/*!
    The task manager popup: toggled by its action, opening on Processes or on
    the tab its subject names, its tabs in order with the GPU's only while
    there is a GPU, every pane loading, each process read exactly while a tab
    that ranks or lists them is shown (every tab but Schedule) and the extras
    only on their tab (GPU time on GPU, sockets on Network), each entity tab's
    list ranked by its own reading (Activity), the process table's columns
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

    readonly property var withGpu: ["processes", "cpu", "gpu", "ram", "disks", "network", "schedule"]
    readonly property var glyphs: ["grid", "cpu", "gpu", "ram", "disk", "network-transfer", "calendar"]
    /*! What each entity tab ranks processes by, as Activity keys it. */
    readonly property var ranks: ({ cpu: "cpu", gpu: "gpu", ram: "rss", disks: "io", network: "connections" })
    /*! What each tab asks for beside the processes. */
    readonly property var extras: ({ gpu: ["gpu"], network: ["net"] })

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
            check.equal("each tab its glyph", manager.tabs.map(t => t.icon).join(" "), root.glyphs.join(" "));
            Usage.hasGpu = false;
            check.equal("tabs without a GPU", root.keys(), root.withGpu.filter(k => k !== "gpu").join(" "));
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
                // Every tab but Schedule ranks or lists processes; the
                // machine's counters are read always.
                const listing = key !== "schedule";
                check.equal(key + ": " + (listing ? "watched" : "unwatched"), Processes.watched, listing);
                check.equal(key + ": its extras", JSON.stringify(Processes.extras),
                    JSON.stringify(listing ? root.extras[key] ?? [] : []));
                const pane = manager.pane.item;
                if (key in root.ranks) {
                    check.equal(key + ": ranked by " + root.ranks[key], pane.rankKey, root.ranks[key]);
                    check.equal(key + ": its list is Activity's", JSON.stringify(pane.ranked),
                        JSON.stringify(Activity.top(root.ranks[key], 5)));
                    check.equal(key + ": its title in the bar", pane.title, manager.current.title);
                }
            }
            manager.tab = "ram";
            check.equal("RAM: earlyoom's section under it, scrolling", manager.pane.item.scrolls, true);
            manager.tab = "cpu";
            check.equal("CPU: nothing under it, no scrolling", manager.pane.item.scrolls, false);
        });

        check.attempt("the GPU going", () => {
            manager.tab = "gpu";
            Usage.hasGpu = false;
            check.equal("its tab falls back to Processes", manager.tab, "processes");
            check.equal("Processes loaded", root.loaded(), true);
            check.equal("Processes: no extras", JSON.stringify(Processes.extras), "[]");
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
            Overlay.openWith(Overlay.taskManager, null, 0, { tab: "cpu" });
            check.equal("on the tab asked for", manager.tab, "cpu");
            check.equal("for a tab that ranks processes: watched", Processes.watched, true);
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
                    root.whenGone(root.retired);
                });
            });
        });
    }

    /*! A tab there is no more (the date menu's old Performance) opens
        Processes. */
    function retired(): void {
        check.attempt("a tab there is no more", () => {
            Overlay.openWith(Overlay.taskManager, null, 0, { tab: "performance" });
            check.equal("Performance: on Processes", manager.tab, "processes");
            Overlay.close();
        });
        root.waysIn();
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
