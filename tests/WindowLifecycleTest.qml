pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/services"
import "root:/modules/common"

Item {
    Check { id: check }
    Command { id: sh }
    Until { id: ready }
    CompositorTheme {}

    Component.onCompleted: ready.until(CompositorOptions.pushingChanged,
        () => Settings.ready && Object.keys(CompositorOptions.appliedDerived).length > 0 && !CompositorOptions.pushing,
        ok => {
            if (!ok || Quickshell.env("TEST_BIN") === "") {
                check.report("isolated theme ready", false, "run tools/test.sh in nested Hyprland");
                check.done(); return;
            }
            sh.run('python3 "$1"', [Qt.resolvedUrl("WindowLifecycleFixture.py").toString().replace("file://", "")], text => {
                try {
                    const results = JSON.parse(text);
                    results.forEach(r => check.report(r.name, r.ok, r.detail ?? ""));
                    check.report("lifecycle checks ran", results.length >= 15, text);
                } catch (error) {
                    check.report("lifecycle fixture completed", false, String(error) + " " + text);
                }
                check.done();
            });
        })
}
