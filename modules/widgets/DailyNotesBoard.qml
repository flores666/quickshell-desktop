pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/services"

Item {
    id: root

    required property var groups
    property Item dragViewport: root
    property real glass: Appearance.popupOpacity
    property string day
    property bool reorderEnabled: true
    property string destinationCategory
    property var focusedCategory: null
    signal selectRequested(string category)
    signal editRequested(string id)
    signal deleteRequested(string category)

    readonly property int gap: Appearance.s.md
    readonly property int columns: root.groups.length > 1
        && root.width >= Appearance.m.dailyNotesTileMinimum * 2 + root.gap ? 2 : 1
    readonly property real columnWidth: (root.width - (root.columns - 1) * root.gap) / root.columns
    readonly property var byCategory: new Map(root.groups.map(group => [group.category, group]))
    readonly property bool focusActive: root.focusedCategory !== null && root.byCategory.has(root.focusedCategory)
    readonly property var keys: root.groups.map(group => group.category)
    readonly property var tiles: new Map(root.children.filter(child => child instanceof DailyNoteCategory)
        .map(tile => [tile.category, tile]))
    readonly property bool canReorder: root.reorderEnabled && root.visible && root.enabled
        && DailyNotes.ready && root.keys.length > 1
    readonly property bool animated: Settings.hyprAnimations !== 0

    property var gesture: null
    property var dragPoint: null
    readonly property bool dragging: root.dragPoint !== null

    readonly property var resting: root.pack(root.keys, root.automaticLanes())
    readonly property var arrangement: {
        const drag = root.gesture;
        if (drag?.landing)
            return drag.landing;
        if (!drag || drag.category === drag.target)
            return root.resting;
        const order = DailyNotes.orderAfterMove(drag.category, drag.target, drag.after);
        const lanes = root.lanesAfterMove(drag.category, drag.target, drag.after);
        return order === null || lanes === null ? root.resting : root.pack(order, lanes ?? root.resting.lanes);
    }

    function automaticLanes(): var {
        if (root.columns === 1)
            return new Map(root.keys.map(key => [key, 0]));
        const lanes = new Map();
        const loads = [0, 0];
        const cards = root.keys.map(key => root.tiles.get(key)).filter(tile => tile);
        const saved = DailyNotes.cardLanes;
        const pinned = cards.filter(tile => saved.has(tile.category));
        const side = saved.get(pinned[0]?.category);
        // If a pinned column was emptied, keep the replacement stable when new cards join.
        const replacement = pinned.length > 1 && pinned.every(tile => saved.get(tile.category) === side)
            ? pinned[pinned.length - 1] : null;
        for (const tile of pinned) {
            const lane = tile === replacement ? 1 - side : saved.get(tile.category);
            lanes.set(tile.category, lane);
            loads[lane] += tile.implicitHeight + root.gap;
        }
        for (const tile of cards) {
            if (lanes.has(tile.category))
                continue;
            const lane = loads[1] < loads[0] ? 1 : 0;
            lanes.set(tile.category, lane);
            loads[lane] += tile.implicitHeight + root.gap;
        }
        return lanes;
    }

    function pack(order: var, lanes: var): var {
        const boxes = new Map();
        const ends = [0, 0];
        const stride = root.columnWidth + root.gap;
        // Focus changes only the paint transform, never the masonry slots.
        for (const key of order) {
            const tile = root.tiles.get(key);
            if (!tile)
                continue;
            const lane = lanes.get(key);
            const height = tile.implicitHeight;
            boxes.set(key, Qt.rect(lane * stride, ends[lane], root.columnWidth, height));
            ends[lane] += height + root.gap;
        }
        return { boxes, lanes, height: Math.max(0, Math.max(...ends) - root.gap) };
    }

    readonly property real contentHeight: {
        let bottom = root.height;
        for (const [key, box] of root.arrangement.boxes)
            bottom = Math.max(bottom, box.y + box.height * (root.tiles.get(key)?.layoutScale ?? 1));
        return bottom;
    }
    implicitHeight: Math.max(root.resting.height, root.arrangement.height)
    height: implicitHeight

    function startDrag(category: string, cursor: point, origin: point, grab: point, heldFor: real): void {
        const tile = root.tiles.get(category);
        if (!root.canReorder || root.gesture || !tile)
            return;
        motion.begin(tile, grab, origin, Date.now() - heldFor * 1000);
        root.gesture = { category, target: category, after: false, order: root.keys };
        root.moveDrag(category, cursor);
    }

    function moveDrag(category: string, cursor: point): void {
        if (root.gesture?.category !== category)
            return;
        root.dragPoint = cursor;
        root.refreshDrag();
    }

    function containsCursor(cursor: point): bool {
        const local = root.dragViewport.mapFromItem(null, cursor.x, cursor.y);
        return local.x >= 0 && local.x < root.dragViewport.width && local.y >= 0 && local.y < root.dragViewport.height;
    }

    function refreshDrag(): void {
        const gesture = root.gesture;
        const cursor = root.dragPoint;
        if (!gesture || cursor === null)
            return;
        const local = root.mapFromItem(null, cursor.x, cursor.y);
        motion.move(local, cursor);
        let target = gesture.category;
        if (root.containsCursor(cursor)) {
            // Test the saved slots in the pointer's column so the preview cannot move its own target.
            const lane = root.columns === 2 && local.x >= root.width / 2 ? 1 : 0;
            let best = Infinity;
            for (const [key, box] of root.resting.boxes) {
                if (root.resting.lanes.get(key) !== lane)
                    continue;
                const distance = Math.max(box.y - local.y, 0, local.y - box.y - box.height);
                if (distance < best) {
                    target = key;
                    best = distance;
                }
            }
        }
        const box = root.resting.boxes.get(target);
        const after = target !== gesture.category && (root.columns === 1
            ? gesture.order.indexOf(gesture.category) < gesture.order.indexOf(target) : local.y >= box.y + box.height / 2);
        if (target !== gesture.target || after !== gesture.after)
            root.gesture = Object.assign({}, gesture, { target, after });
    }

    function finishDrag(drop: bool): void {
        const gesture = root.gesture;
        const cursor = root.dragPoint;
        if (!gesture || cursor === null)
            return;
        const accept = drop && root.canReorder && gesture.category !== gesture.target && root.containsCursor(cursor);
        // Preserve the preview across the write so the scroll bounds cannot shrink between layouts.
        if (accept)
            root.gesture = Object.assign({}, gesture, { landing: root.arrangement });
        root.dragPoint = null;
        try {
            motion.release(root.tiles.get(gesture.category)?.layoutScale ?? 1);
            if (accept)
                root.moveTo(gesture.category, gesture.target, gesture.after);
        } finally {
            root.gesture = null;
        }
    }

    function lanesAfterMove(category: string, target: string, after: bool): var {
        if (root.columns === 1)
            return undefined;
        const visibleLanes = root.resting.lanes;
        const source = visibleLanes.get(category);
        const destination = visibleLanes.get(target);
        if (source === undefined || destination === undefined)
            return null;
        const sourceKeys = root.keys.filter(key => visibleLanes.get(key) === source);
        if (source === destination && sourceKeys.indexOf(category) === sourceKeys.indexOf(target) + (after ? 1 : -1))
            return null;

        const lanes = new Map(DailyNotes.cardLanes);
        for (const [key, lane] of visibleLanes)
            lanes.set(key, lane);
        // Exchange the two cards if moving would otherwise empty the source lane.
        if (source !== destination && sourceKeys.length === 1)
            lanes.set(target, source);
        lanes.set(category, destination);
        return lanes;
    }

    function moveTo(category: string, target: string, after: bool): void {
        const lanes = root.lanesAfterMove(category, target, after);
        if (lanes !== null)
            DailyNotes.moveCategory(category, target, after, lanes);
    }

    function step(category: string, delta: int): void {
        if (!root.canReorder || root.gesture)
            return;
        const boxes = root.resting.boxes;
        const order = root.columns === 1 ? root.keys : [...boxes.keys()].sort((a, b) => {
            const left = boxes.get(a);
            const right = boxes.get(b);
            return left.y - right.y || left.x - right.x;
        });
        const from = order.indexOf(category);
        const to = from + delta;
        if (from >= 0 && to >= 0 && to < order.length)
            root.moveTo(category, order[to], delta > 0);
    }

    onDayChanged: root.finishDrag(false)
    onWidthChanged: root.finishDrag(false)
    onCanReorderChanged: if (!root.canReorder) root.finishDrag(false)
    onKeysChanged: if (root.dragging && root.gesture) {
        const order = root.gesture.order;
        if (order.length !== root.keys.length || order.some((key, i) => key !== root.keys[i]))
            root.finishDrag(false);
    }

    DailyNoteDragMotion { id: motion; animated: root.animated }

    Repeater {
        model: ScriptModel { values: root.keys }

        DailyNoteCategory {
            id: tile
            required property string modelData

            readonly property rect box: root.arrangement.boxes.get(tile.category) ?? Qt.rect(0, 0, 0, 0)
            readonly property bool sliding: root.animated && motion.tile !== null
            layoutScale: !root.focusActive ? 1
                : tile.category === root.focusedCategory ? Appearance.m.dailyNotesFocusScale : Appearance.m.dailyNotesOtherScale
            category: tile.modelData
            fill: PopupStyle.noteCategoryFill(Math.max(0, DailyNotes.categories.indexOf(tile.category)), root.glass)
            taskDestination: tile.category === root.destinationCategory
            group: root.byCategory.get(tile.category) ?? null
            reorderEnabled: root.canReorder
            carried: motion.tile === tile
            lift: tile.carried ? motion.lift : 0
            z: tile.carried ? 2 : tile.layoutScale > 1 ? 1 : 0
            x: tile.box.x
            y: tile.box.y
            width: root.columnWidth
            cardTransform: motion.matrixFor(tile, tile.layoutScale)
            Behavior on layoutScale {
                enabled: root.animated
                NumberAnimation {
                    duration: Appearance.t.base
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.windowDrag.smoothCurve
                }
            }
            Behavior on x {
                enabled: tile.sliding
                NumberAnimation { duration: Appearance.t.popupMove; easing.type: Appearance.t.emphasizedEasing }
            }
            Behavior on y {
                enabled: tile.sliding
                NumberAnimation { duration: Appearance.t.popupMove; easing.type: Appearance.t.emphasizedEasing }
            }
            onGripStarted: (cursor, origin, grab, heldFor) => root.startDrag(tile.category, cursor, origin, grab, heldFor)
            onGripMoved: cursor => root.moveDrag(tile.category, cursor)
            onGripReleased: cursor => {
                if (root.gesture?.category !== tile.category)
                    return;
                root.moveDrag(tile.category, cursor);
                root.finishDrag(true);
            }
            onGripCanceled: if (root.gesture?.category === tile.category) root.finishDrag(false)
            onStepRequested: delta => root.step(tile.category, delta)
            onSelectRequested: category => root.selectRequested(category)
            onEditRequested: id => root.editRequested(id)
            onDeleteRequested: category => root.deleteRequested(category)
        }
    }
}
