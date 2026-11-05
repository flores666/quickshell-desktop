pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/services"
import "root:/modules/common"
import "root:/modules/dock"

// The fixture presses an actual native title-bar button and captures real
// headless frames. Its only timed waits are finite animation/capture settles.
Item {
    Check { id: check }
    Command { id: sh }
    Until { id: ready }
    CompositorTheme {}
    IpcHandler {
        target: "windowAnimation"
        function restore(address: string): void {
            Compositor.focusWindow(Compositor.toplevels.find(w => w.address === address));
        }
        function close(address: string): void {
            Compositor.closeWindow(Compositor.toplevels.find(w => w.address === address));
        }
    }
    Variants {
        model: Quickshell.screens
        DockPanel {}
    }

    function start(): void {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("runner isolation required", false, "run tools/test.sh in nested Hyprland");
            check.done(); return;
        }
        sh.run('python3 "$1"', [Qt.resolvedUrl("WindowAnimationFixture.py").toString().replace("file://", "")], text => {
            try {
                const results = JSON.parse(text);
                results.forEach(result => check.report(result.name, result.ok, result.detail ?? ""));
                check.report("rendered acceptance checks ran", results.length >= 12, text);
            } catch (error) {
                check.report("animation fixture completed", false, String(error) + " " + text);
            }
            check.done();
        });
    }

    Component.onCompleted: ready.until(CompositorOptions.pushingChanged,
        () => Settings.ready && Object.keys(CompositorOptions.appliedDerived).length > 0 && !CompositorOptions.pushing,
        ok => { if (ok) start(); else { check.report("theme ready", false, "timed out"); check.done(); } })
}
