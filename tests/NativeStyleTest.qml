pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"
import "root:/modules/common"

// The bridge must move reserved space with the bar's drawn/hit geometry,
// including a live change while a window is maximized.
Item {
    id: root
    property var defaults: ({})
    Check { id: check }
    Command { id: sh }
    Until { id: ready }
    Settle { id: pushed; busy: CompositorOptions.pushing }
    CompositorTheme {}
    WindowDriver { id: window }

    function style(height: int, then: var): void {
        CompositorOptions.derived = Object.assign({}, root.defaults, { "plugin:windows:height": String(height) });
        pushed.until("hyprctl -j getoption plugin:windows:height", [], text => JSON.parse(text).int === height, text => {
            check.equal("native height reaches " + height, JSON.parse(text).int, height);
            // The animation settling has no completion event on the socket.
            window.run("sleep 0.5; hyprctl clients -j", clients => then(window.state(clients)));
        });
    }

    function start(): void {
        root.defaults = Object.assign({}, CompositorOptions.derived);
        const options = ["height", "button_size", "button_gap", "button_inset", "reveal_edge", "font_size", "font_weight", "font_family", "width_cap", "height_cap"];
        const expected = [Appearance.m.titleBarHeight, Appearance.m.titleBarButton, Appearance.m.titleBarGap,
            Appearance.m.titleBarInset, Appearance.m.titleBarEdge, Appearance.font.titleBarPointSize,
            Appearance.font.titleBarWeight, Appearance.font.titleBarFamily, Appearance.m.windowWidthCap, Appearance.m.windowHeightCap];
        sh.run('hyprctl -j --batch "$1"', [options.map(k => "getoption plugin:windows:" + k).join(" ; ")], text => {
            const replies = JSON.parse("[" + text.replace(/}\s*{/g, "},{") + "]");
            replies.forEach((r, i) => {
                const actual = r.int ?? r.float ?? r.str;
                if (typeof expected[i] === "number") check.near(options[i] + " follows its token", actual, expected[i]);
                else check.equal(options[i] + " follows its token", actual, expected[i]);
            });
            window.open(() => window.act(["zoom"], before => {
                root.style(Appearance.m.titleBarHeight + 12, after => {
                    check.equal("live height moves the maximized content down", after.box[1], before.box[1] + 12);
                    check.equal("live height reserves the same extra room", after.box[3], before.box[3] - 12);
                    root.style(Appearance.m.titleBarHeight, restored => {
                        check.equal("restoring style restores the window box", JSON.stringify(restored.box), JSON.stringify(before.box));
                        window.close(() => check.done());
                    });
                });
            }));
        });
    }

    Component.onCompleted: ready.until(CompositorOptions.pushingChanged,
        () => Settings.ready && Object.keys(CompositorOptions.appliedDerived).length > 0 && !CompositorOptions.pushing,
        ok => {
            check.equal("design-system options are pushed", ok, true);
            if (ok) root.start(); else check.done();
        })
}
