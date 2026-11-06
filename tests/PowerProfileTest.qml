pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Item {
    id: root
    Check { id: check }
    Command { id: sh }
    Until { id: ready }
    property int backs: 0
    QtObject {
        id: backend
        property int profile: PowerProfile.Balanced
        property bool hasPerformanceProfile: false
    }
    function ownerEvent(power: QtObject, line: string, expected: string, then: var): void {
        sh.run('printf \'%s\\n\' "$1" > "$TEST_BIN/power-events"', [line], () => {
            ready.until(power.profileOwnerChanged, () => power.profileOwner === expected, ok => {
                check.equal("monitor receives " + line, ok, true);
                then();
            });
        });
    }
    function option(page: Item, profile: int): Item {
        return page.children.find(child => child.objectName === "profile:" + profile);
    }
    function observe(power: QtObject, page: Item): void {
        root.ownerEvent(power, "The name net.hadess.PowerProfiles is owned by :1.3", ":1.3", () => {
            check.equal("monitor makes live backend available", power.hasProfiles, true);
            const beforeLoss = root.backs;
            root.ownerEvent(power, "The name net.hadess.PowerProfiles does not have an owner", "", () => {
                check.equal("actual owner loss releases the detail page", root.backs, beforeLoss + 1);
                check.equal("owner loss disables choices immediately", page.enabled, false);
                check.equal("actual owner loss removes availability", power.hasProfiles, false);
                root.ownerEvent(power, "The name net.hadess.PowerProfiles is owned by :1.4", ":1.4", () => {
                    check.equal("monitor restores availability after restart", power.hasProfiles, true);
                    const beforeReplacement = root.backs;
                    root.ownerEvent(power, "The name net.hadess.PowerProfiles is owned by :1.5", ":1.5", () => {
                        check.equal("direct owner replacement releases old choices", root.backs, beforeReplacement + 1);
                        root.ownerEvent(power, "exit", "", () => {
                            check.equal("monitor failure clears stale availability", power.hasProfiles, false);
                            page.destroy(); power.destroy(); check.done();
                        });
                    });
                });
            });
        });
    }
    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("runner isolation", false, "run tools/test.sh");
            check.done(); return;
        }
        sh.run('python3 "$1" power-profile',
            [Qt.resolvedUrl("ServiceFixtures.py").toString().replace("file://", "")], text => {
                const urls = text.trim().split("\n");
                const service = Qt.createComponent(urls[0]);
                check.equal("production Power fixture loads", service.errorString(), "");
                const power = service.createObject(root, { backend });
                power.profileOwner = ":1.1";
                const ui = Qt.createComponent(urls[1]);
                check.equal("production profile page fixture loads", ui.errorString(), "");
                let page = ui.createObject(root, { power });
                if (!power || !page) { check.done(); return; }
                page.backRequested.connect(() => root.backs++);
                const saver = root.option(page, PowerProfile.PowerSaver);
                const balanced = root.option(page, PowerProfile.Balanced);
                let performance = root.option(page, PowerProfile.Performance);
                check.equal("unsupported performance omitted", performance.visible, false);
                check.equal("current balanced choice is selected", balanced.selected, true);
                saver.clicked(null);
                check.equal("explicit saver choice reaches backend", backend.profile, PowerProfile.PowerSaver);
                check.equal("selection follows the backend", saver.selected, true);
                const beforeLoss = root.backs;
                power.profileOwner = "";
                check.equal("backend removal leaves profile page", root.backs, beforeLoss + 1);
                balanced.clicked(null);
                check.equal("stale choice cannot act after removal", backend.profile, PowerProfile.PowerSaver);
                power.profileOwner = ":1.2";
                backend.profile = PowerProfile.Balanced;
                saver.clicked(null);
                check.equal("fading old page cannot act on a replacement backend", backend.profile, PowerProfile.Balanced);
                check.equal("replacement keeps old choices disabled", page.enabled, false);
                page.destroy();
                page = ui.createObject(root, { power });
                page.backRequested.connect(() => root.backs++);
                performance = root.option(page, PowerProfile.Performance);
                backend.hasPerformanceProfile = true;
                check.equal("supported performance offered", performance.visible, true);
                performance.clicked(null);
                check.equal("performance choice reaches backend", backend.profile, PowerProfile.Performance);
                backend.profile = PowerProfile.Balanced;
                backend.hasPerformanceProfile = false;
                check.equal("capability removal hides performance", performance.visible, false);
                performance.clicked(null);
                check.equal("stale performance choice is rejected", backend.profile, PowerProfile.Balanced);
                power.setProfile(999);
                check.equal("invalid profile rejected at owner", backend.profile, PowerProfile.Balanced);
                power.setProfile(PowerProfile.Balanced);
                check.equal("balanced still selectable", backend.profile, PowerProfile.Balanced);
                root.observe(power, page);
            });
    }
}
