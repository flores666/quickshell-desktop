pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "root:/config"

/*!
    A monochrome UI glyph drawn from vector path data.

    Icons come from the generated Icons singleton and are rendered with
    QtQuick.Shapes' curve renderer, so they stay crisp at any size and take their
    colour directly from the design system — no image loading, no colourising
    shader, no offscreen layer per icon.
*/
Item {
    id: root

    /*! Key into Icons.glyphs, e.g. "wifi-good". */
    property string name
    property color color: Appearance.c.text
    property int size: Appearance.m.icon

    readonly property var glyph: Icons.glyphs[root.name] ?? null
    readonly property bool valid: root.glyph !== null

    implicitWidth: root.size
    implicitHeight: root.size

    Shape {
        anchors.centerIn: parent
        width: 16
        height: 16
        scale: root.size / 16
        visible: root.valid
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false
        layer.enabled: false

        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.WindingFill
            fillColor: root.glyph && root.glyph.paths.length > 0
                ? Qt.alpha(root.color, root.color.a * root.glyph.paths[0].o)
                : "transparent"
            PathSvg {
                path: root.glyph && root.glyph.paths.length > 0 ? root.glyph.paths[0].d : ""
            }
        }

        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.WindingFill
            fillColor: root.glyph && root.glyph.paths.length > 1
                ? Qt.alpha(root.color, root.color.a * root.glyph.paths[1].o)
                : "transparent"
            PathSvg {
                path: root.glyph && root.glyph.paths.length > 1 ? root.glyph.paths[1].d : ""
            }
        }
    }
}
