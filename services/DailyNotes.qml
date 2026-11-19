pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*! Personal checklist history, newest additions first. The entire document
    is committed together so a completed task and its tracking choice agree. */
Singleton {
    id: root

    property var document: ({ nextId: 1, trackedId: "", notes: [] })
    property bool ready: false
    property string error: ""

    readonly property string today: Qt.formatDate(Time.now, "yyyy-MM-dd")
    readonly property string trackedId: root.document.trackedId
    readonly property var days: [...new Set(root.document.notes.map(note => note.day))].sort()
    readonly property var preview: {
        const tracked = root.find(root.trackedId);
        return tracked && !tracked.done ? tracked : root.document.notes.find(note => !note.done) ?? null;
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

    function find(id: string): var {
        return root.document.notes.find(note => note.id === id) ?? null;
    }

    function validDocument(data: var): bool {
        if (!Number.isSafeInteger(data?.nextId) || data.nextId < 1
                || typeof data.trackedId !== "string" || !Array.isArray(data.notes))
            return false;
        const ids = new Set();
        for (const note of data.notes) {
            if (typeof note?.id !== "string" || !/^[1-9]\d*$/.test(note.id)
                    || Number(note.id) >= data.nextId || ids.has(note.id)
                    || typeof note.day !== "string" || !root.validDay(note.day)
                    || typeof note.title !== "string" || note.title.trim() === ""
                    || typeof note.done !== "boolean"
                    || typeof note.start !== "string" || typeof note.end !== "string"
                    || !root.validRange(note.start, note.end))
                return false;
            ids.add(note.id);
        }
        return true;
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
                root.document = data;
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

    /*! A blank id adds a task, otherwise editing keeps its day and identity. */
    function save(day: string, id: string, text: string, start: string, end: string): bool {
        const title = text.trim();
        start = start.trim();
        end = end.trim();
        if (!root.ready || title === "" || !root.validDay(day) || !root.validRange(start, end))
            return false;
        if (id !== "") {
            const note = root.find(id);
            if (!note || note.day !== day)
                return false;
            if (note.title === title && note.start === start && note.end === end)
                return true;
            return root.replace(note, { title, start, end }, root.trackedId);
        }
        const nextId = root.document.nextId;
        if (!Number.isSafeInteger(nextId + 1))
            return false;
        const note = { id: String(nextId), day, title, start, end, done: false };
        return root.commit({ nextId: nextId + 1, trackedId: root.trackedId, notes: [note, ...root.document.notes] });
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
