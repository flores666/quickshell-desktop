pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    A row of choices wider than the room it has: wallpaper previews, font
    samples.

    Sideways is the axis a preview wants — a picture of a screen is wider than
    it is tall, and a line of type is nothing else — and it keeps the strip out
    of the settings pane's own vertical scroll.

    The wheel is deliberately not caught here.  A Flickable only ever spends the
    wheel on an axis it can actually flick, and this one cannot flick
    vertically, so a wheel over the strip passes through to the pane behind it
    and scrolls the page — which is the only thing the wheel does anywhere in
    the shell's panels.

    The bar beneath the strip is what moves it instead.  A preview keeps the
    press it is given, so that a click which drifts a few pixels is still a
    click rather than a scroll — which leaves the previews themselves
    undraggable, and a handle the only thing left to take hold of.  Callers give
    `cellHeight`, the room a preview gets, and the strip stands taller by what
    the bar needs under it.
*/
Item {
    id: root

    property alias model: view.model
    property alias delegate: view.delegate
    property alias currentIndex: view.currentIndex
    /*! Whether there is anything off the edge to scroll to. */
    readonly property bool overflowing: view.contentWidth > view.width + 1
    /*! How tall a preview stands. Delegates take their height from this rather
        than from the strip, which is taller by the bar's footprint. */
    property int cellHeight: 64

    implicitHeight: root.cellHeight + bar.footprint

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

    ThinScrollBar {
        id: bar

        flickable: view
        vertical: false
    }
}
