pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"
import "root:/modules/panels"

Item {
    id: root
    Check { id: check }
    Until { id: wait }
    MprisDriver { id: driver }
    MediaCard { id: card; width: Appearance.m.mediaWidth; tracking: true }

    property var titles: []
    property var firstState: null
    readonly property var observed: [Players.title, Players.artUrl, Players.length, Players.position,
        Players.hasPlayer, Players.identity, Players.playing, Players.canSeek, Players.players.length]
    Connections {
        target: Players
        function onTitleChanged(): void { root.titles = root.titles.concat(Players.title); }
    }

    function until(name: string, done: var, then: var): void {
        wait.until(root.observedChanged, done, ok => {
            Qt.callLater(() => {
                check.equal(name, ok, true);
                if (ok) then(); else check.done();
            });
        });
    }

    function metadata(title: string, art: string, length: real): var {
        const data = { "mpris:trackid": "/org/mpris/MediaPlayer2/firefox", "xesam:title": title,
            "xesam:artist": ["Artist"], "xesam:album": "Album", "xesam:url": "https://music.example/playlist" };
        if (art !== "") data["mpris:artUrl"] = art;
        if (length >= 0) data["mpris:length"] = length * 1000000;
        return data;
    }
    function initial(): void {
        driver.send({ action: "add" }, () => driver.send({ action: "update", properties: {
            Metadata: root.metadata("First", driver.cover, 180) } }, () => {
                root.until("real MPRIS player discovered", () => Players.title === "First"
                    && Players.artUrl === driver.cover && Players.length === 180, () => {
                    check.equal("initial cover", Players.artUrl, driver.cover);
                    check.near("initial duration in seconds", Players.length, 180);
                    check.equal("artist decoded", Players.artist, "Artist");
                    check.equal("D-Bus object path contributes track identity",
                        Players.trackKey.includes("/org/mpris/MediaPlayer2/firefox"), true);
                    root.missing();
                });
            }));
    }
    function missing(): void {
        driver.send({ action: "update", properties: { Metadata: root.metadata("First", "", -1) } }, () => {
            // A settle after the update, never a repeating query.
            driver.after(300, () => {
                check.equal("same-track metadata withdrawal retains cover", Players.artUrl, driver.cover);
                check.near("same-track metadata withdrawal retains duration", Players.length, 180);
                check.equal("timeline remains present", card.hasLength, true);
                root.burst();
            });
        });
    }
    function burst(): void {
        root.titles = [];
        driver.send({ action: "update", properties: { Metadata: root.metadata("Playlist", "", 180) } }, () =>
            driver.send({ action: "update", properties: { Metadata: root.metadata("Second", driver.otherCover, -1) } }, () =>
                driver.send({ action: "update", properties: { Metadata: root.metadata("Playlist", "", 180) } }, () =>
                    driver.send({ action: "update", properties: { Metadata: root.metadata("Second", "", 240) } }, () => {
                        root.until("track burst settles", () => Players.title === "Second" && Players.length === 240, () => {
                            check.equal("page titles never escape the burst", root.titles.join(","), "Second");
                            check.equal("brief new-track cover retained", Players.artUrl, driver.otherCover);
                            check.equal("timeline survives track switch", card.hasLength, true);
                            root.unknown();
                        });
                    }))));
    }
    function unknown(): void {
        driver.send({ action: "update", properties: { Metadata: root.metadata("Unknown", "", -1) } }, () => {
            root.until("unknown-duration track settles", () => Players.title === "Unknown" && Players.length === 0, () => {
                check.equal("new track never inherits old art", Players.artUrl, "");
                check.equal("unknown duration cannot seek", Players.canSeek, false);
                check.equal("unknown duration has no fake timeline", card.hasLength, false);
                driver.send({ action: "update", properties: { Metadata: root.metadata("First", driver.cover, 180) } }, () => {
                    root.until("track with duration returns", () => Players.length === 180 && Players.canSeek, () => root.bounds());
                });
            });
        });
    }
    function bounds(): void {
        driver.send({ action: "seek", position: -5000000 }, () => {
            root.until("negative position clamped", () => Players.position === 0, () => {
                driver.send({ action: "seek", position: 999000000 }, () => {
                    root.until("position beyond duration clamped", () => Players.position === 180, () => {
                        check.equal("nonfinite time is safe", Players.formatTime(Infinity), "0:00");
                        check.equal("negative time is safe", Players.formatTime(-5), "0:00");
                        check.equal("hours are formatted", Players.formatTime(3723.9), "1:02:03");
                        root.readOnly();
                    });
                });
            });
        });
    }
    function readOnly(): void {
        driver.send({ action: "update", properties: { CanSeek: false } }, () => {
            root.until("seek permission withdrawn", () => !Players.canSeek, () => {
                check.equal("read-only player keeps its timeline", card.hasLength, true);
                check.near("read-only timeline retains reported progress", card.position, 1);
                const timeline = driver.find(card, item => item instanceof MediaTimeline)[0];
                check.equal("read-only timeline disables interaction", timeline.interactive, false);
                driver.send({ action: "update", properties: { CanSeek: true } }, () => {
                    root.until("seek permission restored", () => Players.canSeek, () => root.selection());
                });
            });
        });
    }
    function selection(): void {
        root.firstState = Players.selected;
        driver.send({ action: "update", properties: { Metadata: root.metadata("First", "", -1) } }, () =>
            driver.send({ action: "add", player: "other" }, () =>
                driver.send({ action: "update", player: "other", properties: { PlaybackStatus: "Playing",
                    Metadata: root.metadata("Other player", "", 300) } }, () => {
                    root.until("playing player selected", () => Players.identity === "other" && Players.length === 300, () => {
                        check.equal("other player cannot inherit cover", Players.artUrl, "");
                        driver.send({ action: "update", properties: { PlaybackStatus: "Playing" } }, () => {
                            driver.after(200, () => {
                                check.equal("playing selection remains sticky", Players.identity, "other");
                                driver.send({ action: "update", player: "other", properties: { PlaybackStatus: "Paused" } }, () => {
                                    root.until("selection follows remaining playing player", () => Players.identity === "fixture", () => {
                                        check.equal("returning player retains own state", Players.selected, root.firstState);
                                        check.equal("returning player retains withdrawn art", Players.artUrl, driver.cover);
                                        root.removal();
                                    });
                                });
                            });
                        });
                    });
                })));
    }
    function removal(): void {
        driver.send({ action: "remove" }, () => {
            root.until("current player removal selects remaining player", () => Players.identity === "other", () => {
                driver.send({ action: "remove", player: "other" }, () => {
                    root.until("last player removal clears selection", () => !Players.hasPlayer, () => {
                        check.equal("removal clears cover", Players.artUrl, "");
                        check.near("removal clears duration", Players.length, 0);
                        check.near("removal clears position", Players.position, 0);
                        check.equal("removal hides card", card.implicitHeight, 0);
                        root.unsupported();
                    });
                });
            });
        });
    }
    function unsupported(): void {
        driver.send({ action: "add", position: false }, () =>
            driver.send({ action: "update", properties: { Metadata: root.metadata("No position", "", 180) } }, () => {
                root.until("player without position discovered", () => Players.title === "No position" && Players.length === 180, () => {
                    check.equal("position support required for seek", Players.canSeek, false);
                    check.equal("unsupported position has no fake timeline", card.hasLength, false);
                    check.done();
                });
            }));
    }
    Component.onCompleted: {
        if (!driver.isolated) {
            check.report("private bus required", false, "run tools/test.sh");
            check.done(); return;
        }
        wait.until(driver.readyChanged, () => driver.ready, ok => {
            check.equal("MPRIS fixture ready", ok, true);
            if (ok) root.initial(); else check.done();
        });
    }
}
