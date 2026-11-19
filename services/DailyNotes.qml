pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*! Personal checklist history, categories, tracking, and quick entry destination. */
Singleton {
    id: root

    property var document: ({ nextId: 1, trackedId: "", categories: [], notes: [] })
    property bool ready: false
    property string error: ""

    readonly property string today: Qt.formatDate(Time.now, "yyyy-MM-dd")
    readonly property string trackedId: root.document.trackedId
    readonly property var categories: root.document.categories
    readonly property var cardOrder: root.document.cardOrder ?? root.categories
    readonly property var cardLanes: new Map(Object.entries(root.document.cardLanes ?? {}))
    readonly property string targetCategory: root.document.quickCategory ?? root.document.notes[0]?.category ?? ""
    readonly property var days: [...new Set(root.document.notes.map(note => note.day))].sort()
    readonly property var todayChecklist: root.checklist(root.today)
    readonly property var preview: root.previewAt(Time.now)

    function previewAt(now: date): var {
        const tracked = root.find(root.trackedId);
        if (tracked && !tracked.done)
            return tracked;

        const day = Qt.formatDate(now, "yyyy-MM-dd");
        const minute = Qt.formatTime(now, "HH:mm");
        let active = null;
        let upcoming = null;
        let newest = null;
        for (const note of root.document.notes) {
            if (note.done)
                continue;
            if (!newest)
                newest = note;
            if (!note.start || note.day < day)
                continue;
            if (note.day === day && note.start <= minute) {
                if (minute < note.end && (!active || note.end < active.end))
                    active = note;
            } else if (!upcoming || note.day < upcoming.day
                    || (note.day === upcoming.day && note.start < upcoming.start)) {
                upcoming = note;
            }
        }
        return active ?? upcoming ?? newest;
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

    function validRange(start: string, end: string): bool {
        const time = /^(?:[01]\d|2[0-3]):[0-5]\d$/;
        return (start === "" && end === "") || (time.test(start) && time.test(end) && start < end);
    }

    function rangeText(note: var): string {
        return note?.start ? qsTr("%1–%2").arg(note.start).arg(note.end) : "";
    }

    function forDay(day: string): var {
        return root.document.notes.filter(note => note.day === day);
    }

    function checklist(day: string): var {
        const groups = new Map();
        let done = 0;
        const notes = root.forDay(day);
        for (const note of notes) {
            let group = groups.get(note.category);
            if (!group) {
                group = { category: note.category, notes: new Map(), done: 0 };
                groups.set(note.category, group);
            }
            group.notes.set(note.id, note);
            if (note.done) {
                group.done++;
                done++;
            }
        }
        const cards = [];
        for (const category of root.cardOrder) {
            const group = groups.get(category);
            if (group)
                cards.push(group);
            else if (day === root.today)
                cards.push({ category, notes: new Map(), done: 0 });
        }
        return { total: notes.length, done, groups: cards };
    }

    function progressText(checklist: var): string {
        return qsTr("%1 of %2 done").arg(checklist.done).arg(checklist.total);
    }

    function canAddCategory(text: string): bool {
        return root.ready && !documentFormat.isLegacyCategory(text.trim());
    }

    function selectCategory(category: string): bool {
        return root.ready && root.categories.includes(category) && (root.document.quickCategory === category
            || root.commit(Object.assign({}, root.document, { quickCategory: category })));
    }

    /*! Null means the category could not be saved. */
    function addCategory(text: string): var {
        if (!root.canAddCategory(text))
            return null;
        const name = text.trim();
        const key = name.toLowerCase();
        const existing = root.categories.find(category => category.toLowerCase() === key);
        if (existing !== undefined)
            return existing;
        const categories = [...root.document.categories, name];
        const next = Object.assign({}, root.document, { categories });
        if (next.cardOrder !== undefined)
            next.cardOrder = [...root.cardOrder, name];
        return root.commit(next) ? name : null;
    }

    /*! Resolve both keys against the current order for preview and commit. */
    function orderAfterMove(category: string, target: string, after: bool): var {
        const current = root.cardOrder;
        if (category === target || !current.includes(category) || !current.includes(target))
            return null;
        const cardOrder = current.filter(key => key !== category);
        cardOrder.splice(cardOrder.indexOf(target) + (after ? 1 : 0), 0, category);
        return cardOrder;
    }

    /*! Save lane assignments atomically with the order. */
    function moveCategory(category: string, target: string, after: bool, lanes: var): bool {
        if (!root.ready)
            return false;
        const cardOrder = root.orderAfterMove(category, target, after);
        if (cardOrder === null)
            return false;
        const current = root.cardOrder;
        const changes = { cardOrder };
        if (lanes !== undefined) {
            if (!(lanes instanceof Map) || !documentFormat.validLaneEntries(lanes, new Set(current)))
                return false;
            const previous = root.cardLanes;
            if (lanes.size !== previous.size || [...lanes].some(([key, lane]) => previous.get(key) !== lane))
                changes.cardLanes = documentFormat.laneObject(lanes);
        }
        if (changes.cardLanes === undefined && cardOrder.every((key, index) => key === current[index]))
            return false;
        return root.commit(Object.assign({}, root.document, changes));
    }

    function find(id: string): var {
        return root.document.notes.find(note => note.id === id) ?? null;
    }

    /*! Remove the category and its history across all dates in the same commit. */
    function removeCategory(category: string): bool {
        if (!root.ready || !root.categories.includes(category))
            return false;
        const categories = root.document.categories.filter(key => key !== category);
        const notes = root.document.notes.filter(note => note.category !== category);
        const trackedId = notes.some(note => note.id === root.trackedId) ? root.trackedId : "";
        const next = Object.assign({}, root.document, { categories, notes, trackedId });
        if (next.cardOrder !== undefined)
            next.cardOrder = root.cardOrder.filter(key => key !== category);
        if (root.cardLanes.has(category))
            next.cardLanes = documentFormat.laneObject([...root.cardLanes].filter(([key]) => key !== category));
        if (next.quickCategory === category)
            delete next.quickCategory;
        return root.commit(next);
    }

    function validDocument(data: var): bool {
        return documentFormat.validDocument(data, root.validDay, root.validRange);
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
    function save(day: string, id: string, text: string, start: string, end: string, category: var): bool {
        const title = text.trim();
        start = start.trim();
        end = end.trim();
        if (!root.ready || title === "" || !root.validDay(day) || !root.validRange(start, end))
            return false;
        const note = id === "" ? null : root.find(id);
        if (id !== "" && (!note || note.day !== day))
            return false;
        const key = category === undefined ? note?.category : category;
        if (!root.categories.includes(key))
            return false;
        const fields = { title, start, end, category: key };
        if (note) {
            if (note.title === title && note.start === start && note.end === end && note.category === key)
                return true;
            return root.replace(note, fields, root.trackedId);
        }
        const nextId = root.document.nextId;
        if (!Number.isSafeInteger(nextId + 1))
            return false;
        const added = Object.assign({ id: String(nextId), day, done: false }, fields);
        return root.commit(Object.assign({}, root.document,
            { nextId: nextId + 1, notes: [added, ...root.document.notes] }));
    }

    function replace(note: var, fields: var, trackedId: string): bool {
        const updated = Object.assign({}, note, fields);
        const notes = root.document.notes.map(item => item.id === note.id ? updated : item);
        return root.commit(Object.assign({}, root.document, { notes, trackedId }));
    }

    function toggleDone(id: string): void {
        const note = root.find(id);
        if (note)
            root.replace(note, { done: !note.done }, root.trackedId === id ? "" : root.trackedId);
    }

    function toggleTracking(id: string): void {
        const note = root.find(id);
        if (note && !note.done)
            root.commit(Object.assign({}, root.document, { trackedId: root.trackedId === id ? "" : id }));
    }

    function remove(id: string): void {
        if (!root.find(id))
            return;
        const notes = root.document.notes.filter(note => note.id !== id);
        const trackedId = root.trackedId === id ? "" : root.trackedId;
        root.commit(Object.assign({}, root.document, { notes, trackedId }));
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
