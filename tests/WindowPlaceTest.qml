import QtQuick

/*!
    Un-maximized or out of fullscreen, a window floated from a tile comes back
    where Placement put it, not where Hyprland would have
    (docs/specs/window-modes.md, item 3). In a nested Hyprland with the
    branch's plugin only.
*/
Item {
    Check {
        id: check
    }

    WindowDriver {
        id: window
    }

    function box(name: string, actual: var, expected: var): void {
        check.equal(name, JSON.stringify(actual), JSON.stringify(expected));
    }

    Component.onCompleted: window.open(() => {
        window.act(["layout", "layout"], placed => {
            check.equal("floated from a tile", placed.floating, true);
            window.act(["zoom", "zoom"], s => {
                box("maximized and back: where it was placed", s.box, placed.box);
                window.act(["reset", "full", "full"], s => {
                    box("fullscreen and back: where it was placed", s.box, placed.box);
                    window.close(() => check.done());
                });
            });
        });
    })
}
