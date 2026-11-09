pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/services"
import "root:/modules/tasks"

/* Real user units, with only pkexec replaced. No administrator setup can
   escape the fixture, and no privileged task is started by this test. */
Item {
    id: root
    readonly property string directory: Quickshell.env("TEST_BIN")
    readonly property string prefix: "qs-taskauthtest-"
    readonly property string id: root.prefix + "saved"
    Check { id: check }
    Command { id: sh }
    Until { id: wait; bound: 5000 }
    property int completed: 0
    Loader {
        id: editor
        active: false
        width: Appearance.m.paneCardWidth
        sourceComponent: TaskEditor {
            task: root.definition
            onDone: {
                root.completed++;
                editor.active = false;
            }
        }
    }

    readonly property var definition: ({ id: root.id, name: "Administrator fixture", command: "true",
        schedule: "once 2099-01-01 09:00", privileged: true })

    function listed(): var { return Tasks.tasks.find(t => t.id === root.id); }

    function idle(then: var): void {
        wait.until(Tasks.busyChanged, () => !Tasks.busy, ok => {
            check.equal("operation finished", ok, true);
            then();
        });
    }

    function answer(code: int, then: var): void {
        sh.run('printf %s "$2" > "$1/answer"', [root.directory, String(code)], then);
    }

    Component.onCompleted: {
        if (root.directory === "") {
            check.report("private fixtures required", false, "run tools/test.sh");
            check.done(); return;
        }
        Tasks.prefix = root.prefix;
        sh.run('python3 "$1" 2>&1', [Qt.resolvedUrl("TaskAdminTest.py").toString().replace("file://", "")], out => {
            check.report("snapshot and policy regression tests", out.includes("\nOK"), out);
            root.prepare();
        });
    }

    function prepare(): void {
        sh.run('python3 "$1" || exit 1; test "$(command -v pkexec)" = "$TEST_BIN/pkexec" || exit 1; '
            + 'systemctl --user disable --now "$3.service" "$3.timer" >/dev/null 2>&1; '
            + 'rm -f "$2/$3.service" "$2/$3.timer"; systemctl --user daemon-reload && echo ready',
            [Qt.resolvedUrl("TaskAuthorizationFixture.py").toString().replace("file://", ""), Tasks.dir, root.id],
            out => {
                check.equal("private authorization fixture ready", out.trim(), "ready");
                if (out.trim() !== "ready") { check.done(); return; }
                root.cancelled();
            });
    }

    function cancelled(): void {
        root.answer(126, () => {
            editor.active = true;
            check.equal("editor loads administrator choice", editor.item.privileged, true);
            editor.item.save();
            check.equal("save waits for authorization", Tasks.busy, true);
            root.idle(() => {
                check.report("cancelled: visible error", Tasks.failure.includes("No authorization"), Tasks.failure);
                check.equal("cancelled: editor remains open", editor.active, true);
                check.equal("cancelled: no save completion", root.completed, 0);
                sh.run('test ! -e "$1/$2.service" && echo untouched', [Tasks.dir, root.id], out => {
                    check.equal("cancelled: no unit created", out.trim(), "untouched");
                    root.install();
                });
            });
        });
    }

    function install(): void {
        root.answer(0, () => {
            editor.item.save();
            wait.until(Tasks.tasksChanged, () => root.listed()?.privileged === true, ok => {
                check.equal("authorized: listed as administrator", ok, true);
                check.equal("authorized: command read back", root.listed()?.command, "true");
                check.equal("authorized: previous error cleared", Tasks.failure, "");
                check.equal("authorized: editor closed after success", editor.active, false);
                check.equal("authorized: one save completion", root.completed, 1);
                root.failedEdit();
            });
        });
    }

    function failedEdit(): void {
        root.answer(126, () => {
            Tasks.save(Object.assign({}, root.definition, { command: "false" }));
            root.idle(() => {
                sh.run('grep -x X-QsTask-Command=true "$1/$2.service"', [Tasks.dir, root.id], out => {
                    check.equal("cancelled edit: previous command intact", out.trim(), "X-QsTask-Command=true");
                    root.failedRemove();
                });
            });
        });
    }

    function failedRemove(): void {
        Tasks.remove(root.id);
        root.idle(() => {
            sh.run('test -e "$1/$2.service" && echo retained', [Tasks.dir, root.id], out => {
                check.equal("cancelled removal: task retained", out.trim(), "retained");
                root.demote();
            });
        });
    }

    function demote(): void {
        root.answer(0, () => {
            Tasks.save(Object.assign({}, root.definition, { privileged: false }));
            wait.until(Tasks.tasksChanged, () => root.listed()?.privileged === false, ok => {
                check.equal("administrator rights removed", ok, true);
                sh.run('cat "$1/requests"', [root.directory], out => {
                    const requests = out.trim().split("\n").map(line => JSON.parse(line));
                    check.equal("authorization actions", requests.map(r => r[3]).join(" "),
                        "install install install remove remove");
                    check.equal("helper uses isolated Python", requests[0].slice(0, 2).join(" "), "/usr/bin/python3 -I");
                    check.equal("helper receives original command", requests[0][5], "true");
                    root.remove();
                });
            });
        });
    }

    function remove(): void {
        Tasks.remove(root.id);
        wait.until(Tasks.tasksChanged, () => root.listed() === undefined, ok => {
            check.equal("task removed", ok, true);
            sh.run('wc -l < "$1/requests"', [root.directory], out => {
                check.equal("ordinary removal needs no authorization", out.trim(), "5");
                check.done();
            });
        });
    }
}
