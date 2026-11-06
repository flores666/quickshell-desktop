pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "root:/config"

/*!
    The drop shadow of a rounded surface: one RectangularShadow per layer of
    its elevation's preset (Appearance.shadowFor).

    Each layer is computed from the shape alone, so it
    costs nothing while the surface's contents animate, and it spreads as far
    as the preset asks. MultiEffect's blur, which this used to be, tops out at
    a gaussian of σ 20 — short of the floating shadow's 22.5.

    Place it as a sibling *behind* the surface it belongs to, with the same
    geometry and radius.
*/
Item {
    id: root

    /*! 0 = none, 1 = resting chrome, 2 = raised card, 3 = floating overlay. */
    property int level: 2
    property int radius: Appearance.r.md
    /*! Transmitting popup glass must not look through the shadow's solid core. */
    property bool hollow: false

    Item {
        id: cutout
        width: root.width + root.pad * 2
        height: root.height + root.pad * 2
        visible: false
        layer.enabled: root.hollow && root.visible
        Rectangle {
            x: root.pad; y: root.pad
            width: root.width; height: root.height
            radius: root.radius
        }
    }

    readonly property var spec: Appearance.shadowFor(root.level)
    /*! Room for the shadow to spread past the shape without being clipped. */
    readonly property int pad: root.spec.pad

    visible: root.level > 0
    z: -1

    Item {
        x: -root.pad; y: -root.pad
        width: root.width + root.pad * 2
        height: root.height + root.pad * 2
        layer.enabled: root.hollow && root.visible
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: cutout
            maskInverted: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Repeater {
            model: root.spec.layers

            RectangularShadow {
                required property var modelData

                x: root.pad; y: root.pad
                width: root.width; height: root.height
                offset.y: modelData.y
                // CSS's blur is twice its gaussian's σ; this one's falls off like a
                // gaussian of σ (3 × blur − 4) / 8, measured on Qt 6.12.
                blur: (modelData.blur + 1) * 4 / 3
                radius: root.radius
                color: Qt.alpha(Appearance.c.shadow, modelData.alpha)
            }
        }
    }
}
