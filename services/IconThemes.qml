pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    Conflux application icons, using standard XDG/platform fallback when
    artwork is absent. The native hook selects the theme without changing Qt's
    platform integration. `revision` turns over whenever one changes on disk,
    and whatever resolves an icon by name (AppIcon) reads it to ask again. So an
    application installed while the shell runs comes in with its own icon once
    the install has rebuilt the theme's cache.

    Qt reads each theme once per process, and only native code can have it read
    them again: that is the native module's icon-theme hook (native/, built by
    tools/build-native-module.sh, found through the unit's QML_IMPORT_PATH).
    Without it the themes stay as they were when the shell started, and a new
    icon shows after a restart.
*/
Singleton {
    id: root

    readonly property string themeName: "Conflux"
    readonly property int revision: root.watch?.revision ?? 0

    // The IconThemeWatch, created from a string so that a missing module is an
    // exception here rather than a shell that does not load.
    property var watch: null

    function imageSource(source: string): string {
        void root.revision;
        return typeof root.watch?.imageSource === "function" ? root.watch.imageSource(source) : source;
    }

    function iconPath(name: string): string {
        void root.revision;
        if (typeof root.watch?.iconAvailable === "function")
            return root.watch.iconAvailable(name) ? Quickshell.iconPath(name, false) : "";
        return Quickshell.iconPath(name, true);
    }

    function sync(): void {
        if (Settings.ready && root.watch !== null)
            root.watch.selectTheme(root.themeName);
    }

    Connections {
        target: Settings
        function onReadyChanged(): void { root.sync(); }
    }

    Component.onCompleted: {
        try {
            root.watch = Qt.createQmlObject("import Desktop.Native; IconThemeWatch {}", root, "IconThemes");
            root.sync();
        } catch (e) {
            console.warn("IconThemes: the native module is not loaded (tools/build-native-module.sh);",
                "icons installed from now on show after a restart");
        }
    }
}
