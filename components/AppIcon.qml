pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import "root:/config"

/*!
    An application icon resolved through the XDG icon theme.

    Falls back, in order, to an explicitly supplied fallback icon name, then to a
    generic window glyph, so a missing or broken icon can never leave a hole in
    the dock or the launcher.

    With `optical` set, the artwork is scaled and centred so it weighs as much
    as any other icon drawn so (IconShapes). It is measured once, by drawing it
    into a small canvas nobody sees, and drawn as it comes until then.
*/
Item {
    id: root

    /*! Icon theme name, absolute path, or file:/ URL. */
    property string source: ""
    property string fallbackIcon: "window"
    property int size: 32
    property bool optical: false
    /*!
        Draw it among the shell's own glyphs, in their ink (the tray): drained
        of colour, and a glyph of one tone — four fifths of its artwork or
        more on one side of mid grey (IconShapes) — levelled so that tone
        comes out in the ink and the other in the ink's opposite, so its shape
        reads on whatever the ink was chosen to read on, as legibly as its
        author drew it: a tray icon made for a dark panel comes out dark where
        the bar's text turns dark. Artwork of both tones — a light sign on a
        dark plate — reads on either already, and keeps them. Transparent,
        the default, draws it as it comes.
    */
    property color ink: "transparent"
    readonly property bool inked: root.ink.a > 0
    /*! How much of its artwork is light; until it is measured, all of it, as
        most tray icons are drawn. */
    readonly property real lightShare: root.shape?.light ?? 1
    readonly property bool levelled: root.inked && (root.lightShare >= 0.8 || root.lightShare <= 0.2)

    implicitWidth: root.size
    implicitHeight: root.size

    readonly property string resolved: {
        const s = root.source;
        if (s === "")
            return "";
        if (s.startsWith("/"))
            return "file://" + s;
        // Quickshell hands theme names on as image://icon/ URLs too (a
        // notification's image-path hint, a tray icon), and its provider
        // draws a magenta checkerboard for one the theme lacks instead of
        // failing. A plain one is checked like a bare name; a ?path= or
        // ?fallback= query is its own way out and is left to it.
        const themed = "image://icon/";
        if (s.startsWith(themed) && s.indexOf("?") === -1)
            return Quickshell.iconPath(s.slice(themed.length), true);
        if (s.indexOf("://") !== -1)
            return s;
        return Quickshell.iconPath(s, true);
    }

    readonly property bool usingFallback: root.resolved === "" || image.status === Image.Error
    readonly property var shape: (root.optical || root.inked) && root.resolved !== ""
        ? IconShapes.shapeOf(root.resolved, IconShapes.revision) : null
    /*! Where `optical` scales and centres it; nothing otherwise. */
    readonly property var fit: root.optical ? root.shape : null
    /*! The picture asked of the theme. With `optical`, one size whatever the
        scale comes to, and the largest it may: the theme can answer another
        size with another picture, margins and all, and the one measured has
        to be the one drawn — always drawn down, so it stays sharp. */
    readonly property int raster: root.optical ? Math.ceil(root.size * IconShapes.most) : root.size

    Item {
        anchors.fill: parent
        visible: !root.usingFallback
        layer.enabled: root.levelled
        layer.effect: LevelAdjust {
            readonly property color paper: Appearance.farthest(root.ink)
            readonly property bool light: root.lightShare >= 0.8

            // Alpha is levelled by the same rule, so the low end is clear and
            // the high end opaque: the icon keeps its own.
            minimumOutput: Qt.alpha(this.light ? this.paper : root.ink, 0)
            maximumOutput: Qt.alpha(this.light ? root.ink : this.paper, 1)
        }

        Image {
            id: image
            width: Math.round(root.size * (root.fit?.scale ?? 1))
            height: image.width
            x: Math.round((root.size - image.width) / 2 - (root.fit?.dx ?? 0) * image.width)
            y: Math.round((root.size - image.height) / 2 - (root.fit?.dy ?? 0) * image.height)
            source: root.resolved
            sourceSize.width: root.raster
            sourceSize.height: root.raster
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            mipmap: true
            layer.enabled: root.inked
            layer.effect: MultiEffect { saturation: -1 }
        }
    }

    Loader {
        active: (root.optical || root.inked) && root.shape === null && image.status === Image.Ready

        sourceComponent: Canvas {
            id: probe

            readonly property int n: 64

            width: probe.n
            height: probe.n
            // Painted, which a hidden item would not be, but never seen.
            opacity: 0

            onAvailableChanged: if (probe.available)
                probe.loadImage(root.resolved, Qt.size(root.raster, root.raster))
            onImageLoaded: probe.requestPaint()
            onPaint: {
                if (!probe.isImageLoaded(root.resolved))
                    return;
                const context = probe.getContext("2d");
                context.clearRect(0, 0, probe.n, probe.n);
                context.drawImage(root.resolved, 0, 0, probe.n, probe.n);
                IconShapes.measure(root.resolved, context.getImageData(0, 0, probe.n, probe.n).data, probe.n);
            }
        }
    }

    Icon {
        anchors.centerIn: parent
        visible: root.usingFallback
        name: root.fallbackIcon
        size: Math.round(root.size * 0.72)
        color: root.inked ? root.ink : Appearance.c.textMuted
    }
}
