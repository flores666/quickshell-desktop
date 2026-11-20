pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    function isLegacyCategory(category: var): bool {
        return category === undefined || category === ""
            || (typeof category === "string" && category.toLowerCase() === "inbox");
    }

    function validLaneEntries(entries: var, keys: var): bool {
        for (const [key, lane] of entries) {
            if (!keys.has(key) || (lane !== 0 && lane !== 1))
                return false;
        }
        return true;
    }

    function laneObject(entries: var): var {
        const lanes = {};
        for (const [key, lane] of entries)
            Object.defineProperty(lanes, key, { value: lane, enumerable: true });
        return lanes;
    }

    function isObject(value: var): bool {
        return value !== null && typeof value === "object" && Object.getPrototypeOf(value) === Object.prototype;
    }

    function validBoard(board: var, legacy: bool): bool {
        if (!root.isObject(board))
            return false;
        const categories = legacy && board.categories === undefined ? [] : board.categories;
        if (!Array.isArray(categories))
            return false;
        const names = new Set();
        for (const name of categories) {
            if (typeof name !== "string" || name === "" || name !== name.trim()
                    || (!legacy && root.isLegacyCategory(name)) || names.has(name.toLowerCase()))
                return false;
            names.add(name.toLowerCase());
        }
        const keys = new Set(categories);
        if (board.quickCategory !== undefined && (!keys.has(board.quickCategory) || root.isLegacyCategory(board.quickCategory)))
            return false;
        const lanes = board.cardLanes;
        if (lanes !== undefined && (!root.isObject(lanes) || !root.validLaneEntries(Object.entries(lanes), keys)))
            return false;
        if (board.cardOrder !== undefined) {
            if (!Array.isArray(board.cardOrder))
                return false;
            const ordered = new Set(board.cardOrder);
            if (ordered.size !== board.cardOrder.length)
                return false;
            if (legacy)
                ordered.delete("");
            if (ordered.size !== keys.size || categories.some(key => !ordered.has(key)))
                return false;
        }
        return true;
    }

    function validDocument(data: var, validDay: var, validRange: var): bool {
        if (!Number.isSafeInteger(data?.nextId) || data.nextId < 1
                || typeof data.trackedId !== "string" || !Array.isArray(data.notes))
            return false;
        const legacy = data.boards === undefined;
        const keysByDay = new Map();
        if (legacy) {
            if (!root.validBoard(data, true))
                return false;
        } else {
            if (!root.isObject(data.boards))
                return false;
            for (const [day, board] of Object.entries(data.boards)) {
                if (!validDay(day) || !root.validBoard(board, false) || board.categories.length === 0)
                    return false;
                keysByDay.set(day, new Set(board.categories));
            }
        }
        const legacyKeys = new Set(legacy ? data.categories : []);
        const ids = new Set();
        for (const note of data.notes) {
            if (typeof note?.id !== "string" || !/^[1-9]\d*$/.test(note.id)
                    || Number(note.id) >= data.nextId || ids.has(note.id)
                    || typeof note.day !== "string" || !validDay(note.day)
                    || typeof note.title !== "string" || note.title.trim() === ""
                    || typeof note.done !== "boolean"
                    || typeof note.start !== "string" || typeof note.end !== "string"
                    || !validRange(note.start, note.end))
                return false;
            if (legacy ? !legacyKeys.has(note.category) && !root.isLegacyCategory(note.category)
                       : !keysByDay.get(note.day)?.has(note.category))
                return false;
            ids.add(note.id);
        }
        return true;
    }

    /*! Legacy category names without tasks have no date to recover. */
    function migrate(data: var): var {
        if (data.boards !== undefined)
            return data;
        const keep = key => !root.isLegacyCategory(key);
        const categories = (data.categories ?? []).filter(keep);
        const order = (data.cardOrder ?? categories).filter(keep);
        const lanes = Object.entries(data.cardLanes ?? {});
        const fallback = order[0] ?? qsTr("Recovered Tasks");
        const usedByDay = new Map();
        const notes = data.notes.map(note => {
            const category = keep(note.category) ? note.category : fallback;
            if (!usedByDay.has(note.day))
                usedByDay.set(note.day, new Set());
            usedByDay.get(note.day).add(category);
            return category === note.category ? note : Object.assign({}, note, { category });
        });
        const boards = {};
        const quickDay = notes[0]?.day;
        for (const [day, used] of usedByDay) {
            const board = { categories: categories.length === 0 ? [fallback] : categories.filter(key => used.has(key)) };
            if (data.cardOrder !== undefined)
                board.cardOrder = order.length === 0 ? [fallback] : order.filter(key => used.has(key));
            if (data.cardLanes !== undefined)
                board.cardLanes = root.laneObject(lanes.filter(([key]) => used.has(key)));
            if (day === quickDay && used.has(data.quickCategory))
                board.quickCategory = data.quickCategory;
            boards[day] = board;
        }
        return { nextId: data.nextId, trackedId: data.trackedId, boards, notes };
    }

    function withoutCategory(board: var, category: string): var {
        const keep = key => key !== category;
        const next = Object.assign({}, board, { categories: board.categories.filter(keep) });
        if (next.cardOrder !== undefined)
            next.cardOrder = next.cardOrder.filter(keep);
        if (next.cardLanes !== undefined)
            next.cardLanes = root.laneObject(Object.entries(next.cardLanes).filter(([key]) => keep(key)));
        if (next.quickCategory === category)
            delete next.quickCategory;
        return next;
    }

    function withLayout(board: var, cardOrder: var, lanes: var): var {
        const current = board.cardOrder ?? board.categories;
        const changes = { cardOrder };
        if (lanes !== undefined) {
            if (!(lanes instanceof Map) || !root.validLaneEntries(lanes, new Set(current)))
                return null;
            const previous = new Map(Object.entries(board.cardLanes ?? {}));
            if (lanes.size !== previous.size || [...lanes].some(([key, lane]) => previous.get(key) !== lane))
                changes.cardLanes = root.laneObject(lanes);
        }
        if (changes.cardLanes === undefined && cardOrder.every((key, index) => key === current[index]))
            return null;
        return Object.assign({}, board, changes);
    }
}
