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

    // Legacy documents can omit categories, layout, and the quick entry destination.
    function validDocument(data: var, validDay: var, validRange: var): bool {
        if (!Number.isSafeInteger(data?.nextId) || data.nextId < 1
                || typeof data.trackedId !== "string" || !Array.isArray(data.notes))
            return false;
        const categories = data.categories === undefined ? [] : data.categories;
        if (!Array.isArray(categories))
            return false;
        const names = new Set();
        for (const name of categories) {
            if (typeof name !== "string" || name === "" || name !== name.trim() || names.has(name.toLowerCase()))
                return false;
            names.add(name.toLowerCase());
        }
        const keys = new Set(categories);
        if (data.quickCategory !== undefined && (!keys.has(data.quickCategory) || root.isLegacyCategory(data.quickCategory)))
            return false;
        const lanes = data.cardLanes;
        if (lanes !== undefined && (lanes === null || typeof lanes !== "object"
                || Object.getPrototypeOf(lanes) !== Object.prototype
                || !root.validLaneEntries(Object.entries(lanes), keys)))
            return false;
        if (data.cardOrder !== undefined) {
            if (!Array.isArray(data.cardOrder))
                return false;
            const ordered = new Set(data.cardOrder);
            if (ordered.size !== data.cardOrder.length)
                return false;
            ordered.delete("");
            if (ordered.size !== keys.size || categories.some(key => !ordered.has(key)))
                return false;
        }
        const ids = new Set();
        for (const note of data.notes) {
            if (typeof note?.id !== "string" || !/^[1-9]\d*$/.test(note.id)
                    || Number(note.id) >= data.nextId || ids.has(note.id)
                    || typeof note.day !== "string" || !validDay(note.day)
                    || typeof note.title !== "string" || note.title.trim() === ""
                    || typeof note.done !== "boolean"
                    || typeof note.start !== "string" || typeof note.end !== "string"
                    || !validRange(note.start, note.end)
                    || (!keys.has(note.category) && !root.isLegacyCategory(note.category)))
                return false;
            ids.add(note.id);
        }
        return true;
    }

    /*! Normalize a validated document in memory before exposing its categories.
        Use a named fallback only when the document has notes to recover. */
    function migrate(data: var): var {
        const keep = key => !root.isLegacyCategory(key);
        const next = Object.assign({}, data, { categories: (data.categories ?? []).filter(keep) });
        if (data.cardOrder !== undefined)
            next.cardOrder = data.cardOrder.filter(keep);
        if (data.cardLanes !== undefined)
            next.cardLanes = root.laneObject(Object.entries(data.cardLanes).filter(([key]) => keep(key)));
        if (data.notes.every(note => keep(note.category)))
            return next;

        const order = next.cardOrder ?? next.categories;
        if (order.length === 0) {
            const recovery = qsTr("Recovered Tasks");
            next.categories.push(recovery);
            next.cardOrder?.push(recovery);
        }
        next.notes = data.notes.map(note => keep(note.category) ? note
            : Object.assign({}, note, { category: order[0] }));
        return next;
    }
}
