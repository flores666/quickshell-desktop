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

    property string taskId
    property point cursor

    Check { id: check }
    TestEvent { id: input }

    OverlaySurface {
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

    function items(item: Item, matches: var): var {
        const found = matches(item) ? [item] : [];
        for (const child of item.children)
            found.push(...root.items(child, matches));
        return found;
    }

    function named(name: string): var {
        return root.items(notes.cardItem, child => child.objectName === name);
    }

    function menuItem(label: string): Item {
        return root.items(notes.cardItem, child => child instanceof MenuItemRow && child.label === label)[0] ?? null;
    }

    function click(item: Item, button: int): void {
        const x = Math.floor(item.width / 2);
        const y = Math.floor(item.height / 2);
        if (button === Qt.RightButton)
            root.cursor = item.mapToItem(null, x, y);
        input.mouseClick(item, x, y, button, Qt.NoModifier, -1);
    }

    function checkAbove(label: string, item: Item): void {
        const bottom = item?.mapToItem(null, 0, item.height).y ?? Infinity;
        check.within(label, root.cursor.y - bottom, Appearance.s.xs * 2, 1);
    }

    function taskMenu(): void {
        root.click(root.named("noteTitleLabel")[0], Qt.RightButton);
        root.afterLayout(() => {
            root.checkAbove("the task context menu opens above the cursor", root.menuItem("Delete"));
            Overlay.dismissOnEscape();
            root.click(root.named("taskAnnotation")[1], Qt.RightButton);
            root.afterLayout(root.editMenu);
        });
    }

    function editMenu(): void {
        const edit = root.menuItem("Edit note");
        check.equal("right-click on the second note opens its own menu", edit?.visible, true);
        root.checkAbove("the note context menu opens above the cursor", root.menuItem("Delete note"));
        if (!edit) { check.done(); return; }
        root.click(edit, Qt.LeftButton);
        root.afterLayout(root.editNote);
    }

    function editNote(): void {
        const field = root.named("taskAnnotationInput")[0] as TextEdit;
        if (!field) { check.report("edit field appears", false, "missing"); check.done(); return; }
        check.equal("the selected note takes focus in its inline editor",
            field.activeFocus && field.text === "Duplicate" && Overlay.menu === null, true);
        field.text = "";
        input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
        check.equal("an empty edit leaves the original note and keeps the editor open",
            DailyNotes.find(root.taskId).annotations[1] === "Duplicate" && notes.draft !== null, true);
        field.text = "Updated second";
        check.equal("editing affects only the selected copy", JSON.stringify(DailyNotes.find(root.taskId).annotations),
            '["Duplicate","Updated second","Keep me"]');
        field.cursorPosition = field.length;
        input.keyClick(Qt.Key_Return, Qt.ShiftModifier, -1);
        input.keyClick(Qt.Key_X, Qt.NoModifier, -1);
        check.equal("Shift+Enter adds a line and keeps the inline editor focused",
            field.activeFocus && DailyNotes.find(root.taskId).annotations[1] === "Updated second\nx", true);
        field.text = "Updated second";
        input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
        check.equal("Enter finishes note editing", notes.draft, null);
        root.afterLayout(root.doubleClickNote);
    }

    function doubleClickNote(): void {
        const label = root.named("taskAnnotation")[1];
        input.mouseDoubleClickSequence(label, label.width / 2, label.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
        root.afterLayout(() => {
            const field = root.named("taskAnnotationInput")[0] as TextEdit;
            check.equal("double-clicking a note opens its inline editor",
                field?.activeFocus && field.text === "Updated second", true);
            root.click(root.named("noteCheckbox")[0], Qt.LeftButton);
            check.equal("the first click outside note text only closes editing",
                notes.draft === null && !DailyNotes.find(root.taskId).done, true);
            root.afterLayout(root.deleteMenu);
        });
    }

    function deleteMenu(): void {
        root.click(root.named("taskAnnotation")[0], Qt.RightButton);
        root.afterLayout(() => {
            const remove = root.menuItem("Delete note");
            if (!remove) { check.report("delete menu appears", false, "missing"); check.done(); return; }
            root.click(remove, Qt.LeftButton);
            const saved = DailyNotes.find(root.taskId);
            check.equal("deleting a note preserves the other notes in order", JSON.stringify(saved.annotations),
                '["Updated second","Keep me"]');
            check.equal("deleting a note preserves the task itself",
                saved.title === "Prepare the release" && !saved.done && saved.deadline === "", true);
            check.equal("the view reflects the deletion", root.named("taskAnnotation").map(label => label.text).join(","),
                "Updated second,Keep me");
            check.equal("the delete action dismisses the menu", Overlay.menu, null);
            root.afterLayout(root.keyboardMenu);
        });
    }

    function keyboardMenu(): void {
        const note = root.items(notes.cardItem, child => child instanceof Clickable && child.Accessible.name === "Keep me")[0] as Clickable;
        if (!note) { check.report("note action button exists", false, "missing"); check.done(); return; }
        note.forceActiveFocus(Qt.TabFocusReason);
        input.keyClick(Qt.Key_Menu, Qt.NoModifier, -1);
        check.equal("keyboard opens the note menu with the note as anchor",
            Overlay.menu?.source === note && Overlay.menu.scenePosition === undefined, true);
        Overlay.dismissOnEscape();
        check.equal("dismissing the keyboard menu restores note focus", note.activeFocus, true);
        root.openAddMenu(root.typeNewNote);
    }

    function openAddMenu(then: var): void {
        root.click(root.named("noteTitleLabel")[0], Qt.RightButton);
        root.afterLayout(() => {
            const add = root.menuItem("Add note");
            if (!add) { check.report("add note menu item appears", false, "missing"); check.done(); return; }
            root.click(add, Qt.LeftButton);
            root.afterLayout(then);
        });
    }

    function typeNewNote(): void {
        const field = root.named("taskAnnotationInput")[0] as TextEdit;
        if (!field) { check.report("new inline note appears", false, "missing"); check.done(); return; }
        const last = root.named("taskAnnotation").filter(label => label.visible).pop();
        const position = field.mapToItem(last, 0, 0);
        check.equal("adding a note focuses an empty placeholder after the last note with no popup",
            field.activeFocus && field.text === "" && Overlay.menu === null
                && position.y >= last.height && Math.abs(position.x) < 1, true);
        check.equal("an empty placeholder is not persisted", DailyNotes.find(root.taskId).annotations.length, 2);
        check.equal("the annotation editor adds no time control", root.named("noteDeadlineBadge").length, 1);
        input.keyClick(Qt.Key_A, Qt.NoModifier, -1);
        input.keyClick(Qt.Key_B, Qt.NoModifier, -1);
        check.equal("the first keys append one note and keep the same field focused",
            field.activeFocus && root.named("taskAnnotationInput")[0] === field
                && DailyNotes.find(root.taskId).annotations.join(",") === "Updated second,Keep me,ab", true);
        field.selectAll();
        input.keyClick(Qt.Key_Backspace, Qt.NoModifier, -1);
        check.equal("erasing a new note removes its autosave and keeps its placeholder focused",
            field.activeFocus && root.named("taskAnnotationInput")[0] === field
                && DailyNotes.find(root.taskId).annotations.join(",") === "Updated second,Keep me", true);
        field.text = "Retyped note";
        input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
        check.equal("retyping the same draft adds just one note", DailyNotes.find(root.taskId).annotations.join(","),
            "Updated second,Keep me,Retyped note");
        root.afterLayout(() => root.openAddMenu(root.acceptBlankNote));
    }

    function acceptBlankNote(): void {
        const field = root.named("taskAnnotationInput")[0] as TextEdit;
        field.text = "   ";
        input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
        check.equal("Enter closes a whitespace-only placeholder without adding a note",
            notes.draft === null && DailyNotes.find(root.taskId).annotations.length === 3, true);
        root.afterLayout(() => root.openAddMenu(root.dismissErasedNote));
    }

    function dismissErasedNote(): void {
        const field = root.named("taskAnnotationInput")[0] as TextEdit;
        field.text = "Temporary note";
        field.text = " ";
        root.click(root.named("noteCheckbox")[0], Qt.LeftButton);
        check.equal("dismissing a cleared new note leaves no note behind",
            notes.draft === null && DailyNotes.find(root.taskId).annotations.length === 3, true);
        root.afterLayout(() => root.openAddMenu(root.dismissBlankNote));
    }

    function dismissBlankNote(): void {
        Overlay.dismissOnEscape();
        check.equal("dismissing an empty placeholder leaves no note behind",
            notes.draft === null && DailyNotes.find(root.taskId).annotations.length === 3, true);
        root.checkEdgePlacement();
    }

    function checkEdgePlacement(): void {
        const card = notes.cardItem;
        const cursor = card.mapToItem(null, card.width - 2, 2);
        Overlay.openMenu(card, [{ label: "Edge menu", run: () => {} }], cursor);
        root.afterLayout(() => {
            const row = root.menuItem("Edge menu");
            const topRight = row?.mapToItem(card, row.width, 0);
            check.equal("a menu at the top falls below the cursor and stays within the right edge",
                !!topRight && topRight.y > 2 && topRight.x < card.width, true);
            check.done();
        });
    }

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "" || !DailyNotes.ready) {
            check.report("isolated runner and ready service required", false, "run tools/test.sh DailyNotesAnnotationTest");
            check.done();
            return;
        }
        const day = DailyNotes.today;
        DailyNotes.addCategory(day, "Work");
        DailyNotes.save(day, "", "Prepare the release", "", "Work");
        root.taskId = DailyNotes.document.notes[0].id;
        for (const text of ["Duplicate", "Duplicate", "Keep me"]) {
            const entries = DailyNotes.find(root.taskId).annotations;
            DailyNotes.saveAnnotation(root.taskId, entries, entries?.length ?? 0, text);
        }
        const screen = Quickshell.screens[0];
        Overlay.open(Overlay.dailyNotes, screen, screen.width / 2);
        root.afterLayout(root.taskMenu);
    }
}
