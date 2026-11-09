pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import "root:/config"

Item {
    id: root
    property url source: ""

    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.source
        sourceSize.width: Math.ceil(width * LockStyle.wallpaperScale)
        sourceSize.height: Math.ceil(height * LockStyle.wallpaperScale)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    FastBlur {
        anchors.fill: parent
        source: wallpaper
        radius: LockStyle.blurRadius
        cached: true
        visible: wallpaper.status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: LockStyle.shade
    }
}
