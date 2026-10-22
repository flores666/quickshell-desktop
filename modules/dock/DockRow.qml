pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
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
    /*! Where the grid's button is, for the divider before it. */
    readonly property real launcherX: launcher.x

    /*! Reported to the dock, which owns the tooltip and the preview, and
        decides what a click on an application does. */
    signal childHover(string key, string label, real centerX, bool entered)
    signal activated(var item, real centerX)

    /*!
        The drag in flight: the slot the icon came from, and the slot it would
        land in.

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

    readonly property int slotStride: Appearance.m.dockSlot + Appearance.m.dockGap

    /*! How far an icon has to step aside to open a gap where the drag will land. */
    function slideFor(slot: int): real {
        if (!root.drag || slot === root.drag.from || slot === -1)
            return 0;
        if (slot > root.drag.from && slot <= root.drag.to)
            return -root.slotStride;
        if (slot < root.drag.from && slot >= root.drag.to)
            return root.slotStride;
        return 0;
    }

    /*! [{ key, item, leaving, arriving }]: what the row draws. */
    property var drawn: []

    /*! Dock's list, with each application that has left kept after the one
        it stood behind until it has shrunk away. */
    function reconcile(arriving: bool): void {
        const out = Dock.items.map(item => ({ key: item.key, item, leaving: false, arriving }));
        let behind = -1;
        for (const e of root.drawn) {
            const at = out.findIndex(o => o.key === e.key);
            if (at !== -1) {
                behind = at;
                continue;
            }
            behind += 1;
            out.splice(behind, 0, { key: e.key, item: e.item, leaving: true, arriving: false });
        }
        root.drawn = out;
    }

    function forget(key: string): void {
        root.drawn = root.drawn.filter(e => !(e.key === key && e.leaving));
    }

    Component.onCompleted: root.reconcile(false)

    Connections {
        target: Dock
        function onItemsChanged(): void { root.reconcile(true); }
    }

    // Each slot carries the gap after it, so one shrinking takes its gap along.
    spacing: 0

    Repeater {
        // By key, so a slot lives as long as its application is drawn.
        model: ScriptModel {
            values: root.drawn
            objectProp: "key"
        }

        DockSlot {
            required property var modelData
            readonly property int slot: Dock.appKeys.indexOf(this.modelData.key)

            entry: this.modelData
            screen: root.screen
            slide: root.slideFor(this.slot)
            rearranging: root.drag !== null
            onClicked: (item, centerX) => root.activated(item, centerX)
            onHoverChanged: (key, label, centerX, entered) => root.childHover(key, label, centerX, entered)
            // Not from inside the slot's own signal, which dropping it destroys.
            onGone: key => Qt.callLater(root.forget, key)

            onDragMoved: dx => root.drag = ({
                from: this.slot,
                to: Math.max(0, Math.min(Dock.items.length - 1,
                    this.slot + Math.round(dx / root.slotStride)))
            })
            onDragEnded: {
                const drag = root.drag;
                // Cleared before the move, so the offsets are already gone by
                // the time the new order is laid out.
                root.drag = null;
                if (drag)
                    Dock.moveItem(drag.from, drag.to);
            }
        }
    }

    DockButton {
        id: launcher
        icon: "apps"
        tipText: qsTr("Applications")
        selected: Overlay.isOpen(Overlay.launcher)
        onActivated: Overlay.toggle(Overlay.launcher, root.screen)
        onHoverChanged: (key, label, centerX, entered) => root.childHover(key, label, centerX, entered)
    }
}
