pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "root:/config"

/*! An indeterminate progress ring. Animates only while actually visible. */
Item {
    id: root

    property int size: Appearance.m.icon
    property color color: Appearance.c.accent
    property int thickness: 2

    implicitWidth: root.size
    implicitHeight: root.size

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: (root.size - root.thickness) / 2
                radiusY: (root.size - root.thickness) / 2
                startAngle: 0
                sweepAngle: 260
            }
        }

        RotationAnimator {
            target: shape
            running: root.visible
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }
    }
}
