pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import "root:/components"
import "root:/config"
import "root:/services"
import "root:/modules/panels"

/*! Track replacement and seeks animate presentation, while dispatch keeps the
    actual value. Artwork survives replacement and panel closure. */
Item {
    id: root
    Check { id: check }
    Until { id: wait }
    TestEvent { id: input }
    TestResult { id: pixels }
    MprisDriver { id: driver }
    property var coverImage: null
    readonly property MediaTimeline seek: driver.find(card, item => item instanceof MediaTimeline)[0]
    readonly property MediaArtwork art: driver.find(card, item => item instanceof MediaArtwork)[0]
    readonly property var timeLabel: driver.find(card, item => item instanceof Label && item.role === Label.Role.Caption)[0]
    readonly property var observed: [Players.title, Players.position, Players.canSeek, driver.calls,
        root.seek?.value, root.seek?.displayed, root.seek?.animating, root.seek?.holding,
        root.art?.current, root.art?.current.status, root.art?.blend, root.art?.pending.source]

    FrameAnimation {
        id: presented
        property int frames: 0
        // Allow the window's first polish to lay out the Clickable MouseArea.
        onTriggered: {
            if (++presented.frames < 2) return;
            presented.running = false;
            root.timeline();
        }
    }

    PanelWindow {
        implicitWidth: Appearance.m.mediaWidth
        implicitHeight: card.implicitHeight
        visible: Players.active
        exclusiveZone: 0
        WlrLayershell.namespace: "shell-media-transitions-test"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        MediaCard { id: card; width: parent.width; tracking: true }
    }

    function until(name: string, done: var, then: var): void {
        wait.until(root.observedChanged, done, ok => Qt.callLater(() => {
            check.equal(name, ok, true);
            if (ok) then(); else check.done();
        }));
    }
    function settled(source: string): bool {
        return root.art.current.source.toString() === source && root.art.blend === 1
            && (source === "" || root.art.current.status === Image.Ready);
    }
    function metadata(title: string, cover: string, seconds: real): var {
        return { "mpris:trackid": "/fixture/track", "xesam:title": title,
            "mpris:artUrl": cover, "mpris:length": seconds * 1000000 };
    }
    function begin(): void {
        driver.send({ action: "add" }, () => driver.send({ action: "update", properties: {
            Metadata: root.metadata("Transitions", driver.cover, 180)
        } }, () => root.until("initial player settles", () => Players.canSeek && root.settled(driver.cover)
            && root.seek.displayed === root.seek.clamped, () => presented.running = true)));
    }
    function timeline(): void {
        driver.send({ action: "seek", position: 90000000 }, () => {
            root.until("same-track seek animates", () => root.seek.value === 0.5 && root.seek.animating
                && root.seek.displayed > 1 / 6 && root.seek.displayed < 0.5, () => {
                check.near("time label uses the reported position", card.shownValue, 0.5);
                // TestEvent sends whole pixels, even when the track's width
                // does not divide into thirds. Assert the point actually sent.
                const x = Math.round(root.seek.knobSize / 2 + root.seek.spanX * 2 / 3);
                const target = (x - root.seek.knobSize / 2) / root.seek.spanX;
                const seconds = target * Players.length;
                const before = root.seek.displayed;
                check.equal("pointer press accepted", input.mousePress(root.seek, x, root.seek.height / 2,
                    Qt.LeftButton, Qt.NoModifier, -1), true);
                check.near("pointer target updates immediately", root.seek.value, target);
                check.within("pointer retarget does not jump", root.seek.displayed, before, 0.1);
                input.mouseRelease(root.seek, x, root.seek.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
                root.until("pointer seek reaches the player", () => Math.abs(Players.position - seconds) < 0.001
                    && driver.calls.length === 1, () => {
                    // Quickshell's position setter has millisecond precision.
                    check.within("seek sends the requested position", driver.calls[0][3], seconds * 1000000, 1000);
                    root.until("pointer seek animation settles", () => !root.seek.animating
                        && Math.abs(root.seek.displayed - target) < 0.001, () => root.keyboard());
                });
            });
        });
    }
    function keyboard(): void {
        driver.send({ action: "seek", position: 90000000 }, () => {
            root.until("keyboard adjustment begins during motion", () => root.seek.value === 0.5
                && root.seek.animating && root.seek.displayed > 0.5 && root.seek.displayed < 2 / 3, () => {
                const before = root.seek.displayed;
                input.keyClick(Qt.Key_Right, Qt.NoModifier, -1);
                check.near("keyboard step uses the actual value", root.seek.value, 0.5 + root.seek.stepSize);
                check.within("keyboard retarget does not jump", root.seek.displayed, before, 0.1);
                root.until("keyboard seek reaches the player", () => Math.abs(Players.position - 99) < 0.001
                    && driver.calls.length === 2,
                    () => root.until("keyboard seek animation settles", () => !root.seek.animating
                        && Math.abs(root.seek.displayed - 0.55) < 0.001, () => root.sameTrackArtwork()));
            });
        });
    }
    function sameTrackArtwork(): void {
        driver.send({ action: "update", properties: {
            Metadata: root.metadata("Transitions", driver.otherCover, 180)
        } }, () => root.until("same-track artwork replacement loads", () => root.settled(driver.otherCover), () => {
            check.equal("same-track artwork does not fade", root.art.blend, 1);
            check.equal("metadata refresh does not animate the timeline", root.seek.animating, false);
            root.changeTrack();
        }));
    }
    function changeTrack(): void {
        driver.send({ action: "update", properties: {
            Metadata: root.metadata("Second", driver.cover, 240), Position: 0
        } }, () => root.until("pending track holds the previous timeline", () => root.seek.holding, () => {
            check.near("early position reset does not jump the old track", root.seek.displayed, 0.55);
            check.equal("pending track keeps the old elapsed time", root.timeLabel.text, "1:39 / 3:00");
            root.until("new track animates timeline and cover", () => Players.title === "Second"
                && root.seek.animating && root.seek.displayed > 0 && root.seek.displayed < 0.55
                && root.art.blend > 0 && root.art.blend < 1, () => {
                check.equal("outgoing cover stays opaque", root.art.pending.opacity, 1);
                check.equal("incoming cover is drawn above outgoing", root.art.current.z > root.art.pending.z, true);
                const x = root.seek.knobSize / 2 + root.seek.spanX / 2;
                const before = root.seek.displayed;
                input.mousePress(root.seek, x, root.seek.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
                check.within("seeking during track animation keeps visual continuity", root.seek.displayed, before, 0.1);
                check.near("seeking during track animation uses the actual target", root.seek.value, 0.5);
                input.mouseRelease(root.seek, x, root.seek.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
                root.until("interrupted track transition seeks the new track", () => driver.calls.length === 3
                    && Players.position === 120, () => {
                    check.equal("interrupted transition dispatches the actual seek", driver.calls[2][3], 120000000);
                    root.until("track transition and seek settle", () => root.settled(driver.cover)
                        && !root.seek.animating && root.seek.displayed === 0.5, () => root.hideTimeline());
                });
            });
        }));
    }
    function hideTimeline(): void {
        driver.send({ action: "update", properties: {
            Metadata: root.metadata("Third", driver.cover, 240), Position: 60000000
        } }, () => {
            root.until("another track change animates", () => root.seek.animating
                && root.seek.displayed > 0.25 && root.seek.displayed < 0.5, () => {
                card.tracking = false;
                Qt.callLater(() => {
                    check.near("hiding completes timeline motion", root.seek.displayed, 0.25);
                    driver.send({ action: "seek", position: 120000000 }, () => {
                        root.until("hidden report arrives", () => root.seek.value === 0.5, () => {
                            check.near("hidden timeline takes reports immediately", root.seek.displayed, 0.5);
                            card.tracking = true;
                            root.artwork();
                        });
                    });
                });
            });
        });
    }
    function artwork(): void {
        // Exercise the card's real artwork component at its source boundary.
        root.art.trackKey = "art-1";
        root.art.source = driver.otherCover;
        check.equal("old decoded cover stays while loading", root.art.current.source.toString(), driver.cover);
        root.until("cover fades through intermediate opacity", () => root.art.current.source.toString() === driver.otherCover
            && root.art.current.status === Image.Ready && root.art.blend > 0.35 && root.art.blend < 0.65, () => {
            root.coverImage = pixels.grabImage(root.art);
            // The fixture's two colours both have green 128: their blend must
            // keep it, rather than dimming the background through the images.
            check.within("cover keeps its brightness halfway through the fade",
                root.coverImage.green(root.art.width / 2, root.art.height / 2), 128, 2);
            check.equal("outgoing cover retained during fade", root.art.pending.source.toString(), driver.cover);
            const outgoing = root.art.pending;
            root.art.trackKey = "art-2";
            root.art.source = driver.cover;
            root.art.trackKey = "art-3";
            root.art.source = "";
            root.art.trackKey = "art-4";
            root.art.source = driver.cover;
            check.equal("rapid requests leave the outgoing slot intact", outgoing.source.toString(), driver.cover);
            root.until("latest rapid cover request wins", () => root.settled(driver.cover), () => {
                check.equal("outgoing image released after fade", root.art.pending.source.toString(), "");
                root.clearArtwork();
            });
        });
    }
    function clearArtwork(): void {
        root.art.trackKey = "art-5";
        root.art.source = "";
        root.until("missing artwork fades to the fallback", () => root.art.current.status === Image.Null
            && root.art.blend > 0 && root.art.blend < 1, () => {
            check.equal("cover retained through fallback fade", root.art.pending.status, Image.Ready);
            root.until("fallback settles", () => root.settled(""), () => root.hideArtwork());
        });
    }
    function hideArtwork(): void {
        root.art.trackKey = "art-6";
        root.art.source = driver.otherCover;
        root.until("new cover begins fading", () => root.art.current.status === Image.Ready
            && root.art.blend > 0 && root.art.blend < 1, () => {
            root.art.trackKey = "art-7";
            root.art.source = driver.cover;
            card.tracking = false;
            root.until("hiding applies the queued cover", () => root.settled(driver.cover), () => {
                check.equal("hiding releases outgoing artwork", root.art.pending.source.toString(), "");
                root.art.source = driver.otherCover;
                root.until("hidden artwork loads without a fade", () => root.settled(driver.otherCover), () => {
                    card.tracking = true;
                    check.near("reopening retains the current cover", root.art.blend, 1);
                    driver.send({ action: "remove" }, () => check.done());
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
