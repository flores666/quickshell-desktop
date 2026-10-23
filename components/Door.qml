pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    How a card that hangs from an edge comes and goes: it rolls out of that
    edge as it opens and back into it as it closes, as a garage door does. The
    card's own box grows from the edge, so its shadow, glass and corners follow
    with no clip line, and its contents ride the moving edge, the far end
    showing first. A popup's card under the bar or above the dock hangs from
    one (OverlayCard), and so does the dock's window preview (DockPreview).

    This is the motion alone: the card takes its height (`extent`), where its
    box starts (`drop`) and where its contents sit (`contentY`) from here, and
    fades in and out on its own.
*/
QtObject {
    id: root

    /*! The edge it hangs from: Qt.TopEdge or Qt.BottomEdge. */
    property int edge: Qt.TopEdge
    /*! Whether it is out, or on its way out. */
    property bool out: false
    /*! The card's height out, and the radius of its corners. */
    property real full: 0
    property real radius: 0

    /*! How far out it has rolled: 0 shut, 1 out. Out as a thing moving does,
        and back as quickly as a card fades, so it is in before the card goes. */
    property real rolled: root.out ? 1 : 0
    readonly property bool rolling: root.rolled < 1
    /*! Its height shut: as tall as its two corners, so that it is a rounded
        rectangle all the way out — shorter, its corners would meet and make
        it a capsule. */
    readonly property real shut: Math.min(root.full, root.radius * 2)
    /*! The card's height as drawn. */
    readonly property real extent: root.shut + (root.full - root.shut) * root.rolled
    /*! How far below its place out the card's box starts: its edge on the
        door stays put, and the other comes and goes. */
    readonly property real drop: root.edge === Qt.BottomEdge ? root.full - root.extent : 0
    /*! Where contents as tall as the card out sit in it: on the moving edge. */
    readonly property real contentY: root.edge === Qt.TopEdge ? root.extent - root.full : 0

    Behavior on rolled {
        id: roll
        // The target is set before the animation starts.
        NumberAnimation {
            duration: roll.targetValue > 0 ? Appearance.t.popupMove : Appearance.t.popupFade
            easing.type: roll.targetValue > 0 ? Appearance.t.emphasizedEasing : Appearance.t.standardEasing
        }
    }
}
