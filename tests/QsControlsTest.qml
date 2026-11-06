pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/panels/qs"

Item {
    id: root
    property int toggles: 0
    property int pages: 0
    property int mutes: 0
    property int powers: 0
    property int profiles: 0
    Check { id: check }
    TestEvent { id: input }
    PanelWindow {
        id: window
        implicitWidth: 420
        implicitHeight: 480
        WlrLayershell.namespace: "shell-qs-test"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        Flickable {
            id: scroll
            anchors.fill: parent
            contentHeight: 900
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: controls
                width: 360
                QsTile {
                    id: tile
                    width: parent.width / 2
                    title: "A long network title that wraps"
                    status: "Connected"
                    hasPage: true
                    onToggled: root.toggles++
                    onPageRequested: root.pages++
                }
                QsTile {
                    id: mode
                    width: parent.width / 2
                    compact: true
                    title: "Dark Style"
                    hasPage: true
                    onToggled: root.toggles++
                    onPageRequested: root.pages++
                }
                QsSliderRow {
                    id: row
                    width: parent.width
                    label: "Output volume"
                    value: 0.64
                    toggleEnabled: true
                    hasPage: true
                    onMoved: v => row.value = v
                    onIconClicked: { row.muted = !row.muted; root.mutes++; }
                    onPageRequested: root.pages++
                }
                QsSliderRow {
                    id: brightness
                    width: parent.width
                    label: "Brightness"
                    value: 0.72
                }
                QsFooter {
                    id: footer
                    width: parent.width
                    onProfileRequested: root.profiles++
                    onPowerRequested: root.powers++
                }
            }
        }
    }

    function find(item: Item, name: string): Item {
        if (item.objectName === name) return item;
        for (const child of item.children) {
            const found = root.find(child, name);
            if (found) return found;
        }
        return null;
    }
    function click(item: Item): void {
        input.mousePress(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
        input.mouseRelease(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
    }
    function exercise(): void {
        check.sameColor("available inactive device keeps normal icon ink", tile.iconInk, Appearance.c.text, 0);
        root.click(root.find(tile, "details"));
        check.equal("connectivity details open", root.pages, 1);
        check.equal("details never toggle the radio", root.toggles, 0);
        root.click(root.find(tile, "toggle"));
        check.equal("main tile toggles independently", root.toggles, 1);
        tile.toggleEnabled = false;
        check.sameColor("blocked device icon is muted", tile.iconInk, Appearance.c.textMuted, 0);
        root.click(root.find(tile, "toggle"));
        check.equal("blocked radio cannot toggle", root.toggles, 1);
        tile.toggleEnabled = true;
        root.click(root.find(mode, "details"));
        check.equal("compact Colors route remains independent", root.pages, 2);
        check.equal("Colors does not toggle Dark Style", root.toggles, 1);
        tile.enabled = false;
        check.sameColor("absent device icon is muted", tile.iconInk, Appearance.c.textMuted, 0);
        root.click(root.find(tile, "details"));
        check.equal("disappeared hardware cannot open details", root.pages, 2);
        check.equal("unavailable tile retains its geometry", tile.height >= Appearance.m.qsTileHeight, true);
        const slider = root.find(row, "level") as Slider;
        const percent = root.find(row, "percentage") as Label;
        check.equal("real backend percentage", percent.text, "64%");
        row.value = 1.25;
        check.equal("boosted backend value is not hidden", percent.text, "125%");
        check.near("travel clamps boosted value", slider.clamped, 1);
        row.value = 0.64;
        const audibleFill = slider.fillColor.toString();
        const audibleKnob = slider.knobColor.toString();
        root.click(root.find(row, "mute"));
        check.equal("mute remains actionable", root.mutes, 1);
        check.sameColor("available muted audio keeps normal icon ink",
            (root.find(row, "mute") as IconButton).iconColor, Appearance.c.text, 0);
        check.equal("muting preserves backend percentage", percent.text, "64%");
        check.equal("muting subdues the slider fill", slider.fillColor.toString() !== audibleFill, true);
        check.equal("muting subdues the slider knob", slider.knobColor.toString() !== audibleKnob, true);
        check.equal("assistive description reports mute", slider.Accessible.description.includes("Muted"), true);
        root.click(root.find(row, "devices"));
        check.equal("device route preserved", root.pages, 3);
        check.equal("device choice does not mute", root.mutes, 1);
        check.equal("brightness has no mute target", root.find(brightness, "mute").visible, false);
        check.near("slider trailing edges align", root.find(brightness, "level").width, slider.width);
        slider.forceActiveFocus();
        input.keyClick(Qt.Key_Home, Qt.NoModifier, -1);
        check.near("keyboard slider Home reaches zero", row.value, 0);
        input.keyClick(Qt.Key_Right, Qt.NoModifier, -1);
        check.near("keyboard arrows use real slider mapping", row.value, slider.stepSize);
        Settings.setOverride("border", 0);
        check.equal("decorative border zero preserves keyboard ring", slider.focusVisible, true);
        root.find(mode, "details").forceActiveFocus();
        input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
        check.equal("keyboard reaches Colors independently", root.pages, 4);
        const settings = root.find(footer, "settings");
        const power = root.find(footer, "power");
        const profile = root.find(footer, "profile");
        check.equal("profile precedes Settings", profile.x < settings.x, true);
        check.equal("profile availability follows its service", profile.enabled, Power.hasProfiles);
        root.click(profile);
        check.equal("profile has its own footer route", root.profiles, Power.hasProfiles ? 1 : 0);
        check.equal("Settings precedes Power", settings.x < power.x, true);
        Overlay.open(Overlay.quickSettings, Compositor.focusedScreen, 200);
        root.click(settings);
        check.equal("footer opens Settings", Overlay.active, Overlay.settings);
        check.equal("Settings preserves the hand-off", Overlay.flight?.from, Overlay.quickSettings);
        root.click(power);
        check.equal("footer uses existing Power route", root.powers, 1);
        let scene = window.contentItem;
        while (scene.parent) scene = scene.parent;
        const powerTip = root.find(scene, "tooltip:Power") as Tooltip;
        InputMode.keyboardUsed();
        power.forceActiveFocus(Qt.TabFocusReason);
        check.near("footer tooltip uses its laid-out position", powerTip.anchorY,
            power.mapToItem(scene, 0, 0).y);
        controls.y = 37;
        check.near("tooltip follows a moving ancestor", powerTip.anchorY,
            power.mapToItem(scene, 0, 0).y);
        controls.y = 0;
        Overlay.close();
        row.enabled = false;
        check.sameColor("unavailable audio icon is muted",
            (root.find(row, "mute") as IconButton).iconColor, Appearance.c.textMuted, 0);
        check.equal("unavailable slider reports its state", slider.Accessible.description, "Unavailable");
        root.click(root.find(row, "mute"));
        check.equal("hardware removal disables mute", root.mutes, 1);
        row.enabled = true;
        input.mouseWheel(slider, slider.width / 2, slider.height / 2, Qt.NoButton, Qt.NoModifier, 0, -120, -1);
        check.near("wheel cannot change volume", row.value, slider.stepSize);
        frames.phase = 1;
        frames.ticks = 0;
        frames.running = true;
    }
    FrameAnimation {
        id: frames
        property int ticks: 0
        property int phase: 0
        running: true
        onTriggered: {
            if (++frames.ticks < 5) return;
            frames.running = false;
            if (frames.phase === 0) root.exercise();
            else {
                check.equal("wheel reaches scroller", scroll.contentY > 0, true);
                check.done();
            }
        }
    }
}
