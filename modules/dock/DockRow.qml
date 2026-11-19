pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The dock's arranged slots, preserving identities during reorder,
    arrival and departure.
*/
Row {
    id: root

    required property ShellScreen screen
    /*! The glass the icons stand on, whose colours they take (DockItem). */
    required property Surface panel
    property real controlExtension: 0
    /*! Pointer coordinates across the dock's window. */
    property real pointerX: 0
    property bool magnifying: false
    property int geometryRevision: 0
    readonly property var original: placement.resting
    readonly property real displayWidth: placement.preview.width

    DockLayout {
        id: placement
        source: root.dragSource
        target: root.dragTarget
        slots: {
            void root.geometryRevision;
            // During a move the repeater's indices can still describe the
            // previous order. Take each measure by identity.
            const byKey = new Map();
            for (let i = 0; i < slotRepeater.count; ++i) {
                const slot = slotRepeater.itemAt(i) as DockSlot;
                if (slot)
                    byKey.set(slot.entry.key, slot);
            }
            return root.drawn.map(entry => {
                const slot = byKey.get(entry.key);
                return { key: entry.key, app: Dock.isAppSlot(entry.item),
                    artwork: slot?.artworkWidth ?? 0, presence: slot?.presence ?? 0 };
            });
        }
    }
    /*! Resting artwork in monitor-local coordinates, also while the dock is
        hidden. The native owner chooses the window's monitor. Hover and drag
        transforms never feed back into the destination of a window's Genie. */
    readonly property var iconTargets: {
        const targets = [];
        const size = Appearance.m.dockIcon;
        const y = (root.screen?.height ?? 0) - Appearance.m.screenGap
            - Appearance.m.dockBase - Appearance.m.dockInset - size;
        root.drawn.forEach((entry, index) => {
            if (entry.leaving || !Dock.isAppSlot(entry.item)) return;
            const x = ((root.screen?.width ?? 0) - root.original.width) / 2
                + root.original.centers[index] - size / 2;
            targets.push({ item: entry.item, rect: { x, y, width: size, height: size } });
        });
        return targets;
    }
    readonly property var windowTargets: root.iconTargets.reduce((out, t) => out.concat(t.item.windows
        .filter(w => w?.address).map(w => Object.assign({ address: w.address, pinned: t.item.pinned }, t.rect))), [])
    /*! Publish identities before a pin has a window. These are the desktop
        entry's own identities, not a second application lookup in native code. */
    readonly property var appTargets: root.iconTargets.reduce((out, t) => out.concat(
        [...new Set([t.item.appId, t.item.entry?.id, t.item.entry?.startupClass].filter(id => id))]
            .map(appId => Object.assign({ appId, pinned: t.item.pinned }, t.rect))), [])
    readonly property var animationTargets: root.windowTargets.concat(root.appTargets)
    readonly property var magnifications: {
        // Distances use the resting centres, so an icon's animated artwork
        // never feeds back into its own magnification target.
        const windowWidth = root.QsWindow.window?.width ?? root.screen?.width ?? 0;
        const cursor = root.pointerX - (windowWidth - root.original.width) / 2;
        const spread = root.slotStride * Appearance.m.dockWaveSpread;
        return root.original.centers.map(center => {
            const distance = (cursor - center) / spread;
            return root.magnifying && Settings.dockMagnificationEnabled && !root.drag
                ? Math.min(Appearance.m.dockMagnification,
                    1 + (Appearance.m.dockMagnification - 1) * Math.exp(-distance * distance / 2)) : 1;
        });
    }

    /*! Reported to the dock, which owns the tooltip and the preview, and
        decides what a click on an application does. */
    signal childHover(var key, string label, real centerX, bool entered)
    signal activated(var item, real centerX)

    /*! The source and destination keys change together. Arrivals and exits
        can change slot indices, and bindings must see a single drag state. */
    property var drag: null
    /*! Disable slide animation before clearing offsets and committing a drop. */
    property bool rearranging: false

    readonly property int slotStride: Appearance.m.dockIcon + Appearance.m.dockGap
    readonly property int dragSource: root.drag ? root.indexOf(root.drag.from) : -1
    readonly property int dragTarget: root.drag ? root.indexOf(root.drag.to) : -1

    function indexOf(key: var): int {
        return root.drawn.findIndex(entry => !entry.leaving && entry.key === key);
    }

    function slideFor(key: var): real {
        if (root.drag === null || root.drag.from === key)
            return 0;
        return (placement.preview.byKey.get(key)?.center ?? 0) + placement.previewOffset
            - (root.original.byKey.get(key)?.center ?? 0);
    }

    /*! Pick the closest resting place for the carried item. Crossing an item
        shifts the source by that item's stride, which can vary by slot. */
    function updateDrag(key: var, dx: real): void {
        const from = root.indexOf(key);
        if (from === -1 || (root.drag && root.drag.from !== key))
            return;
        if (!root.drag) {
            root.rearranging = true;
            root.drag = { from: key, to: key };
        }
        const offsets = placement.dropOffsets;
        let nearest = from;
        let distance = Infinity;
        for (let to = 0; to < root.drawn.length; ++to) {
            if (root.drawn[to].leaving)
                continue;
            const delta = Math.abs(dx - offsets[to]);
            if (delta <= distance) {
                nearest = to;
                distance = delta;
            }
        }
        const target = root.drawn[nearest].key;
        if (root.drag.to !== target)
            root.drag = { from: key, to: target };
    }

    function finishDrag(key: var, dropped: bool): void {
        const drag = root.drag;
        if (!drag || drag.from !== key)
            return;
        // Drop offsets before changing the real order and lay out immediately
        // so that pointer hover sees the dropped slot in its new place.
        root.rearranging = false;
        root.drag = null;
        if (dropped) {
            Dock.moveSlot(drag.from, drag.to);
            root.forceLayout();
        }
    }

    /*! Stable records with { key, item, leaving, arriving }: what the row draws. */
    property var drawn: []

    Component {
        id: record
        QtObject {
            required property var key
            required property var item
            required property bool arriving
            property bool leaving: false
        }
    }

    /*! Dock's list, with each slot that has left kept after the one
        it stood behind until it has shrunk away. */
    function reconcile(arriving: bool): void {
        const previous = new Map(root.drawn.map(e => [e.key, e]));
        const out = Dock.slots.map(item => {
            const kept = previous.get(item.key);
            if (kept) {
                kept.item = item;
                kept.leaving = false;
                return kept;
            }
            return record.createObject(root, { key: item.key, item, arriving });
        });
        let behind = -1;
        for (const e of root.drawn) {
            const at = out.findIndex(o => o.key === e.key);
            if (at !== -1) {
                behind = at;
                continue;
            }
            behind += 1;
            e.leaving = true;
            out.splice(behind, 0, e);
        }
        root.drawn = out;
        if (root.drag && root.dragSource === -1)
            root.finishDrag(root.drag.from, false);
    }

    function forget(key: var): void {
        const leaving = root.drawn.find(e => e.key === key && e.leaving);
        if (!leaving)
            return;
        root.drawn = root.drawn.filter(e => e !== leaving);
        leaving.destroy();
    }

    Component.onCompleted: root.reconcile(false)

    Connections {
        target: Dock
        function onSlotsChanged(): void { root.reconcile(true); }
    }

    spacing: 0
    height: Appearance.m.dockSlot

    Item {
        // Row culls children with no size. Put its measured dividers in a
        // sibling so they draw without taking a second span in the row.
        parent: root.parent
        x: root.x
        y: root.y
        width: root.width
        height: root.height
        visible: root.visible

        Repeater {
            model: 2
            DockSeparator {
                id: divider
                required property int index
                readonly property var position: placement.preview.dividers[divider.index]

                x: (divider.position?.center ?? 0) + placement.previewOffset - width / 2
                y: (root.height + root.controlExtension - height) / 2
                opacity: divider.position?.presence ?? 0
                width: Appearance.m.dockDividerWidth * opacity
                visible: divider.position !== null
                color: root.panel.schemeOver(divider).border

                Behavior on x {
                    enabled: root.rearranging && divider.visible
                    NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
                }
            }
        }
    }

    Repeater {
        id: slotRepeater
        onItemAdded: root.geometryRevision++
        onItemRemoved: root.geometryRevision++
        // Keep record identities stable and update their properties directly.
        // ScriptModel 0.3.2 batches changed JS payloads past the next key:
        // inserting in the middle then changes old delegates into other apps
        // and grows the last one instead of the new application.
        model: ScriptModel {
            values: root.drawn
            comparisonMode: ObjectComparison.Identity
        }

        DockSlot {
            required property int index
            required property var modelData
            entry: this.modelData
            screen: root.screen
            panel: root.panel
            controlExtension: root.controlExtension
            width: root.original.byKey.get(this.modelData.key)?.width ?? 0
            centerOffset: root.original.byKey.get(this.modelData.key)?.offset ?? 0
            slide: root.slideFor(this.modelData.key)
            rearranging: root.rearranging
            targetMagnification: this.widget ? 1 : root.magnifications[this.index] ?? 1
            onClicked: (item, centerX) => root.activated(item, centerX)
            onHoverChanged: (key, label, centerX, entered) => root.childHover(key, label, centerX, entered)
            // Not inside the slot's signal, which dropping it destroys. Each
            // callback must be distinct: callLater(forget, key) coalesces a
            // simultaneous batch of exits and forgets only its last key.
            onGone: key => Qt.callLater(() => root.forget(key))

            onDragMoved: dx => root.updateDrag(this.modelData.key, dx)
            onDragEnded: root.finishDrag(this.modelData.key, true)
            onDragCanceled: root.finishDrag(this.modelData.key, false)
        }
    }
}
