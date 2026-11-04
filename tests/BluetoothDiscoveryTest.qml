pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
    id: root
    Check { id: check }
    Command { id: sh }
    QtObject {
        id: adapter
        property bool enabled: false
        property bool discovering: false
        property int state: 0
        property QtObject devices: QtObject { property var values: [] }
        onEnabledChanged: if (!enabled) adapter.discovering = false
    }
    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("private fixtures required", false, "run tools/test.sh");
            check.done(); return;
        }
        sh.run('python3 "$1" bluetooth',
            [Qt.resolvedUrl("ServiceFixtures.py").toString().replace("file://", "")], url => {
                const component = Qt.createComponent(url.trim());
                check.equal("Bluetooth fixture loads", component.errorString(), "");
                const bt = component.createObject(root);
                if (!bt) { check.done(); return; }
                bt.setDiscovering(true);
                check.equal("absent adapter retains discovery intent", bt.discoveryRequested, true);
                bt.adapter = adapter;
                check.equal("off adapter stays idle", adapter.discovering, false);
                adapter.enabled = true;
                check.equal("enabling on the page starts discovery", adapter.discovering, true);
                adapter.enabled = false;
                adapter.enabled = true;
                check.equal("re-enabling on the page restarts discovery", adapter.discovering, true);
                bt.setDiscovering(false);
                check.equal("leaving the page stops discovery", adapter.discovering, false);
                adapter.enabled = false;
                adapter.enabled = true;
                check.equal("off-page enable does not discover", adapter.discovering, false);
                bt.adapter = null;
                bt.setDiscovering(true);
                bt.adapter = adapter;
                check.equal("adapter appearing honors the open page", adapter.discovering, true);
                bt.setDiscovering(false);
                bt.destroy();
                check.done();
            });
    }
}
