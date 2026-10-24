import QtQuick

/*!
    Floating ↔ tiled leaves maximize and fullscreen, and a window floated
    again comes back at the floating size it had (docs/specs/window-modes.md,
    items 1 and 2). In a nested Hyprland with the branch's plugin only.
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

    function mode(name: string, s: var, floating: bool, fs: int): void {
        check.equal(name + ": floating", s.floating, floating);
        check.equal(name + ": fullscreen mode", s.fs, fs);
    }

    Component.onCompleted: window.open(start => {
        const B = start.box;
        mode("opens", start, true, 0);
        window.act(["zoom", "layout"], s => {
            mode("maximized, then tiled", s, false, 0);
            window.act(["layout"], s => {
                mode("then floated", s, true, 0);
                box("then floated: at its floating box", s.box, B);
                window.act(["reset", "zoom", "minimize", "restore", "layout", "layout"], s => {
                    mode("maximized, minimized, restored, tiled, floated", s, true, 0);
                    box("maximized, minimized, restored, tiled, floated: at its floating box", s.box, B);
                    window.act(["reset", "full", "layout"], s => {
                        mode("fullscreen, then tiled", s, false, 0);
                        window.act(["reset", "resize", "layout", "layout"], s => {
                            mode("resized, tiled, floated", s, true, 0);
                            box("resized, tiled, floated: at the size it was left", s.box.slice(2), [600, 400]);
                            window.close(() => check.done());
                        });
                    });
                });
            });
        });
    })
}
