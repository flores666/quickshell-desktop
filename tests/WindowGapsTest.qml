pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/services"
import "root:/modules/bar"

// Real layer reservation and tiled geometry, only on a private headless output.
Item {
    id: root
    readonly property ShellScreen testScreen: Quickshell.screens.find(screen => screen.name === "GAP-1") ?? null
    readonly property bool isolated: Quickshell.env("TEST_BIN") !== ""
        && Quickshell.env("TEST_NOTIFICATION_BUS") === "private"
        && root.testScreen !== null
    Check { id: check }
    Command { id: sh }
    Until { id: ready }
    Settle { id: settled; busy: CompositorOptions.pushing }

    Loader {
        active: root.isolated
        sourceComponent: Bar { modelData: root.testScreen }
    }
    FloatingWindow {
        visible: root.isolated
        screen: root.testScreen
        title: "shell-window-gaps-test"
        implicitWidth: 400
        implicitHeight: 300
    }

    readonly property string snapshot: `python3 - <<'PY'
import json, subprocess
def read(*args):
    return json.loads(subprocess.check_output(["hyprctl", "-j", *args], text=True))
m = next(m for m in read("monitors") if m["name"] == "GAP-1")
w = next((c for c in read("clients") if c["title"] == "shell-window-gaps-test"), None)
print(json.dumps({"monitor": m, "window": w, "gap": read("getoption", "general:gaps_out")["css"]}))
PY`

    function matches(text: string, gap: int, margin: int): bool {
        const s = JSON.parse(text);
        return s.window !== null && s.gap === `0 ${margin} ${margin} ${margin}`
            && s.monitor.reserved[1] === Appearance.m.barHeight + 2 * gap
            && s.window.at[1] === s.monitor.y + s.monitor.reserved[1];
    }

    function geometry(label: string, gap: int, margin: int, then: var): void {
        settled.until(root.snapshot, [], text => root.matches(text, gap, margin), text => {
            const s = JSON.parse(text);
            check.equal(label + ": compositor owns no extra top gap", s.gap, `0 ${margin} ${margin} ${margin}`);
            check.equal(label + ": panel reserves both clearances", s.monitor.reserved[1], Appearance.m.barHeight + 2 * gap);
            if (s.window !== null) {
                const m = s.monitor, w = s.window;
                check.equal(label + ": above and below panel agree", w.at[1] - m.y - Appearance.m.barHeight - gap, gap);
                check.equal(label + ": left margin", w.at[0] - m.x, margin);
                check.equal(label + ": right margin", m.x + m.width / m.scale - w.at[0] - w.size[0], margin);
                check.equal(label + ": bottom margin", m.y + m.height / m.scale - w.at[1] - w.size[1], margin);
            } else {
                check.report(label + ": test window mapped", false, text);
            }
            then();
        });
    }

    function start(): void {
        Settings.setOverride("barHeight", 30);
        Settings.setOverride("barGap", 7);
        Settings.setOverride("hyprGapsOut", 11);
        root.geometry("initial", 7, 11, () => {
            Settings.setOverride("barGap", 0);
            root.geometry("zero panel gap", 0, 11, () => {
                Settings.setOverride("barGap", 12);
                root.geometry("changed panel gap", 12, 11, () => {
                    Settings.setOverride("hyprGapsOut", 19);
                    root.geometry("changed outer gap", 12, 19, () => {
                        Settings.setOverride("barHeight", 36);
                        root.geometry("changed panel height", 12, 19, root.reset);
                    });
                });
            });
        });
    }

    function reset(): void {
        Settings.setOverride("hyprGapsOut", -1);
        root.geometry("reset outer gap", 12, 6, () => {
            // Probe an already-shaped live value, as a shell restart does.
            const before = CompositorOptions.configured;
            CompositorOptions.refresh();
            ready.until(CompositorOptions.configuredChanged, () => CompositorOptions.configured !== before, ok => {
                check.equal("fresh option probe completed", ok, true);
                root.geometry("re-probed outer gap", 12, 6, () => {
                    check.equal("probe reads a side, not the zero top", CompositorOptions.configured.hyprGapsOut, 6);
                    root.reload();
                });
            });
        });
    }

    function reload(): void {
        Settings.setOverride("hyprGapsOut", 19);
        root.geometry("before reload", 12, 19, () => {
            const before = CompositorOptions.configured;
            sh.run("hyprctl reload", [], () => {
                ready.until(CompositorOptions.configuredChanged, () => CompositorOptions.configured !== before, ok => {
                    check.equal("config reload was re-probed", ok, true);
                    root.geometry("config reload", 12, 19, () => {
                        sh.run("hyprctl configerrors", [], text => {
                            check.equal("Lua gap assignments have no config errors", text.trim(), "");
                            check.done();
                        });
                    });
                });
            });
        });
    }

    Component.onCompleted: {
        if (!root.isolated) {
            check.report("isolated headless compositor required", false, "run with tools/test.sh on GAP-1");
            check.done();
            return;
        }
        ready.until(CompositorOptions.configuredChanged,
            () => Settings.ready && CompositorOptions.known("hyprGapsOut"), ok => {
                check.equal("configured outer gap available", ok, true);
                if (ok) root.start(); else check.done();
            });
    }
}
