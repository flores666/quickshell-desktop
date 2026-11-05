pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/components"
import "root:/services"
import "root:/modules/panels/qs"

Item {
    id: root
    readonly property string directory: Quickshell.env("TEST_BIN")
    Check { id: check }
    Command { id: sh }
    FileWait { id: file }
    Until { id: wait }
    Loader {
        id: control
        active: false
        width: 336
        sourceComponent: Component { NightLightControl {} }
    }

    function find(item: var, type: var): var {
        if (item instanceof type) return item;
        for (const child of item.children ?? []) {
            const found = root.find(child, type);
            if (found) return found;
        }
        return null;
    }

    function request(n: int, expected: string, then: var): void {
        file.until(root.directory + "/request-" + n, text => text !== "", text => {
            check.equal("request " + n, text, expected);
            then();
        });
    }

    function answer(n: int, reply: string, then: var): void {
        sh.run('printf %s "$2" > "$1"', [root.directory + "/reply-" + n, reply], then);
    }

    function backend(message: string, then: var): void {
        sh.run('printf "%s\\n" "$2" > "$1"', [root.directory + "/backend-control", message], then);
    }

    Component.onCompleted: {
        if (root.directory === "") {
            check.report("private fixtures required", false, "run tools/test.sh");
            check.done(); return;
        }
        sh.run('python3 "$1" nightlight',
            [Qt.resolvedUrl("ServiceFixtures.py").toString().replace("file://", "")], () =>
                wait.until(Settings.readyChanged, () => Settings.ready, ok => {
                    check.equal("preferences load", ok, true);
                    root.start();
                }));
    }

    function start(): void {
        check.equal("Night Light starts off", Settings.nightLightEnabled, false);
        check.equal("gentle default temperature", Settings.nightLightTemperature, 4500);
        Settings.setNightLightTemperature(99999);
        check.equal("external preference clamps to daylight", NightLight.temperature, 6500);
        Settings.setNightLightTemperature(0);
        check.equal("external preference clamps to warm limit", NightLight.temperature, 2500);
        Settings.setNightLightTemperature(4472);
        check.equal("temperature follows 100 K steps", NightLight.temperature, 4500);
        Settings.setNightLightTemperature(4500);
        Settings.setNightLightEnabled(true);
        control.active = true;
        file.until(root.directory + "/started-1", text => text !== "", text => {
            check.equal("backend has no independent schedule", text,
                "--identity --verbose\n" + Quickshell.shellPath(""));
            check.equal("startup waits on socket readiness", NightLight.available, false);
            check.equal("unready control stays in place", control.item !== null, true);
            check.equal("unready toggle is disabled", root.find(control.item, ToggleSwitch).enabled, false);
            root.backend("ready", () => root.request(1, "temperature 4500", root.drag));
        });
    }

    function drag(): void {
        check.equal("ready backend enables the control", NightLight.available, true);
        const slider = root.find(control.item, Slider);
        slider.moved(0.25);
        slider.moved(0.5);
        slider.moved(0.75);
        check.equal("warmer to the right", NightLight.temperature, 3500);
        check.near("slider keeps the latest position", slider.value, 0.75);
        root.answer(1, "ok", () => root.request(2, "temperature 3500", () => {
            root.find(control.item, ToggleSwitch).toggled(false);
            check.equal("switch disables Night Light", Settings.nightLightEnabled, false);
            check.equal("off retains preferred temperature", NightLight.temperature, 3500);
            check.equal("off disables warmth adjustment", slider.enabled, false);
            root.answer(2, "ok", () => root.request(3, "identity", () => {
                root.answer(3, "ok", () => wait.until(NightLight.appliedChanged,
                    () => NightLight.applied === "identity", ok => {
                        check.equal("off restores the identity matrix", ok, true);
                        root.enable();
                    }));
            }));
        }));
    }

    function enable(): void {
        root.find(control.item, ToggleSwitch).toggled(true);
        root.request(4, "temperature 3500", () => {
            const slider = root.find(control.item, Slider);
            slider.moved(1);
            check.equal("right endpoint is warmest", NightLight.temperature, 2500);
            root.answer(4, "ok", () => root.request(5, "temperature 2500", () => {
                root.answer(5, "ok", () => wait.until(NightLight.appliedChanged,
                    () => NightLight.applied === "temperature 2500", ok => {
                        check.equal("latest drag is applied", ok, true);
                        root.replace();
                    }));
            }));
        });
    }

    function replace(): void {
        NightLight.setWarmth(0.5);
        root.request(6, "temperature 4500", () => {
            root.backend("exit", () => wait.until(NightLight.failureChanged,
                () => NightLight.failure !== "", ok => {
                    check.equal("backend exit is observable", ok, true);
                    check.equal("lost backend disables control", NightLight.available, false);
                    check.equal("lost backend preserves intent", NightLight.enabled, true);
                    check.equal("lost backend clears applied state", NightLight.applied, "");
                    Qt.callLater(root.retry);
                }));
        });
    }

    function retry(): void {
        NightLight.refresh();
        file.until(root.directory + "/started-2", text => text !== "", () => {
            root.backend("ready", () => wait.until(NightLight.availableChanged,
                () => NightLight.available, ok => {
                    check.equal("opening again retries the backend", ok, true);
                    root.answer(6, "ok", () => root.request(7, "temperature 4500", () => {
                        check.equal("old generation cannot publish applied state", NightLight.applied, "");
                        root.answer(7, "invalid command", () => wait.until(NightLight.failureChanged,
                            () => NightLight.failure !== "", ok => {
                                check.equal("failed reply is not a successful apply", ok, true);
                                check.equal("failure disables the slider", root.find(control.item, Slider).enabled, false);
                                Qt.callLater(root.persist);
                            }));
                    }));
                }));
        });
    }

    function persist(): void {
        file.until(Quickshell.statePath("settings.json"), text => {
            try {
                const state = JSON.parse(text);
                return state.nightLightEnabled === true && state.nightLightTemperature === 4500;
            } catch (_) { return false; }
        }, text => {
            const state = JSON.parse(text || "{}");
            check.equal("enabled preference is saved", state.nightLightEnabled, true);
            check.equal("warmth preference is saved", state.nightLightTemperature, 4500);
            // Keep PATH isolated even on a machine with the real backend.
            sh.run('read -r pid < "$1"; waitpid "$pid"; mv -- "$2/hyprsunset-unavailable" "$2/hyprsunset"',
                [root.directory + "/daemon-pid-2", root.directory], () => {
                    NightLight.refresh();
                    wait.until(NightLight.failureChanged, () => NightLight.failure.includes("Install hyprsunset"), ok => {
                        check.equal("missing package degrades without pretending", ok && !NightLight.available, true);
                        check.equal("unavailable control keeps its place", control.item !== null, true);
                        check.done();
                    });
                });
        });
    }
}
