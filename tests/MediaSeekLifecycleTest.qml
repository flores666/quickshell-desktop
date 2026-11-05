pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/services"
import "root:/modules/panels"

/*! Rapid pointer reversals and repeated keys must keep a continuous picture
    while dispatch uses the latest actual target, once per committed gesture. */
Item {
    id: root
    Check { id: check }
    Until { id: wait }
    TestEvent { id: input }
    MprisDriver { id: driver }
    readonly property MediaTimeline seek: driver.find(card, item => item instanceof MediaTimeline)[0]
    readonly property var observed: [Players.hasPlayer, Players.position, Players.canSeek, Players.selected?.pendingSeek, driver.calls,
        root.seek?.value, root.seek?.displayed, root.seek?.animating]
    property real turn: 0
    property real expectedSeek: 0

    PanelWindow {
        implicitWidth: Appearance.m.mediaWidth
        implicitHeight: card.implicitHeight
        visible: Players.active
        exclusiveZone: 0
        WlrLayershell.namespace: "shell-media-seek-test"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        MediaCard { id: card; width: parent.width; tracking: true }
    }
    FrameAnimation {
        id: presented
        property int frames: 0
        onTriggered: {
            if (++presented.frames < 2) return;
            presented.running = false;
            root.drag();
        }
    }
    function until(name: string, done: var, then: var): void {
        wait.until(root.observedChanged, done, ok => Qt.callLater(() => {
            check.equal(name, ok, true);
            if (ok) then(); else check.done();
        }));
    }
    function pointX(value: real): real { return root.seek.knobSize / 2 + root.seek.spanX * value; }
    function drag(): void {
        input.mousePress(root.seek, root.pointX(1), root.seek.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
        check.near("pointer press sets the actual target", root.seek.value, 1);
        check.equal("preview does not dispatch early", driver.calls.length, 0);
        root.until("pointer preview animates", () => root.seek.animating && root.seek.displayed > 0.6
            && root.seek.displayed < 1, () => {
            root.turn = root.seek.displayed;
            input.mouseMove(root.seek, root.pointX(0), root.seek.height / 2, -1, Qt.LeftButton, Qt.NoModifier);
            check.near("reverse drag sets the actual target", root.seek.value, 0);
            check.within("reverse drag does not jump", root.seek.displayed, root.turn, 0.1);
            root.until("reversed preview moves toward the new target", () => root.seek.animating
                && root.seek.displayed > 0 && root.seek.displayed < root.turn, () => {
                input.mouseMove(root.seek, root.pointX(2 / 3), root.seek.height / 2, -1, Qt.LeftButton, Qt.NoModifier);
                input.mouseMove(root.seek, root.pointX(0), root.seek.height / 2, -1, Qt.LeftButton, Qt.NoModifier);
                input.mouseRelease(root.seek, root.pointX(0), root.seek.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
                root.until("one drag dispatches only its final target", () => driver.calls.length === 1
                    && Players.position === 0, () => {
                    check.equal("drag dispatch uses the actual zero target", driver.calls[0][3], 0);
                    root.until("reversed animation settles at zero", () => !root.seek.animating
                        && root.seek.displayed === 0, () => root.keys());
                });
            });
        });
    }
    function keys(): void {
        for (let i = 0; i < 5; ++i) input.keyClick(Qt.Key_Right, Qt.NoModifier, -1);
        check.near("rapid keys accumulate from the actual value", root.seek.value, 0.25);
        root.until("all keyboard gestures reach the backend", () => driver.calls.length === 6
            && Math.abs(Players.position - 45) < 0.001, () => {
            check.equal("last keyboard seek has the correct microseconds", driver.calls[5][3], 45000000);
            root.until("latest keyboard target wins", () => !root.seek.animating
                && root.seek.displayed === 0.25, () => root.repeatedTarget());
        });
    }
    function repeatedTarget(): void {
        driver.send({ action: "seek-ack", enabled: false }, () => {
            input.keyClick(Qt.Key_Right, Qt.NoModifier, -1);
            input.keyClick(Qt.Key_Left, Qt.NoModifier, -1);
            input.keyClick(Qt.Key_Right, Qt.NoModifier, -1);
            check.near("A/B/A requests keep the last actual target", root.seek.value, 0.3);
            root.until("A/B/A gestures reach the backend", () => driver.calls.length === 9, () => {
                driver.send({ action: "seek", position: 54000000 }, () => {
                    root.until("first A reply cannot acknowledge the last A", () => Players.selected.pendingSeek?.requests.length === 2, () => {
                        driver.send({ action: "seek", position: 45000000 }, () => {
                            root.until("B reply is consumed before the last A", () => Players.selected.pendingSeek?.requests.length === 1, () => {
                                check.near("B reply cannot roll back the last A target", Players.position, 54);
                                driver.send({ action: "seek", position: 54000000 }, () => {
                                    root.until("last A reply confirms the pending seek", () => Players.selected.pendingSeek === null, () => {
                                        driver.send({ action: "seek-ack", enabled: true }, () => root.missingAck());
                                    });
                                });
                            });
                        });
                    });
                });
            });
        });
    }
    function missingAck(): void {
        driver.send({ action: "seek-ack", enabled: false }, () => {
            root.expectedSeek = (root.seek.value + root.seek.stepSize) * Players.length;
            input.keyClick(Qt.Key_Right, Qt.NoModifier, -1);
            root.until("unconfirmed seek reaches the backend", () => driver.calls.length === 10, () => {
                Players.refreshPosition();
                check.equal("local clock read cannot acknowledge a seek", Players.selected.pendingSeek !== null, true);
                driver.send({ action: "seek", position: 0 }, () => {
                    Qt.callLater(() => {
                        check.near("older position cannot replace the latest seek intent", Players.position, root.expectedSeek);
                        root.playbackChange();
                    });
                });
            });
        });
    }
    function playbackChange(): void {
        driver.send({ action: "update", properties: { PlaybackStatus: "Playing", Rate: 2 } }, () => {
            root.until("playback and rate change arrive during a pending seek", () => Players.playing, () => {
                check.equal("playback change preserves seek intent", Players.selected.pendingSeek !== null, true);
                driver.send({ action: "update", properties: { PlaybackStatus: "Paused", Rate: 1 } }, () => {
                    root.until("pause arrives during pending seek", () => Players.paused, () => {
                        check.equal("pause preserves seek intent", Players.selected.pendingSeek !== null, true);
                        check.equal("pause keeps the advanced intended position", Players.position >= root.expectedSeek, true);
                        driver.send({ action: "seek", position: 0 }, () => {
                            root.until("unconfirmed seek eventually releases backend state", () => Players.selected.pendingSeek === null
                                && Players.position === 0, () => {
                                driver.send({ action: "seek-ack", enabled: true }, () => root.hidden());
                            });
                        });
                    });
                });
            });
        });
    }
    function hidden(): void {
        card.tracking = false;
        driver.send({ action: "seek", position: 180000000 }, () => {
            root.until("hidden seek arrives", () => root.seek.value === 1, () => {
                check.equal("hidden seek does not animate", root.seek.animating, false);
                check.near("hidden seek snaps to its target", root.seek.displayed, 1);
                card.tracking = true;
                Qt.callLater(() => {
                    check.equal("reopening does not replay a hidden seek", root.seek.animating, false);
                    driver.send({ action: "seek", position: 90000000 }, () => {
                        root.until("visible seek starts again", () => root.seek.animating
                            && root.seek.displayed < 1 && root.seek.displayed > 0.5, () => {
                            driver.send({ action: "remove" }, () => root.until("removing the player cancels motion",
                                () => !Players.hasPlayer && !root.seek.animating, () => {
                                check.near("removed player leaves no stale progress", root.seek.displayed, 0);
                                check.done();
                            }));
                        });
                    });
                });
            });
        });
    }
    Component.onCompleted: {
        if (!driver.isolated) {
            check.report("private fixture required", false, "run tools/test.sh");
            check.done(); return;
        }
        wait.until(driver.readyChanged, () => driver.ready, ok => {
            check.equal("MPRIS fixture ready", ok, true);
            if (!ok) { check.done(); return; }
            driver.send({ action: "add" }, () => driver.send({ action: "update", properties: {
                Metadata: { "mpris:trackid": "/fixture/track", "xesam:title": "Rapid seeking", "mpris:length": 180000000 }
            } }, () => root.until("initial timeline settles", () => Players.canSeek
                && root.seek.displayed === root.seek.clamped, () => presented.running = true)));
        });
    }
}
