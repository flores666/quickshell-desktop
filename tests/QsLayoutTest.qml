pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/panels"

Item {
    id: root
    property bool returning: false
    property bool flashed: false
    property real detailHeight: 0
    Check { id: check }
    TestEvent { id: input }
    PanelWindow {
        id: window
        implicitWidth: 420
        implicitHeight: 300
        WlrLayershell.namespace: "shell-qs-layout-test"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        QuickSettings { id: qs }
    }
    function find(item: Item, name: string): Item {
        if (item.objectName === name) return item;
        for (const child of item.children) {
            const found = root.find(child, name);
            if (found) return found;
        }
        return null;
    }
    Until { id: until }
    Connections {
        target: root.find(qs, "pageScrollbar")
        function onVisibleChanged(): void {
            if (root.returning && root.find(qs, "pageScrollbar").visible) root.flashed = true;
        }
    }
    Component.onCompleted: until.until(Settings.readyChanged, () => Settings.ready, ok => {
            check.equal("settings loaded in isolation", ok, true);
            Settings.setOverride("fontScale", 125);
            Settings.setOverride("popupOpacity", -1);
            Overlay.open(Overlay.quickSettings, Quickshell.screens[0], 200);
            opened.start();
    })
    Timer {
        id: opened
        interval: Appearance.t.popupMove + Appearance.t.popupResize
        onTriggered: {
            check.equal("tall content clamps to available height", qs.cardHeight, window.height);
            check.equal("short screens retain a usable scrollbar", root.find(qs, "pageScrollbar").visible, true);
            const power = root.find(qs, "power");
            power.forceActiveFocus(Qt.TabFocusReason);
            const at = power.mapToItem(qs.cardItem, 0, 0);
            check.equal("keyboard reveals footer on short screens",
                at.y >= 0 && at.y + power.height <= qs.cardItem.height, true);
            const tile = root.find(qs, "toggle");
            tile.forceActiveFocus(Qt.BacktabFocusReason);
            check.equal("keyboard can return to the top",
                tile.mapToItem(qs.cardItem, 0, 0).y >= 0, true);
            check.equal("unset opacity resolves through tuned default", Settings.popupOpacity, -1);
            check.near("initial default is 80 percent of theme glass", Appearance.popupOpacity, 0.8);
            Settings.setOverride("popupOpacity", 100);
            check.near("explicit opacity is preserved", Appearance.popupOpacity, 1);
            Settings.setOverride("popupOpacity", 1);
            check.near("opacity guard survives hand-edited values", Appearance.popupOpacity, 0.7);
            Settings.resetOverrides();
            check.near("reset restores the tuned default", Appearance.popupOpacity, 0.8);
            // The icon routes through FrontPage and QuickSettings just as Power does.
            (root.find(qs, "profile") as Clickable).clicked(null);
            profile.start();
        }
    }
    Timer {
        id: profile
        interval: Appearance.t.popupFade + Appearance.t.popupResize
        onTriggered: {
            check.equal("profile footer opens the profile detail route", qs.visiblePage, "profile");
            qs.page = "colors";
            detail.start();
        }
    }
    Timer {
        id: detail
        interval: Appearance.t.popupFade + Appearance.t.popupResize
        onTriggered: {
            check.equal("Colors detail route survives layout", qs.visiblePage, "colors");
            window.implicitHeight = 900;
            qs.page = "power";
            expanded.start();
        }
    }
    Timer {
        id: expanded
        interval: Appearance.t.popupFade + Appearance.t.popupResize
        onTriggered: {
            check.equal("shorter details route is ready", qs.visiblePage, "power");
            root.detailHeight = qs.cardHeight;
            root.returning = true;
            qs.page = "";
            returned.start();
        }
    }
    Timer {
        id: returned
        interval: Appearance.t.popupFade + Appearance.t.popupResize + Appearance.t.popupMove
        onTriggered: {
            check.equal("back returns to the front page", qs.visiblePage, "");
            check.equal("destination fits the taller viewport", qs.scrollable, false);
            check.equal("back grows from a shorter detail page", qs.cardHeight > root.detailHeight, true);
            check.equal("back never flashes a transient scrollbar", root.flashed, false);
            root.returning = false;
            Overlay.close();
            closed.start();
        }
    }
    Timer {
        id: closed
        interval: Appearance.t.popupFade + Appearance.t.grace + Appearance.t.popupResize
        onTriggered: {
            check.equal("closing releases the rendered page", qs.rendered, false);
            check.equal("return resets front page after teardown", qs.visiblePage, "");
            check.done();
        }
    }
}
