pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

/*!
    Its children, cut to a rounded rectangle by one mask: ColorPicker's square
    gradients (a Rectangle with both a gradient and a radius ignores its
    parents' opacity), and a popup's contents while its card flies or resizes
    (OverlayCard), when they are bigger than the card and a plain `clip`
    leaves them square in its corners.

    Two layers and an effect while `active`; nothing at all while not, when
    the children are drawn as they are.
*/
Item {
    id: root

    property real radius: 0
    property bool active: true
    default property alias content: body.data

    Rectangle {
        id: shape
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: root.active
    }

    Item {
        id: body
        anchors.fill: parent
        layer.enabled: root.active
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: shape
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }
}
