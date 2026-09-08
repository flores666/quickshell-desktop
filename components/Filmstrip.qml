pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    A row of choices wider than the room it has: wallpaper previews, font
    samples.

    Sideways is the axis a preview wants — a picture of a screen is wider than
    it is tall, and a line of type is nothing else — and it keeps the strip out
    of the settings pane's own vertical scroll, which a stacked list of the same
    previews would fight with for the wheel.

    A Flickable only ever spends the wheel on an axis it can actually flick, so
    this one, which cannot flick vertically, hands a plain wheel straight to the
    pane behind it and leaves its own far end unreachable.  Hence `roll`: either
    axis of the wheel becomes travel along this one, and a trackpad's sideways
    swipe lands in the same place.

    The wheel is caught by a button-less MouseArea over the strip rather than
    by a WheelHandler: a handler declared inside the list is adopted into the
    list's scrolling content and never registered, and one on this wrapper is
    never offered the event either.  Taking no buttons is what keeps the
    previews underneath clickable.
*/
Item {
    id: root

    property alias model: view.model
    property alias delegate: view.delegate
    property alias currentIndex: view.currentIndex
    /*! Whether there is anything off the edge to scroll to. */
    readonly property bool overflowing: view.contentWidth > view.width + 1

    /*! Travel by a wheel's worth of rotation, in eighths of a degree. */
    function roll(delta: real): void {
        const reach = Math.max(0, view.contentWidth - view.width);
        view.contentX = Math.max(0, Math.min(reach, view.contentX - delta));
    }

    ListView {
        id: view

        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: Appearance.s.md
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        // The keyboard is left to the surface, the way every other list in the
        // shell leaves it: tabbing through a few hundred fonts is not
        // navigation, and arrow keys would fight the binding on currentIndex.
        keyNavigationEnabled: false

        /*! Open on the choice already in force rather than at the left edge.
            Deferred because the strip has no width to measure against yet. */
        Component.onCompleted: Qt.callLater(() =>
            view.positionViewAtIndex(view.currentIndex, ListView.Contain))
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        onWheel: event => root.roll(event.angleDelta.y !== 0
            ? event.angleDelta.y : event.angleDelta.x)
    }
}
