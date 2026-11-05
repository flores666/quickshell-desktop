pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The dock's icons: every application Dock lists, in its order, then the
    application grid. An icon dragged sideways opens a gap where it would land
    and moves there when dropped. An application that starts grows into its
    place and one that quits shrinks out of it (DockSlot), so what is drawn is
    Dock's list plus whatever is still on its way out, where it stood.
*/
Row {
    id: root

    required property ShellScreen screen
    /*! The glass the icons stand on, whose colours they take (DockItem). */
    required property Surface panel
    /*! Where the grid's button is, for the divider before it. */
    readonly property real launcherX: launcher.x
    /*! Pointer coordinates across the dock's window. */
    property real pointerX: 0
    property bool magnifying: false
    property int geometryRevision: 0
    readonly property var original: {
        void root.geometryRevision;
        const centers = [];
        let width = 0;
        for (let i = 0; i < slots.count; ++i) {
            const slot = slots.itemAt(i);
            const presence = slot ? slot.presence : 0;
            centers.push(width + Appearance.m.dockSlot * presence / 2);
            width += root.slotStride * presence;
        }
        centers.push(width + Appearance.m.dockSlot / 2);
        return { centers, width: width + Appearance.m.dockSlot };
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
            if (entry.leaving) return;
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
    signal childHover(string key, string label, real centerX, bool entered)
    signal activated(var item, real centerX)

    /*!
        The drag in flight: the application keys it came from and would land
        on. Indices can change while an application starts or quits.

        One property and not two. Assigning a pair of them leaves a frame in
        which `slideFor` sees the new drag against the last drop — QML
        re-evaluates every binding on the first write, before the second has
        happened — and with the drop still at its cleared -1 every icon left of
        the drag reads as being inside the gap. Measured on the frame a drag
        began: both icons to its left kicked 46px sideways and animated back,
        which is the cascade the dock used to show for a drag that had not
        reordered anything yet.
    */
    property var drag: null
    /*!
        Whether the icons ease aside for `drag`. Not `drag !== null`: at the
        drop this has to be off before the offsets go, and two bindings on one
        property hear of its change in whatever order QML happened to connect
        them. Measured, the offsets went first and eased away over the new
        order: every icon that had stepped aside started a slot further over
        and slid back. Written before `drag` at either end, so the order is
        this file's.
    */
    property bool rearranging: false

    readonly property int slotStride: Appearance.m.dockSlot + Appearance.m.dockGap

    /*! How far an icon has to step aside to open a gap where the drag will land. */
    function slideFor(slot: int): real {
        if (!root.drag || slot === -1)
            return 0;
        const from = Dock.appKeys.indexOf(root.drag.from);
        const to = Dock.appKeys.indexOf(root.drag.to);
        if (from === -1 || to === -1 || slot === from)
            return 0;
        if (slot > from && slot <= to)
            return -root.slotStride;
        if (slot < from && slot >= to)
            return root.slotStride;
        return 0;
    }

    /*! Stable records with { key, item, leaving, arriving }: what the row draws. */
    property var drawn: []

    Component {
        id: record
        QtObject {
            required property string key
            required property var item
            required property bool arriving
            property bool leaving: false
        }
    }

    /*! Dock's list, with each application that has left kept after the one
        it stood behind until it has shrunk away. */
    function reconcile(arriving: bool): void {
        const previous = new Map(root.drawn.map(e => [e.key, e]));
        const out = Dock.items.map(item => {
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
    }

    function forget(key: string): void {
        const leaving = root.drawn.find(e => e.key === key && e.leaving);
        if (!leaving)
            return;
        root.drawn = root.drawn.filter(e => e !== leaving);
        leaving.destroy();
    }

    Component.onCompleted: root.reconcile(false)

    Connections {
        target: Dock
        function onItemsChanged(): void { root.reconcile(true); }
    }

    // Each slot carries the gap after it, so one shrinking takes its gap along.
    spacing: 0
    height: Appearance.m.dockSlot

    Repeater {
        id: slots
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
            readonly property int slot: Dock.appKeys.indexOf(this.modelData.key)

            entry: this.modelData
            screen: root.screen
            panel: root.panel
            slide: root.slideFor(this.slot)
            rearranging: root.rearranging
            targetMagnification: root.magnifications[this.index] ?? 1
            onIndexChanged: root.geometryRevision++
            onClicked: (item, centerX) => root.activated(item, centerX)
            onHoverChanged: (key, label, centerX, entered) => root.childHover(key, label, centerX, entered)
            // Not inside the slot's signal, which dropping it destroys. Each
            // callback must be distinct: callLater(forget, key) coalesces a
            // simultaneous batch of exits and forgets only its last key.
            onGone: key => Qt.callLater(() => root.forget(key))

            onDragMoved: dx => {
                root.rearranging = true;
                root.drag = ({
                    from: this.modelData.key,
                    to: Dock.appKeys[Math.max(0, Math.min(Dock.items.length - 1,
                        this.slot + Math.round(dx / root.slotStride)))]
                });
            }
            onDragEnded: {
                const drag = root.drag;
                // Cleared before the move, so the offsets are already gone by
                // the time the new order is laid out, and not eased away.
                root.rearranging = false;
                root.drag = null;
                if (drag) {
                    Dock.moveItem(Dock.appKeys.indexOf(drag.from), Dock.appKeys.indexOf(drag.to));
                    // Laid out now, not at the next frame's polish: Qt checks
                    // hover before that, and found the old order's icon under
                    // the pointer, its wash on for six frames.
                    root.forceLayout();
                }
            }
        }
    }

    DockButton {
        id: launcher
        icon: "apps"
        tipText: qsTr("Applications")
        selected: Overlay.isOpen(Overlay.launcher)
        targetMagnification: root.magnifications[slots.count] ?? 1
        y: Appearance.m.dockSlot - height
        scheme: root.panel.schemeOver(launcher)
        onActivated: Overlay.toggle(Overlay.launcher, root.screen, launcher.centerX())
        onHoverChanged: (key, label, centerX, entered) => root.childHover(key, label, centerX, entered)
    }
}
