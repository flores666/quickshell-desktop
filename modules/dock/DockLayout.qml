pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! Measure the resting and proposed dock from the same artwork and gaps.
    Each member contributes half a gap on either side as it grows or shrinks. */
QtObject {
    id: root

    required property var slots
    required property int source
    required property int target

    readonly property var resting: root.measure(root.slots)
    readonly property var preview: root.source >= 0 && root.target >= 0 && root.source !== root.target
        ? root.measure(root.moved(root.target)) : root.resting
    readonly property real previewOffset: (root.resting.width - root.preview.width) / 2

    // Compute drop positions on geometry changes, independently of pointer motion.
    readonly property var dropOffsets: {
        if (root.source < 0)
            return [];
        const start = root.resting.centers[root.source] - root.resting.width / 2;
        return root.slots.map((slot, index) => {
            if (index === root.source)
                return 0;
            const plan = root.measure(root.moved(index));
            return plan.centers[index] - plan.width / 2 - start;
        });
    }

    function moved(to: int): var {
        const order = root.slots.slice();
        order.splice(to, 0, order.splice(root.source, 1)[0]);
        return order;
    }

    function measure(order: var): var {
        let firstApp = -1;
        let lastApp = -1;
        let apps = 0;
        let leading = 0;
        let trailing = 0;
        for (let i = 0; i < order.length; ++i) {
            const slot = order[i];
            if (slot.app && slot.presence > 0) {
                if (firstApp === -1)
                    firstApp = i;
                lastApp = i;
                apps = Math.max(apps, slot.presence);
                trailing = 0;
            } else if (firstApp === -1) {
                leading = Math.max(leading, slot.presence);
            } else {
                trailing = Math.max(trailing, slot.presence);
            }
        }

        const m = Appearance.m;
        // At the largest icon size the launcher's hit box is wider than its
        // artwork plus a gap. Keep those outer hit pixels on the surface.
        const pad = (leading || apps || trailing)
            ? Math.max(0, (m.dockSlot - m.dockLauncherIcon - m.dockGap) / 2) : 0;
        let width = pad;
        const centers = [];
        const byKey = new Map();
        const dividers = [null, null];
        function placeDivider(side, presence) {
            if (presence <= 0)
                return;
            const span = (m.dockGap + m.dockDividerWidth) * presence;
            dividers[side] = { center: width + span / 2, presence };
            width += span;
        }

        for (let i = 0; i < order.length; ++i) {
            const slot = order[i];
            const start = i === 0 ? 0 : width;
            if (i === firstApp)
                placeDivider(0, Math.min(leading, apps));
            const span = (slot.artwork + m.dockGap) * slot.presence;
            const center = width + span / 2;
            width += span;
            if (i === lastApp)
                placeDivider(1, Math.min(trailing, apps));
            if (i === order.length - 1)
                width += pad;
            centers.push(center);
            byKey.set(slot.key, { center, offset: center - start, width: width - start });
        }
        return { centers, byKey, dividers, width };
    }
}
