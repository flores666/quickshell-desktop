pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import "root:/components"
import "root:/config"
import "root:/services"
import "root:/modules/panels"

Item {
    id: root
    Check { id: check }
    Until { id: wait }
    TestEvent { id: input }
    MprisDriver { id: driver }
    property var subject: null
    property string key: ""
    property real fullHeight: 0
    property int timelineDrops: 0
    property bool watching: false
    readonly property var seek: driver.find(card, item => item instanceof Slider)[0]
    readonly property var art: driver.find(card, item => item instanceof Image)[0]
    readonly property var observed: [Players.title, Players.canSeek, Players.position, card.hasLength,
        root.art?.status, Players.selected?.changing]

    PanelWindow {
        id: window
        implicitWidth: Appearance.m.mediaWidth
        implicitHeight: card.implicitHeight
        visible: Players.active
        exclusiveZone: 0
        WlrLayershell.namespace: "shell-media-test"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        MediaCard {
            id: card
            width: parent.width
            tracking: true
            onHasLengthChanged: if (root.watching && !card.hasLength) root.timelineDrops++
        }
    }
    function metadata(title: string, cover: string, seconds: real): var {
        const data = { "mpris:trackid": "/org/mpris/MediaPlayer2/firefox", "xesam:title": title,
            "xesam:artist": ["Artist"], "xesam:album": "Album", "xesam:url": "https://music.example/playlist" };
        if (cover !== "") data["mpris:artUrl"] = cover;
        if (seconds >= 0) data["mpris:length"] = seconds * 1000000;
        return data;
    }
    function until(name: string, done: var, then: var): void {
        wait.until(root.observedChanged, done, ok => {
            Qt.callLater(() => {
                check.equal(name, ok, true);
                if (ok) then(); else check.done();
            });
        });
    }
    function begin(): void {
        driver.send({ action: "add" }, () => driver.send({ action: "update", properties: {
            Metadata: root.metadata("First", driver.cover, 180) } }, () => {
                root.until("artwork decodes in the real card", () => root.art.status === Image.Ready && Players.canSeek, () => {
                    driver.after(80, () => {
                        root.fullHeight = card.implicitHeight;
                        root.watching = true;
                        root.subject = Players.selected;
                        root.key = Players.trackKey;
                        check.near("paused time shown", card.shownValue * Players.length, 30);
                        root.withdraw();
                    });
                });
            }));
    }
    function withdraw(): void {
        driver.send({ action: "update", properties: { Metadata: root.metadata("First", "", -1) } }, () => {
            driver.after(300, () => {
                check.equal("decoded cover survives withdrawal", root.art.status, Image.Ready);
                check.equal("cover source survives withdrawal", root.art.source.toString(), driver.cover);
                check.near("card keeps its height", card.implicitHeight, root.fullHeight);
                check.equal("timeline never collapsed", root.timelineDrops, 0);
                root.dragAcrossTrack();
            });
        });
    }
    function dragAcrossTrack(): void {
        check.equal("real pointer press accepted", input.mousePress(root.seek, root.seek.width / 2,
            root.seek.height / 2, Qt.LeftButton, Qt.NoModifier, -1), true);
        check.equal("drag starts through Clickable", root.seek.pressed && card.scrubbing, true);
        driver.send({ action: "update", properties: { Metadata: root.metadata("Second", driver.otherCover, -1) } }, () =>
            driver.send({ action: "update", properties: { Metadata: root.metadata("Playlist", "", -1) } }, () =>
                driver.send({ action: "update", properties: { Metadata: root.metadata("Second", "", 240) } }, () => {
                    root.until("new track and cover arrive", () => Players.title === "Second" && Players.length === 240
                        && root.art.status === Image.Ready, () => {
                        check.equal("old drag cancelled", card.scrubbing, false);
                        input.mouseMove(root.seek, root.seek.width * 0.8, root.seek.height / 2, -1, Qt.LeftButton, Qt.NoModifier);
                        input.mouseRelease(root.seek, root.seek.width * 0.8, root.seek.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
                        Players.seekTo(0.5, root.subject, root.key);
                        Players.seekTo(NaN, Players.selected, Players.trackKey);
                        driver.after(80, () => driver.send({ action: "actions" }, response => {
                            check.equal("obsolete gesture never seeks new track", response.actions.length, 0);
                            check.near("track switch keeps card height", card.implicitHeight, root.fullHeight);
                            check.equal("track switch never collapses timeline", root.timelineDrops, 0);
                            root.seekCurrent();
                        }));
                    });
                })));
    }
    function seekCurrent(): void {
        input.mousePress(root.seek, root.seek.width / 2, root.seek.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
        input.mouseRelease(root.seek, root.seek.width / 2, root.seek.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
        root.until("seek updates displayed time", () => Math.abs(Players.position - 120) < 0.05, () => {
            driver.after(80, () => driver.send({ action: "actions" }, response => {
                check.equal("one seek for one gesture", response.actions.length, 1);
                check.equal("seek uses SetPosition", response.actions[0][1], "SetPosition");
                check.equal("seek uses microseconds", response.actions[0][3], 120000000);
                root.pendingSeek();
            }));
        });
    }
    function pendingSeek(): void {
        root.subject = Players.selected;
        root.key = Players.trackKey;
        driver.send({ action: "update", properties: { Metadata: root.metadata("Third", "", 240) } }, () => {
            root.until("raw track change blocks seeking before settle", () => !Players.canSeek, () => {
                Players.seekTo(0.75, root.subject, root.key);
                driver.after(80, () => driver.send({ action: "actions" }, response => {
                    check.equal("pending-track seek rejected", response.actions.length, 1);
                    root.until("third track settles", () => Players.title === "Third" && Players.canSeek, () => root.clock());
                }));
            });
        });
    }
    function clock(): void {
        driver.send({ action: "update", properties: { PlaybackStatus: "Playing", Position: 15000000 } }, () => {
            driver.after(200, () => {
                const before = Players.position;
                driver.send({ action: "actions" }, initial => {
                    root.until("visible timeline advances", () => Players.position > before + 0.05, () => {
                        driver.send({ action: "actions" }, response => {
                            check.equal("clock does not query MPRIS", response.reads, initial.reads);
                            root.reopen();
                        });
                    });
                });
            });
        });
    }
    function reopen(): void {
        card.tracking = false;
        const before = Players.position;
        driver.after(1200, () => {
            check.near("hidden timeline does no clock work", Players.position, before);
            card.tracking = true;
            check.report("reopening refreshes immediately", Players.position > before + 1, String(Players.position - before));
            driver.send({ action: "update", properties: { PlaybackStatus: "Paused", Position: 42000000 } }, () => {
                root.until("paused position updates immediately", () => Players.position === 42, () => {
                    driver.after(200, () => {
                        check.near("paused timeline stays still", Players.position, 42);
                        root.watching = false;
                        driver.send({ action: "remove" }, () => {
                            root.until("player removal clears card", () => !Players.hasPlayer, () => check.done());
                        });
                    });
                });
            });
        });
    }
    Component.onCompleted: {
        if (!driver.isolated) {
            check.report("private bus required", false, "run tools/test.sh");
            check.done(); return;
        }
        wait.until(driver.readyChanged, () => driver.ready, ok => {
            check.equal("MPRIS fixture ready", ok, true);
            if (ok) root.begin(); else check.done();
        });
    }
}
