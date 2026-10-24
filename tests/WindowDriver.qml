import QtQuick
import Quickshell
import Quickshell.Io

/*!
    A window for the tests to switch between modes: a kitty of a class of its
    own, so Placement remembers nothing for it, driven through hyprctl in the
    Hyprland the test runs under — a nested one with the branch's plugin,
    never the session (docs/specs/window-modes.md). Its cache is the test's:
    kitty remembers its last size and whether it was maximized, and the
    session's kitty opened at the nested screen's size, maximized.

    One command at a time: each `open`, `act` and `close` calls back with the
    window's state once Hyprland has settled it — `{ floating, fs, box }`,
    the box as `[x, y, w, h]` — and the next is started from that callback.
*/
QtObject {
    id: root

    readonly property string appClass: "modes-" + Date.now()
    property string address: ""
    property int workspace: 1
    /*! The monitor's box and its work area, as `[x, y, w, h]`. */
    property var monitor: []
    property var workArea: []

    /*! The bar's buttons and the dock, as Hyprland dispatches. */
    readonly property var actions: ({
        "zoom": ["focuswindow %a", "fullscreen 1"],
        "full": ["focuswindow %a", "fullscreen 0"],
        "layout": ["togglefloating %a"],
        "minimize": ["movetoworkspacesilent special:minimized,%a"],
        "restore": ["movetoworkspacesilent %w,%a", "focuswindow %a", "alterzorder top,%a"],
        "resize": ["resizewindowpixel exact 600 400,%a"],
        "hideBar": ["windows:hidden_for %c"],
        "showBar": ["windows:hidden_for"],
        // Floating and in no fullscreen mode, set rather than toggled: where
        // a sequence starts, whatever the one before it left.
        "reset": ["focuswindow %a", "fullscreenstate 0 0", "setfloating %a"]
    })

    property var pending: null

    readonly property Process process: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const then = root.pending;
                root.pending = null;
                then(this.text);
            }
        }
    }

    function run(script: string, then: var): void {
        root.pending = then;
        root.process.command = ["sh", "-c", script];
        root.process.running = true;
    }

    function state(clients: string): var {
        const c = JSON.parse(clients).find(c => c.class === root.appClass);
        return c ? { floating: c.floating, fs: c.fullscreen, box: [c.at[0], c.at[1], c.size[0], c.size[1]] } : null;
    }

    function open(then: var): void {
        const cache = Quickshell.env("XDG_CACHE_HOME") + "/kitty";
        root.run(`hyprctl dispatch exec 'env KITTY_CACHE_DIRECTORY=${cache} kitty --class ${root.appClass}' >/dev/null
            for i in $(seq 50); do hyprctl clients -j | grep -q '"${root.appClass}"' && break; sleep 0.1; done
            sleep 0.8; hyprctl monitors -j; echo '#'; hyprctl clients -j`, text => {
            const [monitors, clients] = text.split("\n#\n");
            const m = JSON.parse(monitors).find(m => m.focused);
            root.monitor = [m.x, m.y, m.width, m.height];
            const r = m.reserved;
            root.workArea = [m.x + r[0], m.y + r[1], m.width - r[0] - r[2], m.height - r[1] - r[3]];
            const c = JSON.parse(clients).find(c => c.class === root.appClass);
            root.address = c.address;
            root.workspace = c.workspace.id;
            then(root.state(clients));
        });
    }

    /*! Each of `names`, from `actions`, in turn: each one batch, as the bar
        and the dock send it, and settled before the next. */
    function act(names: var, then: var): void {
        let script = "";
        for (const name of names) {
            const batch = root.actions[name].map(d => "dispatch " + d
                .replace(/%a/g, "address:" + root.address)
                .replace(/%w/g, String(root.workspace))
                .replace(/%c/g, root.appClass)).join(" ; ");
            script += `hyprctl --batch '${batch}' >/dev/null; sleep 0.5; `;
        }
        root.run(script + "hyprctl clients -j", text => then(root.state(text)));
    }

    function close(then: var): void {
        root.run(`hyprctl dispatch windows:hidden_for >/dev/null; hyprctl dispatch closewindow address:${root.address} >/dev/null; sleep 0.3; echo`, () => then());
    }

    /*! A maximized floating window's box: the work area less its title bar's
        28 px (CTitleBar::HEIGHT) at the top. */
    function maximized(): var {
        const a = root.workArea;
        return [a[0], a[1] + 28, a[2], a[3] - 28];
    }
}
