pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"
import "root:/modules/common"

// Read effective values: unknown plugin options can otherwise accept writes
// without ever reaching the renderer. Existing Genie tests guard lifecycle.
Item {
    Check { id: check }
    Command { id: sh }
    Until { id: ready }
    CompositorTheme {}

    function start(): void {
        sh.run('hyprctl -j --batch "getoption plugin:windows:minimize_duration ; getoption plugin:windows:minimize_exposure"', [], text => {
            const values = JSON.parse("[" + text.replace(/no such option/g, "{}").replace(/}\s*{/g, "},{") + "]");
            check.within("Genie is 1.5 times faster than 560 ms", values[0].int * 1.5, 560, 0.75);
            check.equal("effective speed follows its token", values[0].int, Appearance.t.windowMinimize);
            check.report("motion blur has a positive exposure", values[1]?.int > 0, "missing native exposure");
            check.equal("exposure follows its token", values[1]?.int, Appearance.t["windowExposure"]);
            check.done();
        });
    }

    Component.onCompleted: ready.until(CompositorOptions.pushingChanged,
        () => Settings.ready && Object.keys(CompositorOptions.appliedDerived).length > 0 && !CompositorOptions.pushing,
        ok => { if (ok) start(); else { check.report("theme ready", false, "timed out"); check.done(); } })
}
