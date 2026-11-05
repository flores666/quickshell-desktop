pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris as MprisApi
import "root:/services"

/*! Loading Players after discovery already failed must also recover the
    hidden native player, without requiring another property event. */
Item {
    id: root
    Check { id: check }
    Until { id: wait; bound: 2500 }
    MprisDriver { id: driver }
    readonly property var model: MprisApi.Mpris.players

    function start(): void {
        driver.send({ action: "add", exported: false }, () => {
            wait.until(driver.missingChanged, () => driver.missing >= 2, ok => {
                check.equal("native discovery fails before Players loads", ok, true);
                if (!ok) { check.done(); return; }
                driver.send({ action: "export" }, () => driver.send({ action: "update", properties: {
                    PlaybackStatus: "Playing", Metadata: { "xesam:title": "Already playing YouTube", "mpris:length": 90000000 }
                } }, () => driver.after(80, () => {
                    check.equal("native model still lacks the player", root.model.values.length, 0);
                    // First use of the lazy singleton happens here.
                    wait.until(Players.titleChanged, () => Players.title === "Already playing YouTube" && Players.active,
                        recovered => Qt.callLater(() => {
                            check.equal("attaching to an earlier failure recovers playback", recovered, true);
                            check.equal("native model contains the recovered player", root.model.values.length, 1);
                            check.equal("recovered controls reflect the player", Players.canPlay, true);
                            check.done();
                        }));
                })));
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
            if (ok) root.start(); else check.done();
        });
    }
}
