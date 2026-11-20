pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*! Personal checklist history, categories, tracking, and quick entry destination. */
Singleton {
    id: root

    property var document: ({ nextId: 1, boards: {}, notes: [] })
    property bool ready: false
    property string error: ""

    readonly property string today: Qt.formatDate(Time.now, "yyyy-MM-dd")
    readonly property var emptyBoard: ({ categories: [] })
    readonly property var days: Object.keys(root.document.boards).sort()
    readonly property var todayChecklist: root.checklist(root.today)
    readonly property var preview: root.previewAt(Time.now)
    readonly property bool caughtUp: root.ready && root.todayChecklist.done === root.todayChecklist.total
    readonly property var dockPreview: root.caughtUp ? null : root.preview
    readonly property string previewPinId: root.boardFor(root.today).quickCategory === undefined
        ? (root.dockPreview?.id ?? "") : ""

    function previewAt(now: date): var {
        const day = Qt.formatDate(now, "yyyy-MM-dd");
        const deadline = day + "T" + Qt.formatTime(now, "HH:mm");
        const category = root.boardFor(day).quickCategory;
        return (category ? root.relevantNote(day, deadline, category) : null) ?? root.relevantNote(day, deadline);
    }

    function relevantNote(day: string, deadline: string, category: var): var {
        let upcoming = null;
        let newest = null;
        for (const note of root.document.notes) {
            if (note.done || (category !== undefined && (note.day !== day || note.category !== category)))
                continue;
            if (!newest)
                newest = note;
            if (note.deadline && note.deadline >= deadline && (!upcoming || note.deadline < upcoming.deadline))
                upcoming = note;
        }
        return upcoming ?? newest;
    }

    function dateFor(day: string): date {
        const [year, month, dayOfMonth] = day.split("-").map(Number);
        const local = new Date(0);
        local.setHours(12, 0, 0, 0);
        local.setFullYear(year, month - 1, dayOfMonth);
        return local;
    }

    function validDay(day: string): bool {
        return /^\d{4}-\d{2}-\d{2}$/.test(day) && Qt.formatDate(root.dateFor(day), "yyyy-MM-dd") === day;
    }

    function validDeadline(deadline: string): bool {
        return deadline === "" || (/^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d$/.test(deadline)
            && root.validDay(deadline.slice(0, 10)));
    }

    function deadlineText(deadline: string): string {
        if (!deadline)
            return "";
        const date = root.dateFor(deadline.slice(0, 10));
        return qsTr("%1 · %2").arg(Qt.formatDate(date, "MMM d, yyyy")).arg(deadline.slice(11));
    }

    function forDay(day: string): var {
        return root.document.notes.filter(note => note.day === day);
    }

    function checklist(day: string): var {
        const groups = new Map(root.orderFor(day).map(category => [category, { category, notes: new Map(), done: 0 }]));
        let done = 0;
        // The Dock uses document order. The board shows tasks in creation order.
        const notes = root.forDay(day).reverse();
        for (const note of notes) {
            const group = groups.get(note.category);
            group.notes.set(note.id, note);
            if (note.done) {
                group.done++;
                done++;
            }
        }
        return { total: notes.length, done, groups: [...groups.values()] };
    }

    function progressText(checklist: var): string {
        return qsTr("%1 of %2 done").arg(checklist.done).arg(checklist.total);
    }

    function boardFor(day: string): var {
        return Object.prototype.hasOwnProperty.call(root.document.boards, day) ? root.document.boards[day] : root.emptyBoard;
    }

    function orderFor(day: string): var {
        const board = root.boardFor(day);
        return board.cardOrder ?? board.categories;
    }

    function lanesFor(day: string): var {
        return new Map(Object.entries(root.boardFor(day).cardLanes ?? {}));
    }

    function targetCategory(day: string): string {
        return root.boardFor(day).quickCategory ?? root.document.notes.find(note => note.day === day)?.category ?? "";
    }

    function canAddCategory(day: string, text: string): bool {
        return root.ready && root.validDay(day) && !documentFormat.isLegacyCategory(text.trim());
    }

    function selectCategory(day: string, category: string): bool {
        const board = root.boardFor(day);
        return root.ready && board.categories.includes(category) && (board.quickCategory === category
            || root.commitBoard(day, Object.assign({}, board, { quickCategory: category })));
    }

    /*! Null means the category could not be saved. */
    function addCategory(day: string, text: string): var {
        if (!root.canAddCategory(day, text))
            return null;
        const board = root.boardFor(day);
        const name = text.trim();
        const key = name.toLowerCase();
        const existing = board.categories.find(category => category.toLowerCase() === key);
        if (existing !== undefined)
            return existing;
        const next = Object.assign({}, board, { categories: [...board.categories, name] });
        if (board.categories.length === 0)
            next.quickCategory = name;
        if (next.cardOrder !== undefined)
            next.cardOrder = [...board.cardOrder, name];
        return root.commitBoard(day, next) ? name : null;
    }

    /*! Resolve both keys against the current order for preview and commit. */
    function orderAfterMove(day: string, category: string, target: string, after: bool): var {
        const current = root.orderFor(day);
        if (category === target || !current.includes(category) || !current.includes(target))
            return null;
        const cardOrder = current.filter(key => key !== category);
        cardOrder.splice(cardOrder.indexOf(target) + (after ? 1 : 0), 0, category);
        return cardOrder;
    }

    /*! Save lane assignments atomically with the order. */
    function moveCategory(day: string, category: string, target: string, after: bool, lanes: var): bool {
        if (!root.ready)
            return false;
        const cardOrder = root.orderAfterMove(day, category, target, after);
        if (cardOrder === null)
            return false;
        const next = documentFormat.withLayout(root.boardFor(day), cardOrder, lanes);
        return next !== null && root.commitBoard(day, next);
    }

    function find(id: string): var {
        return root.document.notes.find(note => note.id === id) ?? null;
    }

    function removeCategory(day: string, category: string): bool {
        const board = root.boardFor(day);
        if (!root.ready || !board.categories.includes(category))
            return false;
        const notes = root.document.notes.filter(note => note.day !== day || note.category !== category);
        return root.commitBoard(day, documentFormat.withoutCategory(board, category), { notes });
    }

    function commitBoard(day: string, board: var, changes: var): bool {
        const boards = Object.assign({}, root.document.boards);
        if (board.categories.length > 0)
            boards[day] = board;
        else
            delete boards[day];
        return root.commit(Object.assign({}, root.document, changes, { boards }));
    }

    function validDocument(data: var): bool {
        return documentFormat.validDocument(data, root.validDay, root.validDeadline);
    }

    function load(): void {
        const text = file.text();
        try {
            if (file.readResult !== FileViewError.FileNotFound) {
                if (file.readResult !== FileViewError.Success)
                    throw new Error(FileViewError.toString(file.readResult));
                const data = JSON.parse(text);
                if (!root.validDocument(data))
                    throw new Error("Invalid daily notes document");
                root.document = documentFormat.migrate(data);
            }
            root.ready = true;
        } catch (e) {
            root.error = qsTr("Could not read daily notes.");
            console.warn("Daily notes read failed:", e);
        }
    }

    function commit(next: var): bool {
        if (!root.ready)
            return false;
        const text = JSON.stringify(next);
        file.setText(text);
        // FileView 0.3.2 can report a save even if the atomic rename failed.
        // Confirm the replacement on disk before publishing the new state.
        file.reload();
        if (file.text() !== text || file.readResult !== FileViewError.Success) {
            root.error = qsTr("Could not save daily notes.");
            return false;
        }
        root.document = next;
        root.error = "";
        return true;
    }

    /*! A blank id adds a task to the supplied category. Editing keeps its day,
        identity and category unless another category is explicitly supplied. */
    function save(day: string, id: string, text: string, deadline: string, category: var): bool {
        const title = text.trim();
        deadline = deadline.trim();
        if (!root.ready || title === "" || !root.validDay(day) || !root.validDeadline(deadline))
            return false;
        const note = id === "" ? null : root.find(id);
        if (id !== "" && (!note || note.day !== day))
            return false;
        const key = category === undefined ? note?.category : category;
        if (!root.boardFor(day).categories.includes(key))
            return false;
        const fields = { title, deadline, category: key };
        if (note) {
            if (note.title === title && note.deadline === deadline && note.category === key)
                return true;
            return root.replace(note, fields);
        }
        const nextId = root.document.nextId;
        if (!Number.isSafeInteger(nextId + 1))
            return false;
        const added = Object.assign({ id: String(nextId), day, done: false }, fields);
        return root.commit(Object.assign({}, root.document,
            { nextId: nextId + 1, notes: [added, ...root.document.notes] }));
    }

    function replace(note: var, fields: var): bool {
        const updated = Object.assign({}, note, fields);
        const notes = root.document.notes.map(item => item.id === note.id ? updated : item);
        return root.commit(Object.assign({}, root.document, { notes }));
    }

    function setDeadlineTime(id: string, time: string): bool {
        const note = root.find(id);
        return note !== null && root.save(note.day, id, note.title,
            time === "" ? "" : (note.deadline.slice(0, 10) || note.day) + "T" + time);
    }

    function saveAnnotation(id: string, snapshot: var, index: int, replacement: var): bool {
        const note = root.find(id);
        const annotations = note && note.annotations === snapshot
            ? documentFormat.withAnnotation(snapshot ?? [], index, replacement) : null;
        return annotations !== null && (annotations === snapshot || root.replace(note, { annotations }));
    }

    function toggleDone(id: string): void {
        const note = root.find(id);
        if (note)
            root.replace(note, { done: !note.done });
    }

    function remove(id: string): void {
        if (!root.find(id))
            return;
        const notes = root.document.notes.filter(note => note.id !== id);
        root.commit(Object.assign({}, root.document, { notes }));
    }

    Component.onCompleted: root.load()

    DailyNotesDocument { id: documentFormat }

    FileView {
        id: file

        property int readResult: FileViewError.Success
        path: Quickshell.statePath("daily-notes.json")
        blockAllReads: true
        blockWrites: true
        atomicWrites: true
        printErrors: false

        onLoaded: file.readResult = FileViewError.Success
        onLoadFailed: error => file.readResult = error
        onSaveFailed: error => {
            console.warn("Daily notes write failed:", FileViewError.toString(error));
        }
    }
}
