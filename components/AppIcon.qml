pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"

/*!
    An application icon resolved through the XDG icon theme.

    Falls back, in order, to an explicitly supplied fallback icon name, then to a
    generic window glyph, so a missing or broken icon can never leave a hole in
    the dock or the launcher.
*/
Item {
    id: root

    /*! Icon theme name, absolute path, or file:/ URL. */
    property string source: ""
    property string fallbackIcon: "window"
    property int size: 32

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

    Image {
        id: image
        anchors.fill: parent
        visible: !root.usingFallback
        source: root.resolved
        sourceSize.width: root.size
        sourceSize.height: root.size
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        mipmap: true
    }

    Icon {
        anchors.centerIn: parent
        visible: root.usingFallback
        name: root.fallbackIcon
        size: Math.round(root.size * 0.72)
        color: Appearance.c.textMuted
    }
}
