pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"
import "root:/modules/common"

// Verify effective compositor values, including the standard window leaves;
// accepting a write to an unknown plugin option is not evidence it exists.
Item {
    Check { id: check }
    Command { id: sh }
    Until { id: ready }
    CompositorTheme {}

    function start(): void {
        const names = ["minimize_duration", "move_duration", "close_duration", "close_scale", "move_curve"];
        const expected = [Appearance.t["windowMinimize"], Appearance.t["windowMove"],
            Appearance.t["windowClose"], Appearance.m["windowCloseScale"], Appearance.t["windowCurve"]?.join(" ")];
        sh.run('hyprctl -j --batch "$1"', [names.map(k => "getoption plugin:windows:" + k).join(" ; ")], text => {
            const replies = JSON.parse("[" + text.replace(/no such option/g, "{}").replace(/}\s*{/g, "},{") + "]");
            names.forEach((name, i) => {
                check.report(name + " has a design token", expected[i] !== undefined, "missing token");
                const actual = replies[i]?.int ?? replies[i]?.float ?? replies[i]?.str;
                check.report(name + " is registered by the plugin", actual !== undefined, "option unavailable");
                if (typeof expected[i] === "number") check.near(name + " reaches the native owner", actual, expected[i]);
                else check.equal(name + " reaches the native owner", actual, expected[i]);
            });
            sh.run("hyprctl -j animations", [], output => {
                const leaves = JSON.parse(output)[0];
                const move = leaves.find(a => a.name === "windowsMove");
                const close = leaves.find(a => a.name === "windowsOut");
                const fade = leaves.find(a => a.name === "fadeOut");
                check.near("window geometry uses the motion token", move.speed * 100, expected[1]);
                check.near("close geometry uses the close token", close.speed * 100, expected[2]);
                check.near("close fade and geometry finish together", fade.speed, close.speed);
                check.equal("close uses a small centered shrink", close.style, "popin " + Math.round(expected[3] * 100) + "%");
                check.done();
            });
        });
    }

    Component.onCompleted: ready.until(CompositorOptions.pushingChanged,
        () => Settings.ready && Object.keys(CompositorOptions.appliedDerived).length > 0 && !CompositorOptions.pushing,
        ok => {
            check.equal("theme options have reached Hyprland", ok, true);
            if (ok) start(); else check.done();
        })
}
