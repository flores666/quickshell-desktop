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
        const names = ["minimize_duration", "move_duration", "close_duration", "move_curve"];
        const expected = [Appearance.t["windowMinimize"], Appearance.t["windowMove"],
            Appearance.t["windowClose"], Appearance.t["windowCurve"]?.join(" ")];
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
                const open = leaves.find(a => a.name === "windowsIn");
                const fadeIn = leaves.find(a => a.name === "fadeIn");
                check.near("window geometry uses the motion token", move.speed * 100, expected[1]);
                check.near("close geometry uses the close token", close.speed * 100, expected[2]);
                check.near("close fade and geometry finish together", fade.speed, close.speed);
                check.equal("fallback close keeps its full geometry", close.style, "popin 100%");
                check.equal("fallback launch keeps its full geometry", open.style, "popin 100%");
                check.near("launch fade uses the shell fade timing", fadeIn.speed * 100, Appearance.t.fast);
                check.equal("launch fade uses the shell curve", fadeIn.bezier, fade.bezier);
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
