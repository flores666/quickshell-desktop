pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "root:/services"
import "root:/modules/lock"

// TEST_LOCK_SESSION=1 tools/test.sh LockScreenTest, on a disposable nested
// compositor only: the real session-lock protocol, with private PAM stacks.
Item {
    id: root
    property var locker: null
    property bool backgroundWorked: false
    Check { id: check }
    Command { id: sh }
    Until { id: wait }
    TestEvent { id: keys }
    Process {
        id: worker
        command: ["lock-background"]
        stdout: StdioCollector {
            onStreamFinished: root.backgroundWorked = this.text.trim() === "completed"
        }
    }

    function until(name: string, signal: var, done: var, then: var): void {
        wait.until(signal, done, ok => {
            check.equal(name, ok, true);
            if (ok) Qt.callLater(then);
            else check.done();
        });
    }

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "" || Quickshell.env("TEST_LOCK_SESSION") !== "1") {
            check.report("isolated compositor required", false, "see LockScreenTest.qml");
            check.done(); return;
        }
        sh.run('python3 "$1" lock', [Qt.resolvedUrl("ServiceFixtures.py").toString().replace("file://", "")], url => {
            const component = Qt.createComponent(url.trim());
            check.equal("private lock fixture loads", component.errorString(), "");
            root.locker = component.createObject(root);
            if (!root.locker) { check.done(); return; }
            worker.running = true;
            sh.run("hyprctl switchxkblayout all 1", [], () => {
                Session.lock();
                root.until("compositor confirms a secure lock", root.locker.sessionLock.secureStateChanged,
                    () => root.locker.sessionLock.secure, root.english);
            });
        });
    }

    function english(): void {
        sh.run('printf go > "$TEST_BIN/background-control"', [], () => {
            root.until("pre-existing background worker computes while locked", root.backgroundWorkedChanged,
                () => root.backgroundWorked, root.keyboard);
        });
    }

    function keyboard(): void {
        root.until("English is ready", Keyboard.lockReadyChanged, () => Keyboard.lockReady, () => {
            check.equal("English layout active", Keyboard.code, "EN");
            check.equal("no layout failure", Keyboard.lockFailure, "");
            const input = root.locker.surfaces.find(s => s.visible).content.input;
            check.equal("passwords stay concealed", input.echoMode, TextInput.Password);
            check.equal("password input enabled", input.enabled, true);
            root.locker.password = "retained";
            Session.lock();
            check.equal("repeat Lock preserves the current attempt", root.locker.password, "retained");
            sh.run("hyprctl switchxkblayout all 1", [], () => {
                root.until("layout toggle settles back to English", Keyboard.lockReadyChanged,
                    () => Keyboard.lockReady && Keyboard.code === "EN", root.denied);
            });
        });
    }

    function denied(): void {
        root.locker.authentication.config = "deny";
        root.locker.submit();
        root.until("failed authentication completes", root.locker.busyChanged, () => !root.locker.busy, () => {
            check.equal("failed authentication keeps the lock", root.locker.sessionLock.secure, true);
            check.equal("failed authentication erases the password", root.locker.password, "");
            check.equal("failure is shown", root.locker.statusIsError, true);
            root.locker.authentication.config = "permit";
            const input = root.locker.surfaces.find(s => s.visible).content.input;
            input.forceActiveFocus();
            check.equal("typing reaches the password owner", keys.keyClickChar("a", Qt.NoModifier, -1), true);
            check.equal("typed password retained", root.locker.password, "a");
            check.equal("Enter submits", keys.keyClick(Qt.Key_Return, Qt.NoModifier, -1), true);
            root.until("successful PAM authentication unlocks", root.locker.lockIntent.lockedChanged,
                () => !root.locker.lockIntent.locked, root.restored);
        });
    }

    function restored(): void {
        root.until("English lease is released after unlock", Keyboard.lockEnglishChanged, () => !Keyboard.lockEnglish,
            root.layoutsRestored);
    }

    function layoutsRestored(): void {
        root.until("each keyboard's layout is restored", Keyboard.lockReadyChanged, () => Keyboard.lockReady, () => {
            sh.run("hyprctl devices -j", [], text => {
                const devices = JSON.parse(text).keyboards;
                check.equal("compositor no longer holds the session lock", root.locker.sessionLock.secure, false);
                check.equal("original Russian group restored", devices.every(k => k.active_layout_index === 1), true);
                check.equal("unlock clears the password", root.locker.password, "");
                check.equal("English lease released", Keyboard.lockEnglish, false);
                root.locker.surfaces = [];
                Session.lock();
                // Releasing during the initial read must not leave a delayed
                // English write behind after unlock.
                root.locker.lockIntent.locked = false;
                root.until("rapid lock/unlock reconciles", Keyboard.lockReadyChanged, () => Keyboard.lockReady, () => {
                    sh.run("hyprctl devices -j", [], after => {
                        check.equal("rapid unlock keeps the original group",
                            JSON.parse(after).keyboards.every(k => k.active_layout_index === 1), true);
                        check.done();
                    });
                });
            });
        });
    }
}
