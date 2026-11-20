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
    property string editCategory: ""
    property var draft: null

    readonly property string day: root.draft?.day ?? (root.selectedDay || DailyNotes.today)
    readonly property bool notesMenuOpen: Overlay.menu?.content === categoryPicker
    readonly property Item taskInput: root.draft ? (editor.item as DailyNoteEditor)?.input ?? null : entry.input
    readonly property var days: [...new Set([...DailyNotes.days, DailyNotes.today, root.day])].sort()
    readonly property int dayIndex: root.days.indexOf(root.day)
    readonly property string targetCategory: root.rendered ? DailyNotes.targetCategory(root.day) : ""
    readonly property var focusedCategory: root.rendered && root.draft === null
        && entry.text !== "" && root.targetCategory !== "" ? root.targetCategory : null
    readonly property var boardGroups: !root.rendered ? []
        : (root.day === DailyNotes.today ? DailyNotes.todayChecklist : DailyNotes.checklist(root.day)).groups
    readonly property bool showEmpty: root.draft === null && root.boardGroups.length === 0 && DailyNotes.error === ""
    readonly property real bodyHeight: root.draft !== null ? editor.implicitHeight
        : root.showEmpty ? empty.implicitHeight : board.resting.height
    readonly property int bodyGap: root.bodyHeight > 0 ? Appearance.s.lg : 0
    readonly property bool canAdd: root.shown && DailyNotes.ready && !root.notesMenuOpen
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
        if (root.notesMenuOpen)
            Overlay.closeMenu();
        root.cancelCategoryEntry();
        list.reset();
        Qt.callLater(root.revealCategory);
    }
    onFocusedCategoryChanged: Qt.callLater(root.revealCategory)

    function focusTask(): void {
        if (root.shown && !root.notesMenuOpen)
            root.taskInput?.forceActiveFocus();
    }

    function cancelCategoryEntry(): bool {
        if (!root.shown || !toolbar.categoryEntryOpen)
            return false;
        toolbar.categoryEntryOpen = false;
        root.focusTask();
        return true;
    }

    function showDay(day: string): void {
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

    function openCategoryPicker(anchor: Item): void {
        if (root.shown && root.draft && DailyNotes.ready)
            Overlay.openMenuContent(anchor, categoryPicker, root.taskInput);
    }

    function deleteCategory(category: string): void {
        if (!root.shown || !DailyNotes.ready || root.draft || root.notesMenuOpen)
            return;
        if (DailyNotes.removeCategory(root.day, category))
            root.focusTask();
    }

    function addTask(): void {
        if (root.canAdd && DailyNotes.save(root.day, "", entry.text, "", "", root.targetCategory)) {
            entry.text = "";
            root.focusTask();
        }
    }

    function editTask(id: string): void {
        if (!root.shown || !DailyNotes.ready || root.notesMenuOpen)
            return;
        const note = DailyNotes.find(id);
        if (!note || note.day !== root.day)
            return;
        toolbar.categoryEntryOpen = false;
        root.editCategory = note.category;
        editList.reset();
        root.draft = note;
    }

    Component {
        id: categoryPicker

        DailyNoteCategoryPicker {
            day: root.draft?.day ?? ""
            category: root.editCategory
            onSelected: category => {
                root.editCategory = category;
                Overlay.closeMenu();
            }
        }
    }

    Connections {
        target: Overlay
        function onEscapeRequested(request: var): void {
            if (root.cancelCategoryEntry())
                request.accepted = true;
        }
    }

    Connections {
        target: DailyNotes
        function onDocumentChanged(): void {
            if (!root.draft)
                return;
            const note = DailyNotes.find(root.draft.id);
            if (!note) {
                root.draft = null;
                Qt.callLater(root.focusTask);
            } else if (!DailyNotes.boardFor(note.day).categories.includes(root.editCategory)) {
                root.editCategory = note.category;
            }
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
                actionsEnabled: root.draft === null && !root.notesMenuOpen
                onCategoryAdded: root.focusTask()
                onPreviousDay: root.showDay(root.days[root.dayIndex - 1])
                onNextDay: root.showDay(root.days[root.dayIndex + 1])
            }

            Divider { width: header.width }

            DailyNoteComposer {
                id: entry
                objectName: "quickNote"
                width: header.width
                visible: root.draft === null
                enabled: DailyNotes.ready
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
                visible: root.draft === null
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
                    reorderEnabled: root.shown && !root.notesMenuOpen
                    onSelectRequested: category => root.selectCategory(category)
                    onEditRequested: id => root.editTask(id)
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

            DailyNotesScroll {
                id: editList
                anchors.fill: parent
                rightGutter: Appearance.s.lg
                visible: root.draft !== null
                contentHeight: editor.height

                Loader {
                    id: editor
                    width: editList.contentWidth
                    active: root.draft !== null
                    onLoaded: Qt.callLater(root.focusTask)
                    sourceComponent: DailyNoteEditor {
                        draft: root.draft
                        category: root.editCategory
                        onCategoryRequested: anchor => root.openCategoryPicker(anchor)
                        onFinished: {
                            root.draft = null;
                            Qt.callLater(root.focusTask);
                        }
                    }
                }
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
