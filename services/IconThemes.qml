pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    The icon themes as the shell reads them: `revision` turns over whenever one
    changes on disk, and whatever resolves an icon by name (AppIcon) reads it to
    ask again. So an application installed while the shell runs comes in with
    its own icon once the install has rebuilt the theme's cache.

    Qt reads each theme once per process, and only native code can have it read
    them again: that is the native module's one job (native/, built by
    tools/build-native-module.sh, found through the unit's QML_IMPORT_PATH).
    Without it the themes stay as they were when the shell started, and a new
    icon shows after a restart.
*/
Singleton {
    id: root

    readonly property int revision: root.watch?.revision ?? 0

    // The IconThemeWatch, created from a string so that a missing module is an
    // exception here rather than a shell that does not load.
    property var watch: null

    Component.onCompleted: {
        try {
            root.watch = Qt.createQmlObject("import Desktop.Native; IconThemeWatch {}", root, "IconThemes");
        } catch (e) {
            console.warn("IconThemes: the native module is not loaded (tools/build-native-module.sh);",
                "icons installed from now on show after a restart");
        }
    }
}
