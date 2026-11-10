pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "root:/services"
import "root:/modules/common"

Item {
    id: root
    property string scenario: "ordinary"
    Check { id: check }
    Command { id: sh }
    Until { id: ready }
    CompositorTheme {}

    Component.onCompleted: ready.until(CompositorOptions.pushingChanged,
        () => Settings.ready && !CompositorOptions.pushing && Object.keys(CompositorOptions.appliedDerived).length > 0,
        ok => {
            if (!ok || Quickshell.env("TEST_BIN") === "") {
                check.report("runner and compositor theme ready", false, "run in the isolated ELASTIC-1 compositor");
                check.done(); return;
            }
            sh.run('python3 "$1" "$2"', [Qt.resolvedUrl("WindowElasticFixture.py").toString().replace("file://", ""), root.scenario], text => {
                try {
                    const results = JSON.parse(text);
                    results.forEach(r => check.report(r.name, r.ok, r.detail));
                    check.report("rendered drag checks ran", results.length >= 8, text);
                } catch (error) { check.report("fixture returned results", false, String(error) + " " + text); }
                check.done();
            });
        })
}
