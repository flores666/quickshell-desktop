pragma ComponentBehavior: Bound

import QtQuick
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
    readonly property var shape: root.optical && root.resolved !== ""
        ? IconShapes.shapeOf(root.resolved, IconShapes.revision) : null
    /*! The picture asked of the theme. With `optical`, one size whatever the
        scale comes to, and the largest it may: the theme can answer another
        size with another picture, margins and all, and the one measured has
        to be the one drawn — always drawn down, so it stays sharp. */
    readonly property int raster: root.optical ? Math.ceil(root.size * IconShapes.most) : root.size

    Image {
        id: image
        width: Math.round(root.size * (root.shape?.scale ?? 1))
        height: image.width
        x: Math.round((root.size - image.width) / 2 - (root.shape?.dx ?? 0) * image.width)
        y: Math.round((root.size - image.height) / 2 - (root.shape?.dy ?? 0) * image.height)
        visible: !root.usingFallback
        source: root.resolved
        sourceSize.width: root.raster
        sourceSize.height: root.raster
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        mipmap: true
    }

    Loader {
        active: root.optical && root.shape === null && image.status === Image.Ready

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
        color: Appearance.c.textMuted
    }
}
