pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "root:/config"

/*!
    A time-series chart: each series a line over a fill fading to nothing at
    the baseline, the newest sample at the right edge and `span` seconds shown.

    `series` is `[{ points: [{ t, v }], color }]`, `now` the newest sample's t.
    `max` above 0 fixes the top of the scale (100 for a percentage); 0 or less
    follows the data: the largest value in the span, at least 1. A series with
    no point in the span draws nothing, and one point draws a dot.

    With `axes` the chart labels its scale (0, half and the top, through
    `format`) and its span, rules them faintly, and shows a crosshair and a
    readout of each series' value nearest the pointer. Without, it is a
    sparkline and takes no hover. The readout is information, not a control,
    so it is a plain HoverHandler.
*/
Item {
    id: root

    property var series: []
    property real now: 0
    property real span: 60
    property real max: 100
    property bool axes: false
    property var format: v => Math.round(v) + "%"

    /*! The scale's top: `max`, or the data's. */
    readonly property real effectiveMax: {
        if (root.max > 0)
            return root.max;
        let top = 1;
        for (const s of root.series)
            for (const p of root.drawn(s))
                top = Math.max(top, p.v);
        return top;
    }

    readonly property real plotX: root.axes ? Appearance.m.chartAxisWidth : 0
    readonly property real plotW: Math.max(1, root.width - root.plotX)
    readonly property real plotH: Math.max(1, root.height - (root.axes ? Appearance.m.chartAxisHeight : 0))

    /*! The samples of a series inside the span. */
    function drawn(s: var): var {
        return (s.points ?? []).filter(p => p.t >= root.now - root.span && p.t <= root.now);
    }

    /*! Where a sample is, in the chart's own coordinates. */
    function place(point: var, now: real): point {
        const y = root.plotH * (1 - point.v / root.effectiveMax);
        return Qt.point(root.plotX + root.plotW * (1 - (now - point.t) / root.span),
            Math.max(0, Math.min(root.plotH, y)));
    }

    function line(s: var): var {
        return root.drawn(s).map(p => root.place(p, root.now));
    }

    /*! A series' outline closed along the baseline, for the fill. */
    function area(s: var): var {
        const pts = root.line(s);
        if (pts.length < 2)
            return [];
        return [Qt.point(pts[0].x, root.plotH), ...pts, Qt.point(pts[pts.length - 1].x, root.plotH)];
    }

    /*! What the pointer is over: each series' nearest sample, and its age. */
    function nearest(s: var, t: real): var {
        let best = null;
        for (const p of root.drawn(s))
            if (best === null || Math.abs(p.t - t) < Math.abs(best.t - t))
                best = p;
        return best;
    }

    function readout(t: real): var {
        const rows = [];
        for (const s of root.series) {
            const p = root.nearest(s, t);
            if (p)
                rows.push({ color: s.color, text: root.format(p.v) + " · " + Math.round(root.now - p.t) + "s ago" });
        }
        return rows;
    }

    // Grid rules at 0, half and the top.
    Repeater {
        model: root.axes ? 3 : 0

        Item {
            id: rule
            required property int index
            readonly property real y0: root.plotH * (1 - rule.index / 2)

            Rectangle {
                x: root.plotX
                y: Math.min(rule.y0, root.plotH - height)
                width: root.plotW
                height: Appearance.m.border
                color: Appearance.c.border
            }

            Label {
                role: Label.Role.Caption
                faint: true
                text: root.format(root.effectiveMax * rule.index / 2)
                width: Appearance.m.chartAxisWidth - Appearance.s.xs
                horizontalAlignment: Text.AlignRight
                y: Math.max(0, Math.min(root.plotH - height, rule.y0 - height / 2))
            }
        }
    }

    Repeater {
        model: root.axes ? 5 : 0

        Label {
            id: tick
            required property int index
            role: Label.Role.Caption
            faint: true
            text: Math.round(root.span * (1 - tick.index / 4)) + "s"
            y: root.height - height
            x: root.plotX + root.plotW * tick.index / 4 - (tick.index === 0 ? 0 : tick.index === 4 ? width : width / 2)
        }
    }

    Repeater {
        model: root.series

        Item {
            id: one
            required property var modelData
            anchors.fill: parent
            readonly property var points: root.line(one.modelData)

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0
                        y1: 0
                        x2: 0
                        y2: root.plotH
                        GradientStop { position: 0; color: Qt.alpha(one.modelData.color, Appearance.m.chartFill) }
                        GradientStop { position: 1; color: Qt.alpha(one.modelData.color, 0) }
                    }
                    PathPolyline { path: root.area(one.modelData) }
                }

                ShapePath {
                    strokeWidth: Appearance.m.chartLine
                    strokeColor: one.modelData.color
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    PathPolyline { path: one.points }
                }
            }

            // A lone sample has no line to draw: a dot.
            Rectangle {
                visible: one.points.length === 1
                width: Appearance.m.chartDot * 2
                height: width
                radius: width / 2
                color: one.modelData.color
                x: (one.points[0]?.x ?? 0) - width / 2
                y: (one.points[0]?.y ?? 0) - height / 2
            }
        }
    }

    HoverHandler {
        id: hover
        enabled: root.axes
        readonly property bool inside: hover.hovered && hover.point.position.x >= root.plotX
            && hover.point.position.y <= root.plotH
    }

    Rectangle {
        visible: hover.inside
        x: hover.point.position.x - width / 2
        y: 0
        width: Appearance.m.chartCrosshair
        height: root.plotH
        color: Appearance.c.borderStrong
    }

    Rectangle {
        id: tip
        readonly property real t: root.now - root.span * (1 - (hover.point.position.x - root.plotX) / root.plotW)
        readonly property var rows: hover.inside ? root.readout(tip.t) : []
        visible: hover.inside && tip.rows.length > 0
        color: Appearance.c.surface
        border.color: Appearance.c.border
        border.width: Appearance.m.border
        radius: Appearance.r.xs
        width: col.implicitWidth + Appearance.s.sm * 2
        height: col.implicitHeight + Appearance.s.xs * 2
        x: hover.point.position.x > root.plotX + root.plotW / 2
            ? hover.point.position.x - width - Appearance.s.sm
            : hover.point.position.x + Appearance.s.sm
        y: Appearance.s.xs

        Column {
            id: col
            x: Appearance.s.sm
            y: Appearance.s.xs
            Repeater {
                model: tip.rows

                Row {
                    id: entry
                    required property var modelData
                    spacing: Appearance.s.xs
                    Rectangle {
                        width: Appearance.m.chartDot * 2
                        height: width
                        radius: width / 2
                        color: entry.modelData.color
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        role: Label.Role.Caption
                        text: entry.modelData.text
                    }
                }
            }
        }
    }
}
