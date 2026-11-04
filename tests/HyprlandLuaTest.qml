pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "root:/services"

/* Run in a nested Hyprland with the desktop's Lua config. Exercise the real
   IPC boundary: 0.57 removed keyword/legacy dispatch and changed bool/gap
   replies. Settings writes are isolated by tools/test.sh. */
Item {
    id: root

    Check { id: check }
    Command { id: sh }
    Until { id: ready }
    Settle { id: pushed; busy: CompositorOptions.pushing }
    property string openedAddress: ""

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "openwindow" && event.data.endsWith(",quickshell-lua-test,Lua IPC test"))
                root.openedAddress = event.data.split(",")[0];
        }
    }

    function readOptions(then: var): void {
        sh.run('hyprctl -j --batch "getoption general:gaps_in ; getoption decoration:blur:enabled"', [], text => {
            const replies = JSON.parse("[" + text.replace(/}\s*{/g, "},{") + "]");
            then(replies);
        });
    }

    function start(): void {
        root.readOptions(before => {
            // The service reads the configured defaults before applying saved
            // overrides, so the live reply may already differ from configured.
            check.equal("gap replies are decoded", CompositorOptions.decode("hyprGapsIn", before[0]), parseInt(before[0].css));
            check.equal("bool replies are decoded", CompositorOptions.decode("hyprBlur", before[1]), before[1].bool ? 1 : 0);
            const code = CompositorOptions.assignment("general:gaps_in", "17") + "; "
                + CompositorOptions.assignment("decoration:blur:enabled", "0") + "; "
                + CompositorOptions.assignment("plugin:absent:value", "5");
            sh.run('hyprctl eval "$1"', [code], reply => {
                check.equal("Lua option writes succeed with an absent plugin", reply.trim(), "ok");
                root.readOptions(after => {
                    check.equal("gap override reaches Hyprland", parseInt(after[0].css), 17);
                    check.equal("boolean override reaches Hyprland", after[1].bool, false);
                    root.strings();
                });
            });
        });
    }

    function strings(): void {
        const value = "quote\" backslash\\\n\u0000\\u0041";
        const code = "local s = " + Compositor.luaString(value)
            + '; assert(#s == 25 and s:byte(6) == 34 and s:byte(17) == 92 and s:byte(18) == 10 and s:byte(19) == 0'
            + ' and s:sub(20) == string.char(92) .. "u0041")';
        sh.run('hyprctl eval "$1"', [code], reply => {
            check.equal("Lua string literals preserve quotes, slashes and control characters", reply.trim(), "ok");
            // Restore the config and verify the service re-reads its new reply
            // types after the compositor's configreloaded event.
            sh.run("hyprctl reload", [], () => {
                const expected = Settings.hyprGapsIn >= 0 ? Settings.hyprGapsIn : 6;
                pushed.until("hyprctl -j getoption general:gaps_in", [],
                    text => parseInt(JSON.parse(text).css) === expected, text => {
                        check.equal("reload restores configured gaps and saved overrides", parseInt(JSON.parse(text).css), expected);
                        root.actions();
                    });
            });
        });
    }

    function actions(): void {
        Compositor.exec(["kitty", "--config", "NONE", "--override", "confirm_os_window_close=0",
            "--class", "quickshell-lua-test", "--title", "Lua IPC test"], "");
        // A title can arrive before the window maps. Wait for openwindow so
        // the compositor can accept the close, not just identify the window.
        ready.until(root.openedAddressChanged,
            () => root.openedAddress !== "", opened => {
                check.report("Lua exec opens a window", opened, "no window-open event");
                if (!opened) { check.done(); return; }
                const window = Compositor.toplevels.find(w => w.address === root.openedAddress);
                Compositor.moveWindowToWorkspace(window, 2);
                ready.until(Hyprland.rawEvent, () => window.workspace?.id === 2, moved => {
                    check.report("Lua move changes the window's workspace", moved, "window did not move");
                    Compositor.focusWindow(window);
                    ready.until(Hyprland.rawEvent,
                        () => Compositor.focusedWorkspace?.id === 2 && Compositor.activeToplevel === window, focused => {
                            check.report("Lua focus activates the window on its workspace", focused, "window did not gain focus");
                            Compositor.closeWindow(window);
                            ready.until(Compositor.toplevelsChanged,
                                () => !Compositor.toplevels.some(w => w.title === "Lua IPC test"), closed => {
                                    check.report("Lua close removes the window", closed, "window remained mapped");
                                    check.done();
                                });
                        });
                });
            });
    }

    Component.onCompleted: ready.until(CompositorOptions.configuredChanged,
        () => Settings.ready && CompositorOptions.configured.hyprGapsIn !== undefined,
        ok => {
            check.report("configured options are available", ok, "option probe did not finish");
            if (ok) root.start(); else check.done();
        })
}
