pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"
import "root:/modules/widgets"

Item {
    id: root

    Check { id: check }
    TestEvent { id: input }
    Until { id: ready }

    OverlaySurface {
        id: surface
        DailyNotesPanel { id: notes }
    }

    readonly property InputField entry: root.named("quickNote") as InputField
    readonly property Label destination: root.named("quickNoteDestination") as Label
    readonly property DailyNotesBoard board: root.find(notes.cardItem, item => item instanceof DailyNotesBoard) as DailyNotesBoard
    property int compactHeight: 0
    property var unscaledBoxes: []
    property real unscaledBoardHeight: 0
    Timer {
        id: settle
        property var then
        interval: Appearance.t.popupFade + Appearance.t.popupResize + Appearance.t.grace
        onTriggered: settle.then()
    }
    function afterLayout(then: var): void {
        settle.then = then;
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
    function named(name: string): Item {
        return root.find(notes.cardItem, item => item.objectName === name);
    }
    function tile(category: string): DailyNoteCategory {
        return root.find(notes.cardItem, item => item instanceof DailyNoteCategory && item.category === category) as DailyNoteCategory;
    }
    function action(category: string, name: string): Item {
        return root.find(root.tile(category), item => item.objectName === name);
    }
    function click(item: Item): void {
        input.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
    }
    function paintedScale(card: Item): real {
        return (card.mapToItem(root.board, card.width, 0).x - card.mapToItem(root.board, 0, 0).x) / card.width;
    }
    function boxes(): var {
        return root.board.groups.map(group => {
            const card = root.tile(group.category);
            return [card.category, card.x, card.y, card.width, card.height];
        });
    }
    function emptyBoard(): void {
        check.equal("a fresh board is empty and asks for a category",
            root.board.keys.length === 0 && root.destination.text === "Create a category", true);
        root.entry.text = "First task";
        input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
        check.equal("Return without a category only preserves the draft",
            root.entry.text === "First task" && DailyNotes.document.notes.length === 0, true);
        const add = root.named("newNoteCategory") as IconButton;
        root.click(add);
        Qt.callLater(() => {
            const name = root.named("newNoteCategoryName") as InputField;
            check.equal("the toolbar opens an inline field without a menu", name.input.activeFocus && Overlay.menu === null, true);
            check.equal("the plus becomes an inactive confirmation while empty", add.icon === "check" && !add.enabled, true);
            name.text = "Inbox";
            input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
            check.equal("the retired category name cannot be created", !add.enabled && root.board.keys.length === 0, true);
            name.text = "Project 0";
            root.click(add);
            check.equal("clicking the same button creates the category and restores the plus",
                root.board.keys.join(",") === "Project 0" && add.icon === "add" && root.entry.input.activeFocus, true);
            check.equal("creating the first category selects it", notes.targetCategory, "Project 0");
            check.equal("the first category is shown as the destination", root.destination.text, "To Project 0");
            root.afterLayout(() => {
                check.equal("the first category's target is accented", (root.action("Project 0", "selectNoteDestination") as IconButton).accented, true);
                input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
                const first = DailyNotes.document.notes[0];
                check.equal("the automatically selected category accepts the retained draft",
                    first?.title === "First task" && first.category === "Project 0", true);
                if (first) DailyNotes.toggleDone(first.id);
                for (const category of ["Project 2", "Project 1"]) DailyNotes.addCategory(notes.day, category);
                root.afterLayout(root.start);
            });
        });
    }
    function start(): void {
        check.equal("quick entry has no category dropdown", root.named("quickNoteCategory"), null);
        check.equal("the main notes card has no Clear All action", root.named("clearAllNotes"), null);
        check.equal("input is confined to the notes card", surface.mask.item, notes.cardItem);
        check.equal("the chosen category remains selected after adding and completing a task", root.destination.text, "To Project 0");
        check.equal("task entry has the requested placeholder", root.entry.placeholder, "Type to add new task");
        check.equal("the destination label is muted", root.destination.muted, true);
        check.equal("compact content leaves screen room", notes.cardHeight < notes.height, true);
        root.compactHeight = notes.cardHeight;
        check.equal("category cards have no add button", root.named("addNoteInCategory"), null);
        const target = root.action("Project 2", "selectNoteDestination") as IconButton;
        check.equal("card, header and target use the default arrow", [root.tile("Project 2"),
            root.action("Project 2", "dragNoteCategory") as Clickable, target].every(control => control.cursorShape === Qt.ArrowCursor), true);
        root.click(target);
        Overlay.close();
        root.afterLayout(() => {
            Overlay.open(Overlay.dailyNotes, Overlay.screen, Overlay.anchorXOf[Overlay.dailyNotes]);
            root.afterLayout(root.emptySelected);
        });
    }
    function emptySelected(): void {
        check.equal("reopening preserves the category selected with an empty draft", notes.targetCategory, "Project 2");
        check.equal("the static destination label follows selection", root.destination.text, "To Project 2");
        check.equal("only the chosen target is accented", (root.action("Project 2", "selectNoteDestination") as IconButton).accented
            && !(root.action("Project 0", "selectNoteDestination") as IconButton).accented, true);
        check.equal("empty entry has no scaled destination", root.board.focusedCategory, null);
        check.near("chosen card stays unscaled before typing", root.paintedScale(root.tile("Project 2")), 1);
        check.near("other cards stay unscaled before typing", root.paintedScale(root.tile("Project 1")), 1);
        root.unscaledBoxes = root.boxes();
        root.unscaledBoardHeight = root.board.height;
        input.keyClick(Qt.Key_K, Qt.NoModifier, -1);
        root.afterLayout(root.selected);
    }
    function selected(): void {
        check.equal("the first key leaves card geometry unchanged", JSON.stringify(root.boxes()), JSON.stringify(root.unscaledBoxes));
        check.near("typing leaves board height unchanged", root.board.height, root.unscaledBoardHeight);
        check.equal("typing leaves popup height unchanged", notes.cardHeight, root.compactHeight);
        check.equal("the board follows the selected destination", root.board.focusedCategory, "Project 2");
        check.equal("the selected card grows", root.paintedScale(root.tile("Project 2")) > 1, true);
        check.equal("other cards shrink", root.paintedScale(root.tile("Project 1")) < 1, true);
        check.equal("typing reaches the focused task input", root.entry.text.toLowerCase() === "k" && root.entry.input.activeFocus, true);
        root.entry.text = "Keep my typed draft";
        root.click(root.action("Project 2", "dragNoteCategory"));
        root.afterLayout(() => {
            check.equal("choosing the same card keeps the selection", notes.targetCategory, "Project 2");
            check.equal("typing still scales the selected destination", root.board.focusedCategory, "Project 2");
            root.click(root.action("Project 1", "dragNoteCategory"));
            root.afterLayout(() => {
                check.equal("the bottom card scales in place", root.paintedScale(root.tile("Project 1")) > 1, true);
                check.near("zooming the bottom card keeps the popup height", notes.cardHeight, root.compactHeight);
                input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
                check.equal("Enter saves in the selected category", DailyNotes.document.notes[0].category, "Project 1");
                check.equal("successful save clears only the task text", root.entry.text, "");
                root.createCategory();
            });
        });
    }
    function createCategory(): void {
        root.entry.text = "Category task";
        const add = root.named("newNoteCategory") as IconButton;
        const anchor = add.mapToItem(notes.cardItem, 0, 0);
        root.click(add);
        root.afterLayout(() => {
            const name = root.named("newNoteCategoryName") as InputField;
            const at = name.mapToItem(notes.cardItem, 0, 0);
            check.equal("the name slides out to the left of the fixed toolbar button",
                at.x + name.width < anchor.x && at.y === anchor.y && add.mapToItem(notes.cardItem, 0, 0) === anchor, true);
            check.equal("the category placeholder and typed text use muted ink",
                name.placeholderColor === Appearance.c.textMuted && name.input.color === Appearance.c.textMuted, true);
            root.click(name);
            check.equal("clicking inside the category field keeps it open", name.enabled && name.input.activeFocus, true);
            name.text = "Do not add";
            root.click(root.entry);
            check.equal("clicking outside retracts the category field without creating it",
                !name.enabled && add.icon === "add" && root.entry.input.activeFocus
                    && !DailyNotes.boardFor(notes.day).categories.includes("Do not add"), true);
            root.click(add);
            name.text = "Discard me";
            Overlay.dismissOnEscape();
            check.equal("Escape retracts the field and returns focus to the task draft",
                notes.shown && root.entry.input.activeFocus && !DailyNotes.boardFor(notes.day).categories.includes(name.text), true);
            root.click(add);
            check.equal("reopening resets the category name", name.text, "");
            name.text = "  Work  ";
            input.keyClick(Qt.Key_Enter, Qt.KeypadModifier, -1);
            check.equal("Enter creates the trimmed category without changing destination", DailyNotes.boardFor(notes.day).categories.includes("Work")
                && DailyNotes.boardFor(notes.day).quickCategory === "Project 1" && root.destination.text === "To Project 1", true);
            check.equal("creation restores task draft and focus", Overlay.menu === null
                && root.entry.text === "Category task" && root.entry.input.activeFocus, true);
            root.afterLayout(() => {
                root.click(root.action("Work", "dragNoteCategory"));
                input.keyClick(Qt.Key_Return, Qt.NoModifier, -1);
                check.equal("explicitly choosing the new category routes the task", DailyNotes.document.notes[0].category, "Work");
                root.afterLayout(root.deleteEmpty);
            });
        });
    }
    function deleteEmpty(): void {
        root.entry.text = "Keep my typed draft";
        root.click(root.action("Project 2", "dragNoteCategory"));
        root.click(root.action("Project 2", "deleteNoteCategory"));
        check.equal("one click removes an empty category", DailyNotes.boardFor(notes.day).categories.includes("Project 2"), false);
        check.equal("category deletion has no confirmation", Overlay.menu, null);
        check.equal("deleting a chosen category returns to the last addition", notes.targetCategory, "Work");
        check.equal("deletion keeps the draft and task focus", root.entry.text === "Keep my typed draft"
            && root.entry.input.activeFocus, true);
        const day = "2024-06-01";
        for (const category of ["Work", "Project 1"]) DailyNotes.addCategory(day, category);
        DailyNotes.save(day, "", "Older Work task", "", "Work");
        const id = DailyNotes.document.notes[0].id;
        notes.showDay(day);
        root.afterLayout(() => {
            root.click(root.action("Work", "deleteNoteCategory"));
            check.equal("one click removes only this date's category tasks",
                DailyNotes.forDay(day).length === 0 && DailyNotes.forDay(DailyNotes.today).some(note => note.category === "Work"), true);
            check.equal("the board shows its own remaining categories without today's destination",
                root.board.keys.join(",") === "Project 1" && notes.targetCategory === "", true);
            check.equal("deletion preserves the current date", notes.day, day);
            check.equal("the emptied date remains navigable", notes.days.includes(day), true);
            check.equal("the deleted historical task no longer resolves", DailyNotes.find(id), null);
            root.editTask();
        });
    }
    function editTask(): void {
        DailyNotes.addCategory(notes.day, "Other category");
        DailyNotes.save(notes.day, "", "Keep editing", "", "Project 1");
        const id = DailyNotes.document.notes[0].id;
        notes.editTask(id);
        root.afterLayout(() => {
            const title = root.named("noteTitle") as TextEdit;
            input.keyClick(Qt.Key_End, Qt.NoModifier, -1);
            input.keyClick(Qt.Key_Period, Qt.NoModifier, -1);
            DailyNotes.removeCategory(notes.day, "Other category");
            check.equal("unrelated category deletion preserves the edited task and its focus", notes.draft?.id === id
                && DailyNotes.find(id)?.title === "Keep editing." && title.activeFocus, true);
            check.equal("editing preserves the task's category", DailyNotes.find(id)?.category, "Project 1");
            root.removeEditedTask();
        });
    }

    function removeEditedTask(): void {
        DailyNotes.removeCategory(notes.day, "Project 1");
        check.equal("removed edited task releases its stale draft", notes.draft, null);
        root.afterLayout(() => {
            check.equal("removing an edited task restores the composer's draft and focus", Overlay.menu === null && notes.shown
                && root.entry.input.activeFocus && root.entry.text === "Keep my typed draft", true);
            notes.showDay(DailyNotes.today);
            root.afterLayout(root.grow);
        });
    }

    function grow(): void {
        root.compactHeight = notes.cardHeight;
        DailyNotes.addCategory(notes.day, "Long category");
        const text = "Review the release plan and complete all remaining documentation before the meeting. ".repeat(8);
        for (let i = 0; i < 24; ++i)
            DailyNotes.save(notes.day, "", text + i, "", "Long category");
        root.afterLayout(() => {
            check.equal("task content grows the popup", notes.cardHeight > root.compactHeight, true);
            check.near("overflow is capped only at available screen height", notes.cardHeight, notes.height);
            const scroll = root.find(notes.cardItem, item => item instanceof DailyNotesScroll && item.visible) as DailyNotesScroll;
            check.equal("screen-limited content remains scrollable", scroll.contentHeight > scroll.height, true);
            const top = notes.cardItem.mapToItem(notes, 0, 0).y;
            check.equal("the capped card remains inside the available screen", top >= -0.001
                && top + notes.cardItem.height <= notes.height + 0.001, true);
            DailyNotes.removeCategory(notes.day, "Long category");
            root.afterLayout(() => {
                check.near("shrinking restores the content height", notes.cardHeight, root.compactHeight);
                check.done();
            });
        });
    }
    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated runner required", false, "run tools/test.sh DailyNotesCategoryPopupTest");
            check.done();
            return;
        }
        ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
            check.equal("daily notes becomes ready", ok, true);
            if (!ok) { check.done(); return; }
            const screen = Quickshell.screens[0];
            Overlay.open(Overlay.dailyNotes, screen, screen.width / 2);
            root.afterLayout(root.emptyBoard);
        });
    }
}
