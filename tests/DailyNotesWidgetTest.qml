pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"
import "root:/modules/dock"
import "root:/modules/settings"
import "root:/modules/widgets"

Item {
    id: root
    Check { id: check }
    TestEvent { id: input }
    Until { id: ready }
    FileWait { id: saved }
    FileView {
        id: externalSettings
        path: Quickshell.statePath("settings.json")
        blockWrites: true
        printErrors: false
    }
    DockPanel { id: dock; modelData: Quickshell.screens[0] }
    OverlaySurface {
        id: surface
        DailyNotesPanel { id: notes }
        SettingsPanel { id: settings }
    }

    readonly property DockRow row: root.find(dock.contentItem, child => child instanceof DockRow) as DockRow
    readonly property string missing: "quickshell-widget-test-missing"
    readonly property string historyDay: "2001-01-02"
    property var apps: []
    property var afterAnimation: null
    Timer {
        id: animation
        interval: Math.max(Appearance.t.base, Appearance.t.popupFade) + Appearance.t.grace
        onTriggered: root.afterAnimation()
    }
    function after(then: var): void {
        root.afterAnimation = then;
        animation.restart();
    }

    function find(item: Item, matches: var): Item {
        if (matches(item)) return item;
        for (const child of item.children) {
            const result = root.find(child, matches);
            if (result) return result;
        }
        return null;
    }

    function named(name: string): Item {
        return root.find(notes.cardItem, child => child.objectName === name);
    }
    function click(item: Item, button: int): void {
        input.mouseClick(item, item.width / 2, item.height / 2, button, Qt.NoModifier, -1);
    }

    function widget(): DockSlot {
        return root.find(root.row, child => child instanceof DockSlot && child.widget) as DockSlot;
    }
    function app(key: string): DockSlot {
        return root.find(root.row, child => child instanceof DockSlot && child.entry.key === key) as DockSlot;
    }

    function expectOrder(label: string, keys: var): void {
        check.equal(label, JSON.stringify(Dock.slotKeys), JSON.stringify([...keys, Dock.launcherSlot.key]));
    }

    function expectDividers(label: string, widgetEdge: int, launcher: bool): void {
        const line = root.find(root.row.panel, child => child instanceof DockSeparator);
        const dividers = line.parent.children.filter(child => child instanceof DockSeparator && child.visible);
        check.equal(label + " divider count", dividers.length, Number(launcher) + Number(widgetEdge !== 0));
        if (widgetEdge !== 0 && !root.row.rearranging) {
            const control = root.widget().control;
            const edge = widgetEdge === Qt.LeftEdge ? 0 : control.width;
            const x = control.mapToItem(root.row, edge, 0).x;
            const gap = Appearance.m.dockGap;
            check.equal(label + " widget divider has the shared spacing", dividers.some(divider => {
                const lineX = divider.mapToItem(root.row, 0, 0).x;
                return Math.abs((widgetEdge === Qt.LeftEdge ? x - lineX - divider.width : lineX - x) - gap) < 0.001;
            }), true);
        }
    }

    function toggleFromSettings(then: var): void {
        settings.section = "widgets";
        Overlay.open(Overlay.settings, dock.modelData, dock.width / 2);
        root.after(() => {
            const toggle = root.find(settings.cardItem, child => child instanceof ToggleSwitch);
            check.equal("Widgets section exposes the Daily Notes switch", toggle !== null, true);
            if (!toggle) { check.done(); return; }
            root.click(toggle, Qt.LeftButton);
            Overlay.close();
            root.after(then);
        });
    }

    function carry(slot: DockSlot, dx: real, target: var, preview: var): void {
        const scene = dock.contentItem;
        const center = slot.control.mapToItem(scene, slot.control.width / 2, slot.control.height / 2);
        const grab = center.x + Math.sign(dx) * (Application.styleHints.startDragDistance + 2);
        input.mousePress(scene, center.x, center.y, Qt.LeftButton, Qt.NoModifier, -1);
        input.mouseMove(scene, grab, center.y, -1, Qt.LeftButton, Qt.NoModifier);
        input.mouseMove(scene, grab + dx, center.y, -1, Qt.LeftButton, Qt.NoModifier);
        check.equal("pointer drag finds the intended slot", root.row.drag?.to, target);
        preview();
        input.mouseRelease(scene, grab + dx, center.y, Qt.LeftButton, Qt.NoModifier, -1);
        check.equal("drop releases the dock", root.row.drag, null);
        check.equal("drop does not open the widget", Overlay.active, Overlay.none);
    }

    function start(): void {
        Settings.setDockAutoHide(false);
        Settings.setDockMagnificationEnabled(false);
        for (const key of Settings.pinnedApps.slice()) Settings.unpin(key);
        root.apps = Apps.all.slice(0, 3).map(app => app.id);
        Settings.pin(root.missing);
        Settings.setDockOrder([root.missing, ...root.apps]);
        for (const key of root.apps) Settings.pin(key);
        check.equal("existing settings leave the new widget off by default", Settings.dailyNotesEnabled, false);
        root.expectOrder("legacy app order is preserved", root.apps);
        for (const category of ["Other", "Tasks"]) DailyNotes.addCategory(category);
        check.equal("historical fixture saves", DailyNotes.save(root.historyDay, "", "Historical task", "", "", "Tasks"), true);
        root.toggleFromSettings(root.arrange);
    }

    function arrange(): void {
        const slot = root.widget();
        root.expectOrder("the widget defaults to the far left", [null, ...root.apps]);
        check.equal("widget exists after enabling", slot !== null, true);
        if (!slot) { check.done(); return; }
        root.row.forceLayout();
        check.near("widget starts on the row's left edge", slot.x, 0);
        root.expectDividers("left edge", Qt.RightEdge, true);
        check.near("resting geometry includes the widget", root.row.original.width, root.row.width);
        const appTarget = root.row.iconTargets[0];
        check.equal("only applications publish native targets", root.row.iconTargets.length, root.apps.length);
        check.near("native target follows the icon after the wider slot", appTarget.rect.x + appTarget.rect.width / 2,
            root.app(root.apps[0]).control.mapToItem(dock.contentItem, Appearance.m.dockSlot / 2, 0).x);

        const [first, second, third] = root.apps;
        root.carry(slot, root.row.slotStride, first, () => root.expectDividers("drag into the icons", 0, true));
        root.expectOrder("widget drops between applications", [first, null, second, third]);
        root.expectDividers("between applications", 0, true);
        check.equal("reordering retains the widget delegate", root.widget(), slot);
        check.near("mixed-width centers reflect the new order immediately",
            root.row.original.centers[1] - root.row.original.centers[0],
            (Appearance.m.dockIcon + slot.contentWidth) / 2 + Appearance.m.dockGap);
        root.carry(slot, root.row.slotStride * 2, third,
            () => root.expectDividers("drag beside the launcher", Qt.LeftEdge, false));
        root.expectOrder("widget drops beside the launcher", [first, second, third, null]);
        root.expectDividers("right edge", Qt.LeftEdge, false);
        root.carry(root.app(third), slot.width, null, () => root.expectDividers("drag an icon past the widget", 0, true));
        root.expectOrder("applications can also move across the widget", [first, second, null, third]);
        root.expectDividers("icon after the widget", 0, true);
        root.toggleFromSettings(() => {
            root.expectOrder("hiding the widget leaves app order intact", root.apps);
            check.equal("hiding removes the widget delegate", root.widget(), null);
            root.expectDividers("widget hidden", 0, true);
            root.toggleFromSettings(() => {
                root.expectOrder("showing restores the saved position", [first, second, null, third]);
                const persisted = text => {
                    try { return JSON.parse(text); } catch (e) { return {}; }
                };
                saved.until(Quickshell.statePath("settings.json"), text => persisted(text).dailyNotesEnabled, text => {
                    const data = persisted(text);
                    check.equal("widget order is saved with unavailable pins", JSON.stringify(data.dockOrder),
                        JSON.stringify([root.missing, first, second, { widget: "daily-notes" }, third]));
                    root.reloadPlacement(data);
                });
            });
        });
    }

    function reloadPlacement(data: var): void {
        const [first, second, third] = root.apps;
        data.dockOrder = [root.missing, first, { widget: "daily-notes" }, second, third];
        externalSettings.setText(JSON.stringify(data));
        const expected = JSON.stringify([first, null, second, third, Dock.launcherSlot.key]);
        ready.until(Dock.slotKeysChanged, () => JSON.stringify(Dock.slotKeys) === expected, ok => {
            check.equal("reading a saved mixed order restores widget placement", ok, true);
            if (ok) root.after(root.openNotes);
            else check.done();
        });
    }

    function openNotes(): void {
        const slot = root.widget();
        const anchor = slot.control.centerX();
        root.click(slot.control, Qt.LeftButton);
        check.equal("click opens the notes overlay", Overlay.active, Overlay.dailyNotes);
        check.near("popup anchors to the relocated widget", Overlay.anchorXOf[Overlay.dailyNotes], anchor);
        check.equal("the dock stays out while its popup is open", dock.held, true);
        root.after(root.compose);
    }

    function compose(): void {
        check.equal("input is confined to the notes card", surface.mask.item, notes.cardItem);
        check.equal("notes opens on today's date", notes.day, DailyNotes.today);
        const entry = root.named("quickNote") as InputField;
        check.equal("popup initially focuses quick entry", entry.input.activeFocus, true);
        input.keyClick(Qt.Key_X, Qt.NoModifier, -1);
        check.equal("typing on open reaches the task field", entry.text.toLowerCase(), "x");
        check.equal("opening the widget defaults to the last task's category", notes.targetCategory, "Tasks");
        entry.text = "Today's task";
        input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
        check.equal("Enter clears the draft on success", entry.text, "");
        check.equal("adding a task in the default category refreshes the Dock preview",
            DailyNotes.preview?.title === "Today's task" && DailyNotes.preview?.category === "Tasks", true);
        const task = root.find(notes.cardItem, child => child instanceof DailyNoteRow) as DailyNoteRow;
        check.equal("the category renders its task", task?.note.title, "Today's task");
        if (!task) { check.done(); return; }
        root.after(() => {
            root.click(task, Qt.RightButton);
            root.after(root.editToday);
        });
    }

    function editToday(): void {
        const edit = root.find(notes.cardItem, child => child instanceof MenuItemRow && child.label === "Edit");
        check.equal("editing is offered after the popup grows", edit?.visible, true);
        if (!edit) { check.done(); return; }
        root.click(edit, Qt.LeftButton);
        root.after(root.saveToday);
    }

    function saveToday(): void {
        (root.named("noteStart") as InputField).text = "18:00";
        (root.named("noteEnd") as InputField).text = "09:00";
        check.equal("reverse deadline is rejected in the editor", root.named("saveNote").enabled, false);
        (root.named("noteEnd") as InputField).text = "19:15";
        root.click(root.named("saveNote"), Qt.LeftButton);
        check.equal("task keeps its time window", DailyNotes.rangeText(DailyNotes.preview), "18:00–19:15");
        root.after(() => {
            root.click(root.named("previousNoteDay"), Qt.LeftButton);
            check.equal("history jumps to the day with notes", notes.day, root.historyDay);
            root.after(root.track);
        });
    }

    function track(): void {
        const task = root.find(notes.cardItem, child => child instanceof DailyNoteRow) as DailyNoteRow;
        check.equal("history renders the earlier task", task?.note.title, "Historical task");
        if (!task) { check.done(); return; }
        root.click(task, Qt.RightButton);
        root.after(() => root.selectTracking(task));
    }

    function selectTracking(task: DailyNoteRow): void {
        const trackAction = root.find(notes.cardItem, child => child instanceof MenuItemRow && child.label === "Track");
        check.equal("right click offers Track", trackAction?.visible, true);
        if (!trackAction) { check.done(); return; }
        root.click(trackAction, Qt.LeftButton);
        check.equal("using Track closes the context menu", Overlay.menu, null);
        check.equal("tracking changes the Dock summary", (root.widget().control as DockNotesButton).summary, "Historical task");
        root.after(() => root.completeHistoricalTask(task));
    }

    function completeHistoricalTask(task: DailyNoteRow): void {
        root.click(task, Qt.LeftButton);
        check.equal("checkbox completes the task", task.done, true);
        check.equal("completing it returns to the latest open task", DailyNotes.preview?.title, "Today's task");
        DailyNotes.remove(task.note.id);
        check.equal("removing the last historical task keeps its day open", notes.day, root.historyDay);
        root.click(root.named("nextNoteDay"), Qt.LeftButton);
        check.equal("next day returns to current checklist from empty history", notes.day, DailyNotes.today);
        for (const key of root.apps) Settings.unpin(key);
        root.after(() => {
            root.expectOrder("only the widget and launcher remain", [null]);
            root.expectDividers("no application icons", 0, false);
            Settings.setDailyNotesEnabled(false);
            check.equal("hiding also closes the open notes popup", Overlay.active, Overlay.none);
            check.done();
        });
    }
    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("private state required", false, "run with tools/test.sh");
            check.done();
            return;
        }
        ready.until(Settings.readyChanged, () => Settings.ready, ok => {
            if (!ok) { check.report("settings ready", false, "load timed out"); check.done(); return; }
            ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
                if (!ok) { check.report("notes ready", false, "load timed out"); check.done(); return; }
                ready.until(Apps.allChanged, () => Apps.all.length >= 3, ok => {
                    if (ok) root.start();
                    else { check.report("installed fixtures", false, "need three applications"); check.done(); }
                });
            });
        });
    }
}
