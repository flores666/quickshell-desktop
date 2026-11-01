pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/dock"
import "root:/modules/settings"

Item {
    id: root
    Check { id: check }
    Until { id: wait }
    FileWait { id: savedFile }
    property var saved: null
    property var pending: null
    readonly property string statePath: Quickshell.statePath("settings.json")

    Surface { id: glass }
    DockSection { id: section; width: 500 }
    DockRow {
        id: row
        screen: Quickshell.screens[0]
        panel: glass
        function reconcile(arriving: bool): void {}
    }
    FileView { id: external; path: root.statePath; blockWrites: true; printErrors: false }
    Timer {
        id: delay
        onTriggered: { const then = root.pending; root.pending = null; then(); }
    }
    function after(ms: int, then: var): void {
        root.pending = then; delay.interval = ms; delay.start();
    }
    function find(item: var, predicate: var): var {
        if (predicate(item)) return item;
        for (const child of item.children ?? []) {
            const found = root.find(child, predicate);
            if (found) return found;
        }
        return null;
    }
    function control(key: string): var {
        return root.find(section, item => item instanceof SettingRow && item.key === key);
    }
    function slot(index: int): var {
        return row.children.filter(child => child instanceof DockSlot)[index];
    }
    function launcher(): var {
        return row.children.find(child => child instanceof DockButton);
    }
    function pointAt(index: real): void {
        row.pointerX = (row.screen.width - row.original.width) / 2
            + Appearance.m.dockSlot / 2 + index * row.slotStride;
    }

    Component.onCompleted: wait.until(Settings.readyChanged, () => Settings.ready,
        () => Qt.callLater(root.start))

    function start(): void {
        check.equal("magnification defaults to enabled", Settings.dockMagnificationEnabled, true);
        const available = typeof Settings.setDockMagnificationEnabled === "function"
            && Tuning.spec.dockZoom !== undefined && Tuning.spec.dockWaveWidth !== undefined
            && Dock.magnificationDurationRange !== undefined;
        check.equal("all four settings have owners", available, true);
        check.equal("settings expose a Magnification group",
            root.find(section, item => item instanceof SettingGroup && item.title === "Magnification") !== null, true);
        if (!available) { check.done(); return; }
        root.saved = { enabled: Settings.dockMagnificationEnabled,
            numbers: Settings.overrideKeys.map(key => ({ key, value: Settings[key] })) };
        check.near("default zoom preserves 120%", Appearance.m.dockMagnification, 1.2);
        check.near("default width preserves the current wave", Appearance.m.dockWaveSpread, 1.85);
        check.equal("default response preserves 120 ms", Dock.magnificationDuration, 120);
        const specs = [
            { key: "dockZoom", min: 0, max: 20, value: 20, suffix: "%" },
            { key: "dockWaveWidth", min: 50, max: 200, value: 100, suffix: "%" },
            { key: "dockMagnificationDuration", min: 40, max: 300, value: 120, suffix: "ms" }
        ];
        for (const spec of specs) {
            const control = root.control(spec.key);
            check.equal(spec.key + ": control exists", control !== null, true);
            if (!control) continue;
            check.equal(spec.key + ": slider minimum", control.min, spec.min);
            check.equal(spec.key + ": slider maximum", control.max, spec.max);
            check.equal(spec.key + ": initial value", control.value, spec.value);
            check.equal(spec.key + ": unit", control.suffix, spec.suffix);
            check.equal(spec.key + ": registered for reset", Settings.overrideKeys.includes(spec.key), true);
            const slider = root.find(control, item => item instanceof Slider);
            slider.moved(0.5);
            check.equal(spec.key + ": slider writes the setting", Settings[spec.key], (spec.min + spec.max) / 2);
            const reset = root.find(control, item => item instanceof ResetButton);
            reset.clicked(null);
            check.equal(spec.key + ": row reset restores default", Settings[spec.key], -1);
        }
        root.clamps();
        row.drawn = Array.from({ length: 9 }, (_, i) => ({ key: "settings-" + i,
            leaving: false, arriving: false,
            item: { key: "settings-" + i, name: "Test", icon: "utilities-terminal", windows: [] } }));
        row.forceLayout();
        root.wave();
    }

    function clamps(): void {
        Settings.setOverride("dockZoom", 900);
        Settings.setOverride("dockWaveWidth", 900);
        Settings.setOverride("dockMagnificationDuration", 900);
        check.near("zoom cannot exceed the strict 120% cap", Appearance.m.dockMagnification, 1.2);
        check.near("wave width clamps at 200%", Appearance.m.dockWaveSpread, 3.7);
        check.equal("response clamps at 300 ms", Dock.magnificationDuration, 300);
        Settings.setOverride("dockZoom", 0);
        Settings.setOverride("dockWaveWidth", 0);
        Settings.setOverride("dockMagnificationDuration", 0);
        check.near("zero zoom means no growth", Appearance.m.dockMagnification, 1);
        check.near("width clamps at 50%", Appearance.m.dockWaveSpread, 0.925);
        check.equal("response clamps at 40 ms", Dock.magnificationDuration, 40);
        for (const key of ["dockZoom", "dockWaveWidth", "dockMagnificationDuration"])
            Settings.setOverride(key, -1);
    }

    function wave(): void {
        row.magnifying = true;
        root.pointAt(4);
        Settings.setOverride("dockZoom", 10);
        check.near("zoom changes the peak live", row.magnifications[4], 1.1);
        const neighbor = row.magnifications[3];
        Settings.setOverride("dockWaveWidth", 50);
        check.equal("narrower wave reduces neighbor growth", row.magnifications[3] < neighbor, true);
        Settings.setOverride("dockWaveWidth", 200);
        check.equal("wider wave increases neighbor growth", row.magnifications[3] > neighbor, true);
        check.near("width does not alter the peak", row.magnifications[4], 1.1);
        Settings.setOverride("dockZoom", 0);
        check.equal("zero zoom keeps all targets at rest", row.magnifications.every(value => value === 1), true);
        Settings.setOverride("dockZoom", 20);
        Settings.setOverride("dockWaveWidth", 100);
        Settings.setOverride("dockMagnificationDuration", 40);
        root.after(56, () => {
            check.near("application uses fast response setting", root.slot(4).magnification, 1.2);
            root.pointAt(9);
            root.after(56, () => {
                check.near("launcher uses fast response setting", root.launcher().magnification, 1.2);
                Settings.setOverride("dockMagnificationDuration", 300);
                root.pointAt(4);
                root.after(160, root.slowResponse);
            });
        });
    }

    function slowResponse(): void {
        check.equal("application uses slow response setting", root.slot(4).magnification < 1.199, true);
        check.equal("launcher uses slow response setting", root.launcher().magnification > row.magnifications[9] + 0.01, true);
        const group = root.find(section, item => item instanceof SettingGroup && item.title === "Magnification");
        const toggle = group ? root.find(group, item => item instanceof ToggleSwitch) : null;
        check.equal("magnification toggle exists", toggle !== null, true);
        if (toggle) toggle.toggled(false);
        else Settings.setDockMagnificationEnabled(false);
        check.equal("toggle writes the preference", Settings.dockMagnificationEnabled, false);
        check.equal("disabled wave targets rest", row.magnifications.every(value => value === 1), true);
        for (const key of ["dockZoom", "dockWaveWidth", "dockMagnificationDuration"])
            check.equal(key + ": hidden while disabled", root.control(key)?.visible, false);
        root.after(316, () => {
            row.forceLayout();
            check.near("disabled dock restores resting width", row.width, row.original.width);
            Settings.setDockMagnificationEnabled(true);
            check.near("re-enable resumes the chosen wave", row.magnifications[4], 1.2);
            check.equal("re-enable preserves response", Dock.magnificationDuration, 300);
            root.persist();
        });
    }

    function persist(): void {
        Settings.setDockMagnificationEnabled(false);
        Settings.setOverride("dockZoom", 12);
        Settings.setOverride("dockWaveWidth", 150);
        Settings.setOverride("dockMagnificationDuration", 80);
        savedFile.until(root.statePath, text => {
            try {
                const state = JSON.parse(text);
                return state.dockMagnificationEnabled === false && state.dockZoom === 12
                    && state.dockWaveWidth === 150 && state.dockMagnificationDuration === 80;
            } catch (_) { return false; }
        }, text => {
            const state = JSON.parse(text);
            check.equal("all four choices are persisted", state.dockMagnificationEnabled === false
                && state.dockZoom === 12 && state.dockWaveWidth === 150 && state.dockMagnificationDuration === 80, true);
            state.dockMagnificationEnabled = true;
            state.dockZoom = 6;
            state.dockWaveWidth = 125;
            state.dockMagnificationDuration = 200;
            wait.until(Settings.dockZoomChanged, () => Settings.dockZoom === 6, ok => {
                check.equal("saved preferences reload", ok, true);
                Qt.callLater(root.reloaded);
            });
            external.setText(JSON.stringify(state));
        });
    }

    function reloaded(): void {
        check.equal("toggle reloads", Settings.dockMagnificationEnabled, true);
        check.near("zoom reloads", Appearance.m.dockMagnification, 1.06);
        check.near("width reloads", Appearance.m.dockWaveSpread, 2.3125);
        check.equal("response reloads", Dock.magnificationDuration, 200);
        Settings.setDockMagnificationEnabled(false);
        Settings.resetOverrides();
        check.equal("Reset all preserves the toggle", Settings.dockMagnificationEnabled, false);
        check.near("Reset all restores zoom", Appearance.m.dockMagnification, 1.2);
        check.near("Reset all restores width", Appearance.m.dockWaveSpread, 1.85);
        check.equal("Reset all restores response", Dock.magnificationDuration, 120);
        for (const entry of root.saved.numbers) Settings.setOverride(entry.key, entry.value);
        Settings.setDockMagnificationEnabled(root.saved.enabled);
        check.done();
    }
}
