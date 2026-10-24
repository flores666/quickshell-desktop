import QtQuick

/*!
    A maximized floating window keeps room for its title bar, however it got
    there and whether the bar is shown; minimized and restored, a maximized or
    fullscreen window comes back as it was (docs/specs/window-modes.md, items
    4 and 6). In a nested Hyprland with the branch's plugin only.
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
        window.act(["full", "zoom"], s => {
            check.equal("fullscreen, then maximized: maximized", s.fs, 1);
            box("fullscreen, then maximized: room for its bar", s.box, window.maximized());
            window.act(["reset", "zoom", "hideBar"], s => {
                box("maximized, its bar hidden: the whole work area", s.box, window.workArea);
                window.act(["showBar"], s => {
                    box("maximized, its bar shown again: room for it", s.box, window.maximized());
                    window.act(["reset", "zoom", "minimize", "restore"], s => {
                        check.equal("maximized, minimized, restored: maximized", s.fs, 1);
                        box("maximized, minimized, restored: room for its bar", s.box, window.maximized());
                        window.act(["reset", "full", "minimize", "restore"], s => {
                            check.equal("fullscreen, minimized, restored: fullscreen", s.fs, 2);
                            box("fullscreen, minimized, restored: the whole monitor", s.box, window.monitor);
                            window.close(() => check.done());
                        });
                    });
                });
            });
        });
    })
}
