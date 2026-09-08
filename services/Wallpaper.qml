pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
// Qualified: QtCore has a `Settings` of its own, which would shadow ours.
import QtCore as Core
import Qt.labs.folderlistmodel
import Quickshell

/*!
    The desktop wallpaper.

    The shell does not paint it — hyprpaper does, and it is already running with
    IPC open.  This drives that, one `hyprctl hyprpaper wallpaper` per output:
    the daemon loads the picture itself, so that request is the whole of the
    protocol needed here.  A background layer surface of our own would be a
    second thing painting the same pixels, and the overview plugin is patched to
    show the one hyprpaper puts up.

    hyprpaper forgets an IPC change when it restarts, so the choice is persisted
    and pushed again at startup.  Until the user makes one, whatever hyprpaper
    was configured with is left alone.

    One flat folder, not a search: a wallpaper directory is somewhere the user
    puts pictures, not somewhere to go hunting through.
*/
Singleton {
    id: root

    readonly property url folder:
        Core.StandardPaths.writableLocation(Core.StandardPaths.PicturesLocation) + "/Wallpapers"

    /*! Absolute paths, in name order. Empty when the folder is not there. */
    readonly property var items: {
        const out = [];
        for (let i = 0; i < pictures.count; i++)
            out.push(pictures.get(i, "filePath"));
        return out;
    }

    readonly property bool available: root.items.length > 0
    /*! The folder as a plain path, for telling someone where pictures go. */
    readonly property string folderPath: root.folder.toString().replace(/^file:\/\//, "")
    /*! The picture in force, or empty when the shell has never set one. */
    readonly property string current: Settings.wallpaper

    function set(path: string): void {
        Settings.setWallpaper(path);
    }

    /*! hyprpaper names its outputs the way Wayland does, which is what a screen
        is called here too. */
    function push(path: string): void {
        if (path === "")
            return;
        for (const screen of Quickshell.screens)
            Quickshell.execDetached(["hyprctl", "hyprpaper", "wallpaper", `${screen.name},${path}`]);
    }

    /*!
        Both the user picking a picture and the settings file finishing loading
        arrive here as the same thing — the choice changed — so the daemon is
        driven from one place.

        Keying off the value rather than off "the settings are loaded" is what
        makes the startup case work at all: the file is read asynchronously, and
        the choice is still empty at the moment loading is announced.
    */
    onCurrentChanged: root.push(root.current)

    Component.onCompleted: root.push(root.current)

    FolderListModel {
        id: pictures

        folder: root.folder
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
    }
}
