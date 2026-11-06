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

    readonly property var glyph: Icons.glyphs[root.name] ?? []
    readonly property bool valid: root.glyph.length > 0

    implicitWidth: root.size
    implicitHeight: root.size

    Shape {
        anchors.centerIn: parent
        width: Icons.extent
        height: Icons.extent
        scale: root.size / Icons.extent
        visible: root.valid
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false
        layer.enabled: false

        GlyphPath { part: 0 }
        GlyphPath { part: 1 }
        GlyphPath { part: 2 }
    }

    // The generator rejects artwork needing more than these three style
    // groups. Identical strokes share a path, while caps, joins and dot widths
    // retain the source artwork's settings.
    component GlyphPath: ShapePath {
        id: stroke
        required property int part
        readonly property var group: root.glyph[stroke.part] ?? null

        strokeWidth: stroke.group?.width ?? -1
        strokeColor: root.color
        fillColor: "transparent"
        capStyle: stroke.group?.cap === "round" ? ShapePath.RoundCap
            : stroke.group?.cap === "square" ? ShapePath.SquareCap : ShapePath.FlatCap
        joinStyle: stroke.group?.join === "round" ? ShapePath.RoundJoin
            : stroke.group?.join === "bevel" ? ShapePath.BevelJoin : ShapePath.MiterJoin

        PathSvg { path: stroke.group?.d ?? "" }
    }
}
