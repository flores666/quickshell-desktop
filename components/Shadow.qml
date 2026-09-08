pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "root:/config"

/*!
    A single soft drop shadow for an opaque rounded surface.

    One gaussian-blurred silhouette — no stacked layers, no banding, no halo.
    The blurred source is a plain rounded rectangle, independent of whatever the
    surface contains, so its texture is rendered once and reused: the shadow
    costs nothing while the surface's contents animate.

    Place it as a sibling *behind* the surface it belongs to, with the same
    geometry and radius.
*/
Item {
    id: root

    /*! 0 = none, 1 = resting chrome, 2 = raised card, 3 = floating overlay. */
    property int level: 2
    property int radius: Appearance.r.md

    readonly property var spec: Appearance.shadowFor(root.level)
    /*! Room for the blur to spread past the shape without being clipped. */
    readonly property int pad: root.spec.pad

    visible: root.level > 0
    z: -1

    Item {
        // The layered item is larger than the shape, which is what keeps the
        // blur from being cut off at its own edges.
        anchors.fill: parent
        anchors.margins: -root.pad
        layer.enabled: root.visible
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: Math.max(2, root.spec.blur)
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.pad
            // The whole shape sits a little lower than the surface it backs.
            anchors.topMargin: root.pad + root.spec.y
            anchors.bottomMargin: root.pad - root.spec.y
            radius: root.radius
            color: Qt.alpha(Appearance.c.shadow,
                Appearance.c.shadowStrength * root.spec.alpha)
            antialiasing: true
        }
    }
}
