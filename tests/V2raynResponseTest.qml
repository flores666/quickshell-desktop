pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
    id: root
    property var service: null
    readonly property string directory: Quickshell.env("TEST_BIN")
    Check { id: check }
    Command { id: sh }
    FileWait { id: requested }
    Until { id: ended }

    function request(n: int, then: var): void {
        requested.until(root.directory + "/requested-" + n, text => text !== "", text => {
            check.report("request " + n + " starts", text !== "", "no curl request");
            then(text);
        });
    }

    function answer(n: int, mode: string, then: var): void {
        sh.run('printf %s "$2" > "$1"',
            [root.directory + "/response-" + n, JSON.stringify({ mode })], then);
    }

    function disabled(): void {
        root.service.coreApi = "http://old";
        root.service.tun = true;
        root.request(1, () => {
            root.service.readMode(); // A queued read must not use an empty endpoint.
            root.service.tun = false;
            root.answer(1, "Direct", () => {
                ended.until(root.service.modeProbe.runningChanged, () => !root.service.modeProbe.running, ok => {
                    check.equal("disabled request finishes", ok, true);
                    check.equal("disabled endpoint rejects a stale response", root.service.mode, "");
                    check.equal("disabled TUN has no switch", root.service.canSwitch, false);
                    root.replaced();
                });
            });
        });
    }

    function replaced(): void {
        root.service.tun = true;
        root.request(2, () => {
            root.service.coreApi = "http://current";
            root.answer(2, "Direct", () => root.request(3, url => {
                check.equal("follow-up uses the new endpoint", url, "http://current/configs");
                check.equal("old endpoint cannot publish its mode", root.service.mode, "");
                root.answer(3, "Rule", () => ended.until(root.service.modeChanged,
                    () => root.service.mode === "Rule", ok => {
                        check.equal("current response is accepted", ok && root.service.canSwitch, true);
                        root.reused();
                    }));
            }));
        });
    }

    function reused(): void {
        root.service.readMode();
        root.request(4, () => {
            root.service.tun = false;
            root.service.tun = true;
            root.answer(4, "Direct", () => root.request(5, () => {
                check.equal("same endpoint, old generation rejected", root.service.mode, "");
                root.answer(5, "Rule", () => ended.until(root.service.modeProbe.runningChanged,
                    () => !root.service.modeProbe.running, ok => {
                        check.equal("fresh generation succeeds", ok && root.service.mode === "Rule", true);
                        root.service.destroy();
                        check.done();
                    }));
            }));
        });
    }

    Component.onCompleted: {
        if (root.directory === "") {
            check.report("private fixtures required", false, "run tools/test.sh");
            check.done(); return;
        }
        sh.run('python3 "$1" v2rayn',
            [Qt.resolvedUrl("ServiceFixtures.py").toString().replace("file://", "")], url => {
                const component = Qt.createComponent(url.trim());
                check.equal("v2rayN fixture loads", component.errorString(), "");
                root.service = component.createObject(root);
                if (root.service) root.disabled(); else check.done();
            });
    }
}
