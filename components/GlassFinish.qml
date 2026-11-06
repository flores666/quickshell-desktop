pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "root:/config"

/*! A square reflection clipped once, plus one gradient-filled outline ring.
    No rounded gradient Rectangle: Qt loses inherited alpha on that path. */
Item {
    id: root
    required property real radius
    required property real borderWidth

    RoundedClip {
        anchors.fill: parent
        radius: root.radius
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: PopupStyle.reflection }
                GradientStop { position: PopupStyle.reflectionKnee; color: PopupStyle.reflectionEnd }
                GradientStop { position: 1; color: PopupStyle.reflectionEnd }
            }
        }
    }

    Shape {
        anchors.fill: parent
        visible: root.borderWidth > 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill
            fillGradient: LinearGradient {
                y2: root.height
                GradientStop { position: 0; color: PopupStyle.rimTop }
                GradientStop { position: 1; color: PopupStyle.rimBottom }
            }
            PathRectangle { width: root.width; height: root.height; radius: root.radius }
            PathRectangle {
                x: root.borderWidth; y: root.borderWidth
                width: Math.max(0, root.width - root.borderWidth * 2)
                height: Math.max(0, root.height - root.borderWidth * 2)
                radius: Math.max(0, root.radius - root.borderWidth)
            }
        }
    }
}
