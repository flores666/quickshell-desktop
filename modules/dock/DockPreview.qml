pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The windows of an application with several open, over its icon in the
    dock: a live picture of each, named by its title. A click on one brings
    that window forward; its button closes it. One window needs no telling
    apart, so an application with one has the tooltip instead.

    It opens once the pointer has rested on the icon, or at once on a click
    on it, and closes a moment after the pointer has left both it and the
    icons. On its way up from the icon to the windows the pointer crosses
    other icons; inside the triangle from where it left the icon to the two
    ends of the card's lower edge, they do not count (`aim`). Resting on
    another application's icon (`t.hop`), the preview rolls back in and out
    again over that one, if it has windows to show. It lives in the
    dock's window, as the tooltip does, and reaches down over the gap to the
    icons, so moving up from an icon onto it never leaves its hover. It rolls
    up out of the dock and back down into it, as a popup above the dock does
    (Door).
*/
Item {
    id: root

    /*! The top of the dock as drawn, which this stands on. */
    required property real dockTop
    required property ShellScreen screen
    /*! Closed, and kept closed, while the dock is busy otherwise. */
    property bool suppressed: false

    /*! The application shown, by key; "" while none is. */
    property string key: ""
    property real anchorX: 0
    /*! The icon under the pointer whose preview is shown, or is to be. */
    property string pointed: ""
    property real pointedX: 0
    /*! Where the pointer is on the dock, in the dock's window; null off it. */
    property var pointer: null
    /*! Where the pointer left the icon of the application shown: the apex of
        the triangle it is safe in, whose base is the card's lower edge. Null
        once it strays out of it, or there is none. */
    property var aim: null
    /*! The application to show once this one has rolled in: { key, x }. */
    property var next: null

    readonly property var item: root.key === "" ? null
        : Dock.items.find(i => i.key === root.key && root.offers(i)) ?? null
    readonly property bool shown: root.item !== null && !root.suppressed
    readonly property bool hovered: hover.hovered
    /*! What is drawn: the application last shown, kept through the fade out. */
    property var held: null

    readonly property int pad: Appearance.s.lg
    readonly property int count: root.held ? root.held.windows.length : 0
    readonly property int screenWidth: root.screen ? root.screen.width : 1920
    readonly property int boxHeight: Appearance.m.dockPreview
    readonly property int boxWidth: Math.round(root.boxHeight
        * root.screenWidth / (root.screen ? root.screen.height : 1080))
    /*! Below 1 when the windows would not fit across the screen at full size. */
    readonly property real fit: {
        const around = root.pad * 2 + root.count * Appearance.s.sm * 2
            + Math.max(0, root.count - 1) * Appearance.s.xs + Appearance.s.md * 2;
        return Math.min(1, (root.screenWidth - around) / Math.max(1, root.count * root.boxWidth));
    }
    /*! Room the dock's window keeps above the dock, so that the preview at
        full size, and its shadow, never need the window to grow. */
    readonly property int room: Appearance.shadowFor(3).pad + root.pad * 2 + Appearance.s.sm * 3
        + Appearance.m.iconLg + root.boxHeight + Appearance.m.popupGap

    /*! Whether a dock item gets a preview rather than the tooltip. Closing
        all but one of its windows closes the preview, too. */
    function offers(item: var): bool {
        return (item?.windows.length ?? 0) > 1;
    }

    function offersKey(key: string): bool {
        return root.offers(Dock.items.find(i => i.key === key) ?? null);
    }

    /*! Whether the pointer is on its way to the windows: inside the triangle
        from `aim` to the two ends of the card's lower edge, as they stand. */
    function aiming(p: point): bool {
        if (root.aim === null)
            return false;
        const bottom = root.y + card.height;
        const a = root.aim;
        const b = Qt.point(root.x, bottom);
        const c = Qt.point(root.x + card.width, bottom);
        // Which side of each edge it is on; inside, never both.
        const side = (u, v) => (p.x - v.x) * (u.y - v.y) - (u.x - v.x) * (p.y - v.y);
        const sides = [side(a, b), side(b, c), side(c, a)];
        return !(sides.some(d => d < 0) && sides.some(d => d > 0));
    }

    /*! An icon took the pointer. */
    function enter(key: string, x: real): void {
        linger.stop();
        root.pointed = key;
        root.pointedX = x;
        if (root.key === "") {
            if (root.offersKey(key))
                dwell.restart();
            else
                dwell.stop();
        } else if (key === root.key) {
            hop.stop();
            root.aim = null;
        } else {
            hop.restart();
        }
    }

    /*! A click on the icon of an application it offers: shown at once. */
    function show(key: string, x: real): void {
        root.enter(key, x);
        dwell.stop();
        hop.stop();
        root.next = null;
        root.key = key;
        root.anchorX = x;
    }

    /*! An icon lost the pointer. */
    function leave(key: string): void {
        if (key === root.key && root.shown && root.pointer !== null)
            root.aim = root.pointer;
        if (root.pointed !== key)
            return;
        root.pointed = "";
        dwell.stop();
        hop.stop();
        linger.restart();
    }

    function close(): void {
        dwell.stop();
        linger.stop();
        hop.stop();
        root.aim = null;
        root.next = null;
        root.key = "";
    }

    onItemChanged: if (root.item) root.held = root.item
    onSuppressedChanged: if (root.suppressed) root.close()

    // On its way to the windows, what the pointer passes over neither takes
    // the preview nor, between the icons, closes it; strayed out of the
    // triangle, it is on its way nowhere.
    onPointerChanged: {
        if (root.aim === null || root.pointer === null)
            return;
        if (!root.aiming(root.pointer)) {
            root.aim = null;
            return;
        }
        if (hop.running)
            hop.restart();
        if (linger.running)
            linger.restart();
    }

    // Rolled in for another application: out again over it, if the pointer
    // is still there.
    onVisibleChanged: if (!root.visible && root.next !== null) {
        const next = root.next;
        root.next = null;
        if (root.pointed === next.key) {
            root.key = next.key;
            root.anchorX = next.x;
        }
    }

    Timer {
        id: dwell
        interval: Appearance.t.dwell
        onTriggered: {
            root.key = root.pointed;
            root.anchorX = root.pointedX;
        }
    }

    Timer {
        id: linger
        interval: Appearance.t.linger
        onTriggered: if (!root.hovered && root.pointed === "") root.close()
    }

    Timer {
        id: hop
        interval: Appearance.t.hop
        onTriggered: {
            if (root.hovered || root.pointed === "" || root.pointed === root.key)
                return;
            root.next = root.offersKey(root.pointed) ? { key: root.pointed, x: root.pointedX } : null;
            root.aim = null;
            root.key = "";
        }
    }

    // Centred over the icon, never past the screen's edges; the strip below the
    // card reaches down to the icons' top.
    x: Math.round(Math.max(Appearance.s.md,
        Math.min(root.screenWidth - root.width - Appearance.s.md, root.anchorX - root.width / 2)))
    y: root.dockTop + Appearance.m.dockFrame - root.height
    width: card.width
    height: card.height + Appearance.m.popupGap + Appearance.m.dockFrame
    visible: opacity > 0
    opacity: root.shown ? 1 : 0

    Behavior on opacity {
        NumberAnimation { duration: Appearance.t.popupFade; easing.type: Appearance.t.standardEasing }
    }

    // Standing on the dock, this keeps its bottom edge where it is as its
    // height changes, so the card's top is the door's moving edge.
    Door {
        id: roller
        edge: Qt.BottomEdge
        out: root.shown
        full: row.height + root.pad * 2
        radius: card.radius
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hover.hovered) {
                linger.stop();
                hop.stop();
                root.aim = null;
            } else if (root.pointed === "") {
                linger.restart();
            }
        }
    }

    Surface {
        id: card

        width: row.width + root.pad * 2
        height: roller.extent
        radius: Appearance.r.panel
        elevation: 3

        RoundedClip {
            anchors.fill: parent
            // The windows are laid out at the card's full height, and ride
            // its top edge out of the dock and back.
            clip: true
            radius: card.radius
            active: roller.rolling

            Row {
                id: row

                x: root.pad
                y: root.pad
                spacing: Appearance.s.xs

                Repeater {
                    // Only while drawn: each picture streams for as long as it exists.
                    model: ScriptModel {
                        values: root.visible && root.held ? root.held.windows.filter(w => w) : []
                    }

                    WindowPreview {
                        required property var modelData

                        window: this.modelData
                        icon: root.held?.icon ?? ""
                        boxWidth: Math.floor(root.boxWidth * root.fit)
                        boxHeight: Math.floor(root.boxHeight * root.fit)
                        onClicked: {
                            Compositor.focusWindow(this.modelData);
                            root.close();
                        }
                    }
                }
            }
        }
    }
}
