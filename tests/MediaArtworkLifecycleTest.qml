pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/modules/panels"

/*! Exercise real asynchronous image reads, including an obsolete HTTP reply
    and a failed URL made available before a later track reuses it. */
Item {
    id: root
    Check { id: check }
    Until { id: wait }
    MprisDriver { id: driver }
    readonly property var observed: [art.current.status, art.current.source, art.pending.source,
        art.blend, art.shownKey, driver.artRequests, driver.artFinished]
    readonly property string recovery: driver.cover.replace("cover.png", "recovered.png")

    PanelWindow {
        implicitWidth: Appearance.m.mediaArt
        implicitHeight: Appearance.m.mediaArt
        exclusiveZone: 0
        WlrLayershell.namespace: "shell-media-artwork-test"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        MediaArtwork { id: art; anchors.fill: parent; animate: true; trackKey: "first" }
    }
    function until(name: string, done: var, then: var): void {
        wait.until(root.observedChanged, done, ok => Qt.callLater(() => {
            check.equal(name, ok, true);
            if (ok) then(); else check.done();
        }));
    }
    function begin(): void {
        art.source = driver.cover;
        root.until("initial artwork decodes", () => art.current.status === Image.Ready, () => {
            art.trackKey = "pending";
            art.source = driver.deferredCover;
            root.until("replacement HTTP request reaches the backend", () => driver.artRequests === 1, () => {
                check.equal("old image retained during a slow load", art.current.source.toString(), driver.cover);
                art.trackKey = "return";
                art.source = driver.cover;
                root.until("returning to the displayed image cancels the pending slot",
                    () => art.pending.source.toString() === "" && art.shownKey === "return", () => {
                    driver.send({ action: "release-art", id: 1 }, () => {
                        root.until("obsolete HTTP reply completes", () => driver.artFinished === 1, () => {
                            check.equal("late reply cannot replace the current image", art.current.source.toString(), driver.cover);
                            check.equal("obsolete image is not retained", art.pending.source.toString(), "");
                            root.failure();
                        });
                    });
                });
            });
        });
    }
    function failure(): void {
        // This deliberately missing fixture produces one expected Image warning.
        art.trackKey = "failure";
        art.source = root.recovery;
        root.until("failed image reaches the fallback", () => art.current.status === Image.Error && art.blend === 1, () => {
            driver.send({ action: "cover", file: "recovered.png" }, () => {
                check.equal("same track does not retry on a clock", art.current.status, Image.Error);
                art.trackKey = "recovery";
                root.until("later track retries the same failed URL", () => art.current.status === Image.Ready
                    && art.current.source.toString() === root.recovery && art.blend === 1, () => {
                    check.equal("recovered image releases the failed slot", art.pending.source.toString(), "");
                    check.done();
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
            if (ok) root.begin(); else check.done();
        });
    }
}
