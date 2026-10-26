import QtQuick
import Quickshell
import "root:/components"
import "root:/services"

/*!
    An icon installed while the shell runs (IconThemes): an AppIcon asking for
    a name no theme has draws the fallback glyph, and once the icon is put in
    a theme and the theme's cache rebuilt, as an install's last step does, the
    same AppIcon finds it. Only in tools/test.sh's data directory, the run's
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

    readonly property string theme: Quickshell.env("XDG_DATA_HOME") + "/icons/hicolor"
    // A 1×1 PNG.
    readonly property string png: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    property bool installing: false

    AppIcon {
        id: icon
    }

    function begin(): void {
        const ours = Quickshell.shellPath("tests").replace(/\/tree\/tests$/, "/data");
        if (Quickshell.env("XDG_DATA_HOME") !== ours) {
            check.report("the tests' own data directory", false, "got " + Quickshell.env("XDG_DATA_HOME"));
            check.done();
            return;
        }
        // A theme with a cache and no such icon, as before the install.
        sh.run(`mkdir -p "$1/48x48/apps" && gtk-update-icon-cache -q -f -t "$1"`, [root.theme], () => {
            icon.source = "shell-test-icon";
            check.report("the native module is loaded", IconThemes.watch !== null, "no IconThemeWatch");
            check.equal("not installed: not found", icon.resolved, "");
            check.equal("not installed: the fallback glyph", icon.usingFallback, true);
            root.installing = true;
            timeout.start();
            sh.run(`printf %s "$2" | base64 -d > "$1/48x48/apps/shell-test-icon.png"
                    gtk-update-icon-cache -q -f -t "$1"`, [root.theme, root.png], () => {});
        });
    }

    function finish(): void {
        if (!root.installing)
            return;
        root.installing = false;
        timeout.stop();
        check.equal("installed: found", icon.resolved, "image://icon/shell-test-icon");
        check.equal("installed: drawn", icon.usingFallback, false);
        check.done();
    }

    Connections {
        target: IconThemes

        // Every reading of the themes, the theme's own making among them, until
        // one finds the icon.
        function onRevisionChanged(): void {
            Qt.callLater(() => {
                if (icon.resolved !== "")
                    root.finish();
            });
        }
    }

    Timer {
        id: timeout
        interval: 3000
        onTriggered: root.finish()
    }

    Component.onCompleted: root.begin()
}
