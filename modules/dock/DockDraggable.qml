pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"

/*! The shared click and horizontal drag gesture for movable dock items. */
Clickable {
    id: root

    required property ShellScreen screen
    required property Surface panel
    property real slide: 0
    property bool rearranging: false
    property bool dragging: false
    property bool dragged: false
    property real originX: 0
    property real dragX: 0

    signal invoked
    signal dragMoved(real dx)
    signal dragFinished(bool dropped)
    signal hoverChanged(var key, string label, real centerX, bool entered)

    radius: Appearance.r.capsule(root.height)
    focusable: false
    scheme: root.panel.schemeOver(root)
    cursorShape: root.dragging ? Qt.ClosedHandCursor
        : root.hovered ? Qt.PointingHandCursor : Qt.ArrowCursor

    Behavior on slide {
        enabled: root.rearranging
        NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
    }

    transform: Translate { x: root.dragging ? root.dragX : root.slide }

    function centerX(): real {
        const surface = root.QsWindow.contentItem;
        return surface ? root.mapToItem(surface, root.width / 2, 0).x : 0;
    }

    function finishDrag(dropped: bool): void {
        if (root.dragging) {
            root.dragging = false;
            root.dragFinished(dropped);
        }
    }

    onPointerPressed: event => {
        if (event.button === Qt.LeftButton) {
            root.dragged = false;
            root.originX = root.mapToItem(null, event.x, 0).x;
        }
    }
    onPointerMoved: event => {
        if (!(event.buttons & Qt.LeftButton))
            return;
        const x = root.mapToItem(null, event.x, 0).x;
        if (!root.dragging) {
            if (Math.abs(x - root.originX) < Application.styleHints.startDragDistance)
                return;
            root.originX = x;
            root.dragX = 0;
            root.dragged = true;
            root.dragging = true;
        }
        root.dragX = x - root.originX;
        root.dragMoved(root.dragX);
    }
    onPointerReleased: event => {
        if (event.button === Qt.LeftButton)
            root.finishDrag(true);
    }
    onPointerCanceled: root.finishDrag(false)
    onClicked: event => {
        if (!root.dragged || event === null)
            root.invoked();
    }
}
