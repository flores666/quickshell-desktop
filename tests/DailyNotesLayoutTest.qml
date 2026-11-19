pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/components"
import "root:/config"
import "root:/services"
import "root:/modules/widgets"

Item {
    id: root

    Check { id: check }
    Until { id: ready }
    readonly property string longCategory: "Research and planning for the next major release"
    readonly property string historyDay: "2001-05-15"
    property string day: DailyNotes.today
    property int viewportWidth: 520
    property bool seeded: false

    PanelWindow {
        screen: Quickshell.screens[0]
        implicitWidth: 520
        implicitHeight: 160
        visible: root.seeded
        WlrLayershell.namespace: "shell-notes-layout-test"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        DailyNotesScroll {
            id: viewport
            width: root.viewportWidth
            height: parent.height
            contentHeight: board.height

            DailyNotesBoard {
                id: board
                width: viewport.contentWidth
                groups: root.day === DailyNotes.today ? DailyNotes.todayChecklist.groups
                    : DailyNotes.checklist(root.day).groups
            }
        }
    }

    Timer {
        id: layout
        property var then
        interval: Appearance.t.popupFade
        onTriggered: check.attempt("checklist layout", layout.then)
    }

    function afterLayout(then: var): void {
        layout.then = then;
        layout.restart();
    }

    function seed(name: string, count: int, title: string): void {
        DailyNotes.addCategory(name);
        for (let i = 0; i < count; ++i)
            DailyNotes.save(DailyNotes.today, "", title, "", "", name);
    }

    function tile(category: string): DailyNoteCategory {
        return board.children.find(item => item instanceof DailyNoteCategory && item.category === category)
            as DailyNoteCategory;
    }

    function lastRow(item: Item): DailyNoteRow {
        if (item instanceof DailyNoteRow)
            return item as DailyNoteRow;
        for (let i = item.children.length - 1; i >= 0; --i) {
            const row = root.lastRow(item.children[i]);
            if (row)
                return row;
        }
        return null;
    }

    function inView(task: DailyNoteRow): bool {
        const y = task.mapToItem(viewport, 0, 0).y;
        return task.activeFocus && y >= 0 && y + task.height <= viewport.height + 0.001;
    }

    function categoryFills(): var {
        return DailyNotes.categories.map(category => root.tile(category).fill);
    }

    function checkPalette(): void {
        const screen = Quickshell.screens[0];
        const theme = Appearance.dark ? "dark" : "light";
        const popupOpacity = Settings.popupOpacity;
        Settings.setOverride("popupOpacity", Tuning.spec.popupOpacity.min);
        for (const mode of ["light", "dark"]) {
            Settings.setTheme(mode);
            Settings.setAccentFollowsWallpaper(false);
            Settings.setAccentColor("#d626ad");
            const accent = Appearance.c.accent.toString();
            const fills = root.categoryFills();
            check.equal(mode + " uses six distinct category colors", new Set(fills.map(fill => fill.toString())).size, 6);
            check.sameColor(mode + " repeats the first color for the seventh category", fills[6], fills[0], 0);
            check.equal(mode + " keeps every category fill translucent", fills.every(fill => fill.a > 0 && fill.a < 1), true);

            const wallpaper = "/nonexistent/notes-palette-" + mode + ".png";
            const background = Appearance.dark ? Settings.backgroundDark : Settings.backgroundLight;
            Settings.setWallpaper(wallpaper);
            Settings.setAccentFollowsWallpaper(true);
            Settings.setBackgroundColor(Appearance.dark ? "#292f33" : "#c7d2e9");
            Backdrop.measure(screen, wallpaper, Backdrop.gauge(screen), {
                width: 1, height: 1, data: new Uint8Array([21, 170, 86, 255])
            });
            check.equal(mode + " uses the sampled desktop accent", Appearance.c.accent.toString() !== accent, true);
            check.equal(mode + " keeps the category tints after desktop colors change",
                root.categoryFills().map(String).join(), fills.map(String).join());
            check.equal(mode + " keeps text readable over a black or white desktop at minimum opacity", fills.every(fill =>
                ["#000000", "#ffffff"].every(backdrop =>
                    Appearance.contrast(Appearance.c.text, Appearance.laid(fill, backdrop, 1)) >= 4.5)), true);
            Settings.setBackgroundColor(background);
        }
        Settings.setWallpaper("");
        Settings.setOverride("popupOpacity", popupOpacity);
        Settings.setTheme(theme);
    }

    function checkPacking(): void {
        const tiles = board.groups.map(group => root.tile(group.category));
        const twoColumns = board.columns === 2;
        const width = twoColumns ? (board.width - board.gap) / 2 : board.width;
        const rightX = width + board.gap;
        check.equal("each tile fits its column", tiles.every(tile => Math.abs(tile.width - width) < 0.001
            && (tile.x === 0 || (twoColumns && Math.abs(tile.x - rightX) < 0.001))), true);
        check.equal("tile tops follow the category order",
            tiles.every((tile, i) => i === 0 || tile.y >= tiles[i - 1].y), true);
        let bottom = 0;
        for (const x of twoColumns ? [0, rightX] : [0]) {
            let nextY = 0;
            for (const tile of tiles.filter(tile => Math.abs(tile.x - x) < 0.001)) {
                check.near(tile.category + " starts at the next position in its column", tile.y, nextY);
                bottom = Math.max(bottom, tile.y + tile.height);
                nextY = tile.y + tile.height + board.gap;
            }
        }
        check.near("the board ends at its lowest tile", board.height, bottom);
    }

    function arranged(): void {
        root.checkPalette();
        const work = root.tile("Work");
        const project = root.tile("Project");
        const personal = root.tile("Personal");
        const errands = root.tile("Errands");
        const study = root.tile("Study");
        const heading = root.tile(root.longCategory);
        const travel = root.tile("Travel");
        check.equal("two columns fit a wide window", board.columns, 2);
        check.near("the first tile starts at the left edge", work.x, 0);
        check.near("the second tile reaches the far edge", project.x + project.width, board.width);
        check.near("the second tile starts at the top", project.y, 0);
        check.equal("both columns leave room for the controls", work.width >= Appearance.m.dailyNotesTileMinimum, true);
        check.equal("project is taller than the first two tiles in the left column",
            project.height > work.height + board.gap + personal.height, true);
        check.near("the third tile uses the shorter column", personal.x, work.x);
        check.near("the fourth tile can use the same column", errands.x, personal.x);
        check.equal("a long category title wraps within its column", heading.height > travel.height, true);
        root.checkPacking();

        const task = root.lastRow(study);
        const wideHeight = task.height;
        check.equal("long task starts outside the viewport", task.mapToItem(viewport, 0, 0).y > viewport.height, true);
        task.forceActiveFocus(Qt.TabFocusReason);
        check.equal("offscreen task takes keyboard focus", task.activeFocus, true);
        root.afterLayout(() => {
            check.equal("focused task scrolls into view", root.inView(task), true);
            root.viewportWidth = 220;
            root.afterLayout(() => root.narrowed(study, task, wideHeight));
        });
    }

    function narrowed(study: DailyNoteCategory, task: DailyNoteRow, wideHeight: real): void {
        check.equal("narrow window uses one column", board.columns, 1);
        root.checkPacking();
        check.equal("long text wraps further in the narrowed tile", task.height > wideHeight, true);
        check.equal("focused task stays visible after reflow", root.inView(task), true);
        root.viewportWidth = 520;
        root.afterLayout(() => root.shorten(study, task));
    }

    function shorten(study: DailyNoteCategory, task: DailyNoteRow): void {
        const originalHeight = study.height;
        check.equal("fixture edit succeeds", DailyNotes.save(DailyNotes.today, task.note.id, "Read", "", "", study.category), true);
        root.afterLayout(() => {
            check.equal("shortening wrapped text shrinks its tile", study.height < originalHeight, true);
            check.equal("editing retains the note and category", root.lastRow(study) === task && study.count === 1, true);
            check.equal("focused task stays visible after editing", root.inView(task), true);
            root.checkPacking();
            root.day = root.historyDay;
            root.afterLayout(root.singleCategory);
        });
    }

    function singleCategory(): void {
        check.equal("history contains one category", board.groups.length, 1);
        check.equal("a lone category can fill a wide board", board.columns, 1);
        root.checkPacking();
        check.done();
    }

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "") {
            check.report("isolated test runner required", false, "run tools/test.sh DailyNotesLayoutTest");
            check.done();
            return;
        }
        ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, ok => {
            check.equal("notes service is ready", ok, true);
            if (!ok) { check.done(); return; }
            root.seed("Work", 2, "Send a note today");
            root.seed("Project", 8, "Send a note today");
            root.seed("Personal", 1, "Send a note today");
            root.seed("Errands", 1, "Send a note today");
            root.seed("Reading", 1, "Send the briefing packet");
            root.seed("Study", 1, "Review the draft release schedule with the team before the meeting");
            DailyNotes.addCategory(root.longCategory);
            DailyNotes.addCategory("Travel");
            DailyNotes.addCategory("Later");
            check.equal("historical task saves", DailyNotes.save(root.historyDay, "", "Archived task", "", "", "Study"), true);
            root.seeded = true;
            root.afterLayout(root.arranged);
        });
    }
}
