pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*! Reveal the focused control when it is reached by keyboard or moved by layout. */
Item {
    id: root

    default property alias contents: view.flickableData
    property alias contentHeight: view.contentHeight
    readonly property alias viewport: view
    property int leftGutter: 0
    property int rightGutter: 0
    property int bottomGutter: 0
    property var dragPoint: null
    signal contentMoved
    readonly property real contentWidth: Math.max(0, view.width - root.leftGutter - bar.footprint)
    readonly property Item focusedControl: root.visible ? root.Window.activeFocusItem : null
    readonly property var focusedBounds: {
        const control = root.focusedControl;
        let y = 0;
        let height = control?.height ?? 0;
        // Measure within the content so scrolling does not trigger another reveal.
        for (let item = control; item; item = item.parent) {
            if (item === view.contentItem)
                return { y, height };
            const card = item as DailyNoteCategory;
            const scale = card?.layoutScale ?? 1;
            y = y * scale + item.y;
            height *= scale;
        }
        return null;
    }

    onFocusedBoundsChanged: Qt.callLater(root.revealFocus)
    onHeightChanged: Qt.callLater(root.revealFocus)
    onDragPointChanged: root.scrollForDrag()

    function reset(): void {
        view.cancelFlick();
        view.contentY = view.originY;
    }

    function revealFocus(): void {
        const bounds = root.focusedBounds;
        if (bounds)
            root.revealBounds(bounds.y, bounds.height);
    }

    function revealBounds(y: real, height: real): void {
        if (!bar.overflowing || root.dragPoint !== null)
            return;
        const top = Math.max(view.originY, y - Appearance.s.xs);
        const bottom = Math.min(view.originY + view.contentHeight, y + height + Appearance.s.xs);
        if (top < view.contentY || bottom > view.contentY + view.height) {
            view.cancelFlick();
            view.contentY = top < view.contentY ? top : Math.min(top, bottom - view.height);
        }
    }

    function scrollForDrag(): void {
        const point = root.dragPoint;
        if (point === null || !root.visible) {
            edgeScroll.stop();
            return;
        }
        const local = root.mapFromItem(null, point.x, point.y);
        const edge = Math.min(Appearance.windowDrag.edge, root.height / 2);
        const inside = local.x >= 0 && local.x < root.width && local.y >= 0 && local.y < root.height;
        let destination = view.contentY;
        if (inside && local.y < edge)
            destination = view.originY;
        else if (inside && local.y >= root.height - edge)
            destination = view.originY + bar.reach;
        if (edgeScroll.running && edgeScroll.to === destination)
            return;
        edgeScroll.stop();
        if (destination === view.contentY)
            return;
        view.cancelFlick();
        edgeScroll.from = view.contentY;
        edgeScroll.to = destination;
        edgeScroll.duration = Math.ceil(Math.abs(destination - view.contentY) * 1000 / Appearance.t.noteDragScrollSpeed);
        edgeScroll.start();
    }

    NumberAnimation {
        id: edgeScroll
        target: view
        property: "contentY"
    }

    Flickable {
        id: view
        anchors.fill: parent
        anchors.leftMargin: -root.leftGutter
        anchors.rightMargin: -root.rightGutter
        anchors.bottomMargin: -root.bottomGutter
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        onContentYChanged: if (root.dragPoint !== null) root.contentMoved()
        onContentHeightChanged: if (root.dragPoint !== null) Qt.callLater(root.scrollForDrag)
    }

    ThinScrollBar { id: bar; flickable: view }
}
