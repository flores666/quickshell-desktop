pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"
import "root:/modules/panels"

/*! Zen claims its MPRIS name before exporting the player. Quickshell's first
    GetAll fails; later valid signals must make the player discoverable. */
Item {
    id: root
    Check { id: check }
    Until { id: wait; bound: 2500 }
    MprisDriver { id: driver }
    MediaCard { id: card; width: Appearance.m.mediaWidth }
    readonly property var observed: [Players.hasPlayer, Players.active, Players.title, Players.canPlay]
    property var player: null

    function start(): void {
        driver.send({ action: "add", exported: false }, () => {
            wait.until(driver.missingChanged, () => driver.missing >= 2, ok => {
                check.equal("initial read reaches unexported object", ok, true);
                if (!ok) { check.done(); return; }
                driver.after(80, () => {
                    check.equal("failed initial read leaves player undiscovered", Players.hasPlayer, false);
                    driver.send({ action: "export" }, () => driver.send({ action: "update", properties: {
                        PlaybackStatus: "Playing", Position: 120000000,
                        Metadata: { "mpris:trackid": "/browser", "xesam:title": "YouTube video",
                            "xesam:artist": ["Channel"], "xesam:url": "https://www.youtube.com/watch?v=fixture",
                            "mpris:artUrl": driver.cover, "mpris:length": 600000000 }
                    } }, () => {
                        wait.until(root.observedChanged, () => Players.active && Players.title === "YouTube video"
                            && Players.canPlay, recovered => Qt.callLater(() => {
                            check.equal("late-exported YouTube player becomes visible", recovered, true);
                            if (!recovered) { check.done(); return; }
                            check.equal("real playback state retained", Players.playing, true);
                            check.equal("card shown", card.visible, true);
                            check.equal("timeline available", card.hasLength, true);
                            check.equal("cover available", Players.artUrl, driver.cover);
                            check.near("duration recovered", Players.length, 600);
                            root.player = Players.current;
                            root.stable();
                        }));
                    }));
                });
            });
        });
    }
    function stable(): void {
        driver.send({ action: "actions" }, before => {
            driver.send({ action: "update", properties: { CanGoNext: true } }, () => driver.after(80, () => {
                driver.send({ action: "actions" }, after => {
                    check.equal("healthy player keeps its object", Players.current, root.player);
                    check.equal("healthy player is not queried again", after.getAll.fixture, before.getAll.fixture);
                    root.replacement();
                });
            }));
        });
    }
    function replacement(): void {
        driver.send({ action: "remove" }, () => {
            wait.until(root.observedChanged, () => !Players.hasPlayer, gone => Qt.callLater(() => {
                check.equal("player withdrawal clears selection", gone, true);
                driver.missing = 0;
                driver.send({ action: "add", exported: false }, () => {
                    wait.until(driver.missingChanged, () => driver.missing >= 2, missing => {
                        check.equal("replacement can fail its initial read", missing, true);
                        driver.send({ action: "remove" }, () =>
                            driver.send({ action: "add" }, () => driver.send({ action: "update", properties: {
                                PlaybackStatus: "Playing", Metadata: { "xesam:title": "Replacement video", "mpris:length": 90000000 }
                            } }, () => {
                                wait.until(root.observedChanged, () => Players.title === "Replacement video" && Players.active,
                                    restored => Qt.callLater(() => {
                                        check.equal("same-name new owner is discovered", restored, true);
                                        check.equal("retired player is not resurrected", Players.current !== root.player, true);
                                        driver.send({ action: "actions" }, response => {
                                            check.equal("replacement receives only its normal initial read", response.getAll.fixture, 2);
                                            check.done();
                                        });
                                    }));
                            })));
                    });
                });
            }));
        });
    }
    Component.onCompleted: {
        if (!driver.isolated) {
            check.report("private bus required", false, "run tools/test.sh");
            check.done(); return;
        }
        wait.until(driver.readyChanged, () => driver.ready, ok => {
            check.equal("MPRIS fixture ready", ok, true);
            if (ok) root.start(); else check.done();
        });
    }
}
