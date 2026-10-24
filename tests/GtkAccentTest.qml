import QtQuick
import Quickshell
import "root:/services"

/*!
    GTK's accent while the accent follows the wallpaper
    (docs/specs/wallpaper-accent.md, item 5): the libadwaita accent nearest to
    it, and the one there before given back when it stops. Only against
    tools/test.sh's gsettings, which keeps its values in a file of the run's
    own: anywhere else the test touches nothing and fails.
*/
Item {
    id: root

    Check {
        id: check
    }

    Command {
        id: sh
    }

    // Loaded only once the gsettings is known to be the tests' own.
    Loader {
        id: theme
        active: false
        source: Quickshell.shellPath("modules/common/DesktopTheme.qml")
    }

    readonly property string key: "org.gnome.desktop.interface accent-color"

    /*! GTK's accent once it is `want`, or as it stands after two seconds. */
    function accent(want: string, then: var): void {
        sh.run(`for i in $(seq 20); do
                v=$(gsettings get ${root.key})
                [ "$v" = "'$1'" ] && break
                sleep 0.1
            done
            printf '%s' "$v"`, [want], then);
    }

    function follow(wallpaper: string): void {
        Settings.setWallpaperAccent(wallpaper);
        Settings.setAccentFollowsWallpaper(true);
    }

    property bool started: false

    function begin(): void {
        if (root.started)
            return;
        root.started = true;
        // Asked first, before anything is set.
        sh.run("command -v gsettings", [], where => {
            if (!where.trim().startsWith(Quickshell.shellPath("tests/bin"))) {
                check.report("the tests' own gsettings", false, "got " + where.trim());
                check.done();
                return;
            }
            sh.run(`gsettings set ${root.key} purple`, [], () => root.run());
        });
    }

    function run(): void {
        check.attempt("before", () => {
            Settings.setAccentFollowsWallpaper(false);
            Settings.setWallpaperAccent("");
        });
        theme.active = true;
        check.equal("DesktopTheme loads", theme.status, Loader.Ready);
        check.attempt("a red wallpaper", () => root.follow("#c03030"));
        root.accent("red", red => {
            check.equal("a red wallpaper: red", red, "'red'");
            check.equal("a red wallpaper: GTK's own kept", Settings.gtkAccentBefore, "purple");
            check.attempt("a blue wallpaper", () => root.follow("#2050c0"));
            root.accent("blue", blue => {
                check.equal("a blue wallpaper: blue", blue, "'blue'");
                check.attempt("an orange wallpaper", () => root.follow("#e8702a"));
                root.accent("orange", orange => {
                    check.equal("an orange wallpaper: orange", orange, "'orange'");
                    check.equal("changed twice: GTK's own still kept", Settings.gtkAccentBefore, "purple");
                    check.attempt("not following", () => Settings.setAccentFollowsWallpaper(false));
                    root.accent("purple", back => {
                        check.equal("not following: GTK's own back", back, "'purple'");
                        check.equal("not following: none kept", Settings.gtkAccentBefore, "");
                        check.attempt("put back", () => Settings.setWallpaperAccent(""));
                        check.done();
                    });
                });
            });
        });
    }

    Connections {
        target: Settings

        function onReadyChanged(): void {
            if (Settings.ready)
                root.begin();
        }
    }

    Component.onCompleted: {
        if (Settings.ready)
            root.begin();
    }
}
