pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"

ShellOverlay {
    id: root

    overlayId: Overlay.dailyNotes
    placement: ShellOverlay.Placement.AboveDock
    cardWidth: Math.min(Appearance.m.dailyNotesWidth,
        root.screen ? root.screen.width - Appearance.s.md * 2 : Appearance.m.dailyNotesWidth)
    cardHeight: Math.max(0, Math.min(root.height, Math.ceil(header.implicitHeight + root.bodyGap
        + root.bodyHeight + status.height + Appearance.s.xl * 2)))
    initialFocusItem: entry.input
    glassCutouts: root.rendered && list.visible && board.keys.length > 0 ? cutouts : null
    readonly property Component cutouts: Component {
        DailyNotesCutouts {
            notesBoard: board
            viewport: list.viewport
            origin: Qt.point(contents.x + body.x + list.x, contents.y + body.y + list.y)
        }
    }

    property string selectedDay: ""
    property var draft: null
    property DailyNoteEditor activeEditor: null

    readonly property string day: root.draft?.day ?? (root.selectedDay || DailyNotes.today)
    readonly property var days: [...new Set([...DailyNotes.days, DailyNotes.today, root.day])].sort()
    readonly property int dayIndex: root.days.indexOf(root.day)
    readonly property string targetCategory: root.rendered ? DailyNotes.targetCategory(root.day) : ""
    readonly property var focusedCategory: root.rendered && root.draft === null
        && entry.text !== "" && root.targetCategory !== "" ? root.targetCategory : null
    readonly property var boardGroups: !root.rendered ? []
        : (root.day === DailyNotes.today ? DailyNotes.todayChecklist : DailyNotes.checklist(root.day)).groups
    readonly property bool showEmpty: root.boardGroups.length === 0 && DailyNotes.error === ""
    readonly property real bodyHeight: root.showEmpty ? empty.implicitHeight : board.resting.height
    readonly property int bodyGap: root.bodyHeight > 0 ? Appearance.s.lg : 0
    readonly property bool canAdd: root.shown && DailyNotes.ready && Overlay.menu === null
        && root.draft === null && root.targetCategory !== "" && entry.text.trim() !== ""

    onShownChanged: if (root.shown) {
        toolbar.categoryEntryOpen = false;
        root.draft = null;
        entry.text = "";
        root.showDay(DailyNotes.today);
    }
    onRenderedChanged: if (!root.rendered) {
        toolbar.categoryEntryOpen = false;
        root.draft = null;
    }
    onDayChanged: if (root.rendered) {
        if (root.shown && Overlay.menu !== null)
            Overlay.closeMenu();
        root.cancelCategoryEntry();
        list.reset();
        Qt.callLater(root.revealCategory);
    }
    onFocusedCategoryChanged: Qt.callLater(root.revealCategory)

    function focusTask(): void {
        if (root.shown && Overlay.menu === null)
            (root.draft ? root.activeEditor?.input : entry.input)?.forceActiveFocus();
    }

    function cancelCategoryEntry(): bool {
        if (!root.shown || !toolbar.categoryEntryOpen)
            return false;
        toolbar.categoryEntryOpen = false;
        root.focusTask();
        return true;
    }

    function showDay(day: string): void {
        root.finishEdit();
        root.selectedDay = day === DailyNotes.today ? "" : day;
        list.reset();
        root.focusTask();
        Qt.callLater(root.revealCategory);
    }

    function selectCategory(category: string): void {
        DailyNotes.selectCategory(root.day, category);
        root.focusTask();
    }

    function revealCategory(): void {
        const box = board.resting.boxes.get(root.focusedCategory);
        if (root.shown && list.visible && box)
            list.revealBounds(box.y, box.height * Appearance.m.dailyNotesFocusScale);
    }

    function deleteCategory(category: string): void {
        if (!root.shown || !DailyNotes.ready || root.draft || Overlay.menu !== null)
            return;
        if (DailyNotes.removeCategory(root.day, category))
            root.focusTask();
    }

    function addTask(): void {
        if (root.canAdd && DailyNotes.save(root.day, "", entry.text, "", root.targetCategory)) {
            entry.text = "";
            root.focusTask();
        }
    }

    function presentAddedTask(day: string, category: string, id: string): void {
        if (!root.shown || root.day !== day)
            return;
        const tile = board.tiles.get(category) as DailyNoteCategory;
        const row = tile?.showAddedTask(id);
        // A compact popup is still growing to fit the row. Scroll only at the screen limit.
        if (row && root.cardHeight >= root.height) {
            const top = row.mapToItem(list.viewport.contentItem, 0, 0).y;
            list.revealBounds(top, row.height * tile.layoutScale);
        }
    }

    function editTask(id: string, index: var): void {
        if (!root.shown || !DailyNotes.ready || root.draft || Overlay.menu !== null)
            return;
        const note = DailyNotes.find(id);
        if (!note || note.day !== root.day || index > (note.annotations?.length ?? 0))
            return;
        toolbar.categoryEntryOpen = false;
        const annotation = index >= 0 ? { snapshot: note.annotations, index } : null;
        root.draft = { id, day: note.day, annotation, text: annotation ? note.annotations?.[index] ?? "" : note.title };
    }

    function finishEdit(): bool {
        if (!root.draft)
            return false;
        if (root.shown && Overlay.menu !== null)
            Overlay.closeMenu();
        root.draft = null;
        Qt.callLater(root.focusTask);
        return true;
    }

    function dismissInlineOutside(scenePosition: point): bool {
        if (toolbar.categoryEntryOpen && !toolbar.containsCategoryEntry(scenePosition))
            root.cancelCategoryEntry();
        const input = root.activeEditor?.input;
        const viewport = list.viewport;
        if (root.draft === null || (input && input.contains(input.mapFromItem(null, scenePosition))
                && viewport.contains(viewport.mapFromItem(null, scenePosition))))
            return false;
        InputMode.pointerUsed();
        return root.finishEdit();
    }

    // Stay enabled through release when this press closes the editor.
    MouseArea {
        parent: root.cardItem
        anchors.fill: parent
        z: 1
        enabled: root.shown && Overlay.menu === null
        acceptedButtons: Qt.AllButtons
        preventStealing: true
        onPressed: mouse => mouse.accepted = root.dismissInlineOutside(root.cardItem.mapToItem(null, mouse.x, mouse.y))
    }
    Connections {
        target: root.cardItem
        function onMenuBackgroundPressed(scenePosition: point): void {
            root.dismissInlineOutside(scenePosition);
        }
    }

    Component {
        id: rowEditor
        DailyNoteEditor {
            id: editor

            draft: root.draft
            onFinished: root.finishEdit()
            Component.onCompleted: {
                root.activeEditor = editor;
                Qt.callLater(root.focusTask);
            }
        }
    }

    Connections {
        target: Overlay
        function onOutsideCardPressed(): void {
            if (root.shown && !root.cancelCategoryEntry())
                root.finishEdit();
        }
        function onEscapeRequested(request: var): void {
            if (root.shown && (root.cancelCategoryEntry() || root.finishEdit()))
                request.accepted = true;
        }
    }

    Connections {
        target: DailyNotes
        function onTaskAdded(day: string, category: string, id: string): void {
            if (root.shown && root.day === day)
                Qt.callLater(root.presentAddedTask, day, category, id);
        }
        function onDocumentChanged(): void {
            if (root.draft && !DailyNotes.find(root.draft.id))
                root.finishEdit();
        }
    }

    Connections {
        target: Settings
        function onDailyNotesEnabledChanged(): void {
            if (root.shown && !Settings.dailyNotesEnabled)
                Overlay.close();
        }
    }

    Item {
        id: contents
        anchors.fill: parent
        anchors.margins: Appearance.s.xl
        enabled: root.shown

        Column {
            id: header
            width: parent.width
            spacing: Appearance.s.md

            DailyNotesToolbar {
                id: toolbar

                width: header.width
                day: root.day
                canGoBack: root.dayIndex > 0
                canGoForward: root.dayIndex + 1 < root.days.length
                actionsEnabled: root.draft === null && Overlay.menu === null
                onCategoryAdded: root.focusTask()
                onPreviousDay: root.showDay(root.days[root.dayIndex - 1])
                onNextDay: root.showDay(root.days[root.dayIndex + 1])
            }

            Divider { width: header.width }

            DailyNoteComposer {
                id: entry
                objectName: "quickNote"
                width: header.width
                enabled: DailyNotes.ready && root.draft === null
                canSave: root.canAdd
                destinationName: root.targetCategory
                destinationHint: DailyNotes.boardFor(root.day).categories.length === 0 ? qsTr("Create a category") : ""
                input.Accessible.description: entry.destinationName === "" ? entry.destinationHint
                    : qsTr("Adds to %1").arg(entry.destinationName)
                onAccepted: root.addTask()
            }
        }

        Item {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.topMargin: root.bodyGap
            anchors.bottom: status.top

            DailyNotesScroll {
                id: list
                anchors.fill: parent
                leftGutter: Appearance.s.xl
                rightGutter: Appearance.s.lg
                bottomGutter: status.text === "" ? Appearance.s.xl : 0
                contentHeight: Math.max(board.height + bottomGutter, board.contentHeight)
                dragPoint: board.dragPoint
                onContentMoved: board.refreshDrag()

                DailyNotesBoard {
                    id: board
                    x: list.leftGutter
                    width: list.contentWidth
                    glass: root.cardItem.glass
                    groups: root.boardGroups
                    destinationCategory: root.targetCategory
                    focusedCategory: root.focusedCategory
                    day: root.day
                    dragViewport: list
                    draft: root.draft
                    taskEditor: rowEditor
                    reorderEnabled: root.shown && root.draft === null && Overlay.menu === null
                    onSelectRequested: category => root.selectCategory(category)
                    onEditRequested: (id, index) => root.editTask(id, index)
                    onDeleteRequested: category => root.deleteCategory(category)
                }
            }

            Label {
                id: empty
                anchors.centerIn: parent
                visible: root.showEmpty
                muted: true
                text: DailyNotes.ready ? qsTr("No tasks for this day") : qsTr("Loading…")
            }
        }

        Label {
            id: status
            anchors.bottom: parent.bottom
            width: parent.width
            visible: text !== ""
            height: text === "" ? 0 : implicitHeight + Appearance.s.sm
            text: DailyNotes.error
            color: PopupStyle.danger
            role: Label.Role.Small
        }
    }
}
