pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import "root:/config"
import "root:/components"
import "root:/modules/common"
import "root:/modules/widgets"
import "root:/services"

Item {
    id: root

    readonly property string category: "Work"
    readonly property string wrappedTitle: "Review the release plan and confirm the remaining checklist with the project team.\nSend the updated notes."
    readonly property InputField composer: root.named(notes.cardItem, "quickNote") as InputField
    property string editedId
    property string firstId
    property DailyNoteRow editedRow

    Check { id: check }
    Until { id: ready }
    TestEvent { id: input }

    OverlaySurface {
        id: surface
        DailyNotesPanel { id: notes }
    }

    Timer {
        id: settle
        property var next
        interval: Appearance.t.popupFade + Appearance.t.popupResize + Appearance.t.grace
        onTriggered: settle.next()
    }

    function afterLayout(next: var): void {
        settle.next = next;
        settle.restart();
    }

    function find(item: Item, matches: var): Item {
        if (!item || matches(item)) return item;
        for (const child of item.children) {
            const found = root.find(child, matches);
            if (found) return found;
        }
        return null;
    }

    function named(item: Item, name: string): Item {
        return root.find(item, child => child.objectName === name);
    }

    function row(id: string): DailyNoteRow {
        return root.find(notes.cardItem, child => child instanceof DailyNoteRow && child.note?.id === id) as DailyNoteRow;
    }

    function click(item: Item): void {
        input.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
    }

    function openPickerFromKeyboard(badge: Item): void {
        badge.forceActiveFocus(Qt.TabFocusReason);
        input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
    }

    function append(): void {
        root.editedRow = root.row(root.editedId);
        root.composer.text = "Added from the composer";
        input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
        root.afterLayout(root.edit);
    }

    function edit(): void {
        const first = root.row(root.firstId);
        const added = root.row(DailyNotes.document.notes[0].id);
        check.equal("the composer appends below both saved tasks",
            first && root.editedRow && added && first.y < root.editedRow.y && root.editedRow.y < added.y, true);
        check.equal("the existing task keeps its row", root.row(root.editedId), root.editedRow);
        const badge = root.named(root.editedRow, "noteDeadlineBadge") as Clickable;
        const checkbox = root.named(root.editedRow, "noteCheckbox");
        check.equal("the badge shows only the time beneath the title",
            badge.visible && badge.y > 0 && (badge as DailyNoteDeadlineBadge).text === "09:30", true);
        check.equal("the time badge is fully rounded and compact",
            badge.radius >= badge.height / 2 && badge.width < badge.parent.width, true);
        const label = root.named(root.editedRow, "noteTitleLabel");
        check.near("the checkbox is centered on the wrapped title",
            checkbox.y + checkbox.height / 2, label.mapToItem(root.editedRow, 0, label.height / 2).y);
        root.click(badge);
        check.equal("the time picker opens without entering text editing",
            Overlay.menu?.source === badge && notes.draft === null, true);
        root.afterLayout(root.scrollDeadline);
    }

    function editTitle(): void {
        const title = root.named(root.editedRow, "noteTitle") as TextEdit;
        const label = root.named(root.editedRow, "noteTitleLabel") as Label;
        const badge = root.named(root.editedRow, "noteDeadlineBadge");
        check.equal("inline editing keeps both neighboring rows visible",
            !!title?.activeFocus && root.row(root.firstId).visible
                && root.row(DailyNotes.document.notes[0].id).visible, true);
        check.equal("the same time control is available below the text field", badge.mapToItem(title, 0, 0).y >= title.height, true);
        check.equal("editing uses the task title's font size", title.font.pixelSize, label.font.pixelSize);
        check.equal("the editor retains both wrapping and explicit line breaks",
            title.text === root.wrappedTitle && title.lineCount === label.lineCount && title.lineCount > 2, true);
        check.near("the multiline editor is as tall as the rendered title", title.height, label.height);
        check.equal("the editor has no category, save, or cancel controls",
            root.named(root.editedRow, "editNoteCategory") === null && root.named(root.editedRow, "saveNote") === null
                && !root.find(root.editedRow, child => child instanceof IconButton && child.Accessible.name === "Cancel editing"), true);
        title.cursorPosition = title.length;
        input.mouseClick(title, 1, 2, Qt.LeftButton, Qt.NoModifier, -1);
        check.equal("pressing inside the editor moves the caret without closing editing",
            title.cursorPosition === 0 && title.activeFocus && notes.draft?.id === root.editedId, true);
        title.selectAll();
        input.keyClick(Qt.Key_Backspace, Qt.NoModifier, -1);
        check.equal("an empty title keeps the last saved title", DailyNotes.find(root.editedId).title, root.wrappedTitle);
        input.keyClick(Qt.Key_N, Qt.NoModifier, -1);
        input.keyClick(Qt.Key_E, Qt.NoModifier, -1);
        input.keyClick(Qt.Key_W, Qt.NoModifier, -1);
        check.equal("each key saves the full title immediately", DailyNotes.find(root.editedId).title, "new");
        check.equal("typing keeps the same focused row",
            title.activeFocus && root.row(root.editedId) === root.editedRow, true);
        input.keyClick(Qt.Key_Return, Qt.ShiftModifier, -1);
        input.keyClick(Qt.Key_X, Qt.NoModifier, -1);
        check.equal("explicit line breaks save without closing the editor", DailyNotes.find(root.editedId).title, "new\nx");
        check.equal("saving the title retains the independently edited time", DailyNotes.find(root.editedId).deadline,
            "2097-04-15T10:20");
        root.openPickerFromKeyboard(badge);
        check.equal("the keyboard can open the picker while the title is being edited",
            Overlay.menu?.source === badge, true);
        root.afterLayout(root.chooseTimeWhileEditing);
    }

    function timeList(name: string): ListView {
        return root.find(root.named(notes.cardItem, name), child => child instanceof ListView) as ListView;
    }

    function chooseOption(list: ListView, index: int): void {
        list.positionViewAtIndex(index, ListView.Center);
        list.forceLayout();
        root.click(list.itemAtIndex(index));
    }

    function scrollDeadline(): void {
        const hours = root.timeList("noteHourList");
        const minutes = root.timeList("noteMinuteList");
        check.equal("the picker restores only hour and minute",
            surface.mask.item === notes.cardItem && !root.named(notes.cardItem, "noteDeadlineDate")
                && hours?.currentIndex === 9 && minutes?.currentIndex === 30, true);
        if (!hours || !minutes) { check.done(); return; }
        hours.positionViewAtBeginning();
        input.mouseWheel(hours, hours.width / 2, hours.height / 2, Qt.NoButton, Qt.NoModifier, 0, -120, -1);
        const header = root.named(notes.cardItem, "noteHourList");
        input.mouseWheel(header, header.width / 2, 1, Qt.NoButton, Qt.NoModifier, 120, 0, -1);
        root.afterLayout(root.chooseDeadlineTime);
    }

    function chooseDeadlineTime(): void {
        const hours = root.timeList("noteHourList");
        const minutes = root.timeList("noteMinuteList");
        check.equal("scrolling moves the hours without closing the picker or editing the deadline",
            !!hours && hours.contentY > hours.originY && DailyNotes.find(root.editedId).deadline === "2097-04-15T09:30", true);
        if (!hours || !minutes) { check.done(); return; }
        root.chooseOption(minutes, 20);
        check.equal("clicking a minute updates the deadline immediately", DailyNotes.find(root.editedId).deadline, "2097-04-15T09:20");
        input.keyClick(Qt.Key_Backtab, Qt.ShiftModifier, -1);
        check.equal("Shift+Tab moves from minutes to hours", hours.activeFocus, true);
        input.keyClick(Qt.Key_Down, Qt.NoModifier, -1);
        check.equal("keyboard selection saves an hour immediately", DailyNotes.find(root.editedId).deadline, "2097-04-15T10:20");
        const saved = DailyNotes.find(root.editedId);
        check.equal("changing time keeps the task in its original day and category",
            saved.day === notes.day && saved.category === root.category && notes.draft === null, true);
        Overlay.dismissOnEscape();
        const title = root.named(root.editedRow, "noteTitleLabel");
        root.click(title);
        check.equal("a single title click leaves the task and editor unchanged", !root.editedRow.done && notes.draft === null, true);
        input.mouseDoubleClickSequence(title, title.width / 2, title.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
        check.equal("double-clicking the title starts editing without toggling completion",
            !root.editedRow.done && notes.draft?.id === root.editedId, true);
        root.afterLayout(root.editTitle);
    }

    function chooseTimeWhileEditing(): void {
        const title = root.named(root.editedRow, "noteTitle") as TextEdit;
        root.chooseOption(root.timeList("noteHourList"), 18);
        const saved = DailyNotes.find(root.editedId);
        check.equal("changing time during editing preserves the title", saved.title, "new\nx");
        check.equal("changing time during editing retains the date", saved.deadline, "2097-04-15T18:20");
        Overlay.dismissOnEscape();
        check.equal("the picker returns focus to the open title editor", title.activeFocus, true);
        root.afterLayout(root.clickOutside);
    }

    function clickOutside(): void {
        root.click(root.named(root.editedRow, "noteCheckbox"));
        check.equal("clicking the checkbox outside the text closes editing without toggling the task",
            notes.shown && notes.draft === null && !root.editedRow.done, true);
        root.afterLayout(() => {
            check.equal("leaving the editor restores focus to the composer", root.composer.input.activeFocus, true);
            check.equal("clicking outside keeps the autosaved title", DailyNotes.find(root.editedId).title, "new\nx");
            notes.editTask(root.firstId);
            root.afterLayout(root.clickAnotherTask);
        });
    }

    function clickAnotherTask(): void {
        const category = root.find(notes.cardItem, child => child instanceof DailyNoteCategory && child.category === "Personal");
        const destination = root.named(category, "selectNoteDestination");
        input.mousePress(destination, destination.width / 2, destination.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
        check.equal("a press on another category closes editing without waiting for release", notes.draft, null);
        input.mouseRelease(destination, destination.width / 2, destination.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
        check.equal("the dismissal click does not select the other category", notes.targetCategory, root.category);
        root.click(destination);
        check.equal("the next click can explicitly select the category", notes.targetCategory, "Personal");
        notes.selectCategory(root.category);
        notes.editTask(root.firstId);
        root.afterLayout(root.clickOutsidePicker);
    }

    function clickOutsidePicker(): void {
        const badge = root.named(root.row(root.firstId), "noteDeadlineBadge");
        root.openPickerFromKeyboard(badge);
        root.afterLayout(() => {
            input.mouseWheel(notes.cardItem, notes.cardItem.width - 2, 2, Qt.NoButton, Qt.NoModifier, 0, -120, -1);
            check.equal("scrolling on the board background closes only the picker",
                Overlay.menu === null && notes.draft?.id === root.firstId, true);
            root.openPickerFromKeyboard(badge);
            input.mouseClick(notes.cardItem, notes.cardItem.width - 2, 2, Qt.LeftButton, Qt.NoModifier, -1);
            check.equal("one click outside both row and picker closes editing", notes.shown && notes.draft === null
                && Overlay.menu === null, true);
            root.afterLayout(root.dismissWithEscape);
        });
    }

    function dismissWithEscape(): void {
        notes.editTask(root.firstId);
        root.afterLayout(() => {
            const badge = root.named(root.row(root.firstId), "noteDeadlineBadge");
            check.equal("a task without a time offers a visible control", (badge as Clickable).Accessible.name, "Set time");
            root.openPickerFromKeyboard(badge);
            Overlay.dismissOnEscape();
            check.equal("Escape closes the dropdown and returns focus to the title editor",
                Overlay.menu === null && notes.draft?.id === root.firstId && notes.activeEditor?.input.activeFocus, true);
            Overlay.dismissOnEscape();
            check.equal("another Escape closes editing while keeping the board open", notes.shown && notes.draft === null, true);
            notes.editTask(root.firstId);
            root.afterLayout(root.clickTimeOutsideEditor);
        });
    }

    function clickTimeOutsideEditor(): void {
        const badge = root.named(root.row(root.firstId), "noteDeadlineBadge");
        root.click(badge);
        check.equal("the first click on the time badge only closes the text editor",
            notes.draft === null && Overlay.menu === null, true);
        root.click(badge);
        check.equal("the next click opens the time picker", Overlay.menu?.source === badge, true);
        Overlay.dismissOnEscape();
        notes.editTask(root.firstId);
        root.afterLayout(root.clickOtherSurface);
    }

    function clickOtherSurface(): void {
        Overlay.setPointerOver("popup:" + Overlay.dailyNotes, false);
        Overlay.setPointerOver("test-dock", true);
        Overlay.dismissOnOutsideClick();
        Overlay.setPointerOver("test-dock", false);
        check.equal("a press on another shell surface closes editing and keeps the board open",
            notes.shown && notes.draft === null, true);
        const badge = root.named(root.editedRow, "noteDeadlineBadge");
        badge.forceActiveFocus();
        input.keyClick(Qt.Key_Delete, Qt.NoModifier, -1);
        check.equal("Delete on the time badge immediately clears the deadline", DailyNotes.find(root.editedId).deadline, "");
        check.done();
    }

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated runner required", false, "run tools/test.sh DailyNotesEditingTest");
            check.done();
            return;
        }
        ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
            check.equal("daily notes becomes ready", ok, true);
            if (!ok) { check.done(); return; }
            const day = DailyNotes.today;
            DailyNotes.addCategory(day, root.category);
            DailyNotes.addCategory(day, "Personal");
            DailyNotes.save(day, "", "First task", "", root.category);
            root.firstId = DailyNotes.document.notes[0].id;
            DailyNotes.save(day, "", root.wrappedTitle, "2097-04-15T09:30", root.category);
            root.editedId = DailyNotes.document.notes[0].id;
            const screen = Quickshell.screens[0];
            Overlay.open(Overlay.dailyNotes, screen, screen.width / 2);
            root.afterLayout(root.append);
        });
    }
}
