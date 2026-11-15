pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/components"
import "root:/services"
import "root:/modules/settings"

// Exercise the real settings sections, saved units and slider adjustment.
// The runner gives notification, font and config writes private boundaries.
Item {
    id: root
    readonly property ShellScreen testScreen: Quickshell.screens.find(screen => screen.name === "GAP-1") ?? null
    readonly property bool isolated: Quickshell.env("TEST_NOTIFICATION_BUS") === "private"
        && Quickshell.env("TEST_BIN") !== "" && root.testScreen !== null
    Check { id: check }
    Until { id: ready }
    SettingsPanel { id: panel }
    AppearanceSection { id: appearance; visible: false; width: 480 }
    DockSection { id: dock; visible: false; width: 480 }
    NotificationsSection { id: notifications; visible: false; width: 480 }
    FloatingWindow {
        id: window
        visible: root.isolated
        screen: root.testScreen
        title: "shell-settings-test"
        implicitWidth: 500
        implicitHeight: 600
        WindowsSection { id: windows; width: parent.width }
    }

    function find(item: Item, test: var): Item {
        if (test(item)) return item;
        for (const child of item.children) {
            const found = root.find(child, test);
            if (found) return found;
        }
        return null;
    }

    function row(item: Item, key: string): SettingRow {
        return root.find(item, child => child instanceof SettingRow && child.key === key) as SettingRow;
    }

    function start(): void {
        Settings.setOverride("hyprGapsIn", 3);
        Settings.setOverride("dockHideDelay", 1005);
        Settings.setOverride("notificationTimeout", 3500);
        Settings.setDockAutoHide(true);
        const gaps = root.row(windows, "hyprGapsIn");
        check.equal("existing half-gap is displayed as the whole space", gaps.displayValue, 6);
        check.equal("existing half-gap storage is preserved", Settings.hyprGapsIn, 3);
        check.equal("hide delay is displayed in seconds without rounding away saved precision", root.row(dock, "dockHideDelay").displayValue, 1.005);
        check.equal("notification duration is displayed in seconds", root.row(notifications, "notificationTimeout").displayValue, 3.5);
        check.equal("notification storage stays in milliseconds", Settings.notificationTimeout, 3500);
        const slider = root.find(gaps, child => child instanceof Slider) as Slider;
        slider.moved(slider.value + slider.stepSize);
        check.equal("one slider step retains the existing stored unit", Settings.hyprGapsIn, 4);
        check.equal("one slider step displays the actual resulting gap", gaps.displayValue, 8);

        // Hidden containers suppress effective visibility; reveal these unmapped
        // sections while checking the controls' own availability conditions.
        appearance.visible = true;
        dock.visible = true;
        Settings.setOverride("hyprBlur", 0);
        check.equal("blur strength hides while blur is off", root.row(appearance, "hyprBlurSize").visible, false);
        Settings.setOverride("hyprBlur", 1);
        check.equal("blur switch and strength share one section", root.row(appearance, "hyprBlurSize").visible, true);
        Settings.setRoundnessFollowsWindows(true);
        check.equal("following window corners hides the unused manual value", root.row(appearance, "roundness").visible, false);
        Settings.setRoundnessFollowsWindows(false);
        check.equal("independent corners expose their manual value", root.row(appearance, "roundness").visible, true);
        Settings.setDockOpacityFollowsBar(true);
        check.equal("matching panel opacity hides the unused dock value", root.row(dock, "dockOpacity").visible, false);
        Settings.setDockMagnificationEnabled(false);
        check.equal("disabled magnification hides its size control", root.row(dock, "dockZoom").visible, false);
        appearance.visible = false;
        dock.visible = false;

        const index = panel.buildIndex();
        check.equal("appearance search includes shared blur controls", index.appearance.includes("background blur"), true);
        check.equal("windows has no duplicate blur control", index.windows.includes("background blur"), false);
        check.equal("appearance search includes window frame", index.appearance.includes("window frame"), true);
        check.equal("panel search describes both vertical gaps", index.panel.includes("gap above and below"), true);
        check.equal("window search describes only the side and bottom margins", index.windows.includes("side and bottom margins"), true);
        check.equal("reset names what it actually resets", index.reset.includes("reset all settings"), false);
        const scroll = root.find(panel, child => child instanceof Flickable) as Flickable;
        scroll.contentY = 180;
        panel.section = "windows";
        check.equal("switching sections starts at the top", scroll.contentY, 0);
        check.done();
    }

    Component.onCompleted: {
        if (!root.isolated) {
            check.report("private desktop and bus required", false, "run with tools/test.sh on GAP-1");
            check.done();
            return;
        }
        ready.until(CompositorOptions.configuredChanged,
            () => Settings.ready && CompositorOptions.known("hyprRounding"), ok => {
                check.equal("settings and compositor are ready", ok, true);
                if (ok) root.start(); else check.done();
            });
    }
}
