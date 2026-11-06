import QtQuick
import Quickshell
import "root:/components"
import "root:/services"

/*!
    Conflux stays selected in either shell scheme, inherits absent artwork,
    and discovers icons installed while the shell runs. Conflux and hicolor
    are private fixtures in tools/test.sh's data directory.
*/
Item {
    id: root

    Check {
        id: check
    }

    Command {
        id: sh
    }

    Until {
        id: selected
    }

    readonly property string icons: Quickshell.env("XDG_DATA_HOME") + "/icons"
    readonly property string theme: root.icons + "/hicolor"
    // A 1×1 PNG.
    readonly property string png: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    property bool started: false
    property bool installing: false
    property string originalTheme

    AppIcon {
        id: icon
    }

    AppIcon {
        id: themedIcon
    }

    AppIcon {
        id: inheritedIcon
    }

    AppIcon {
        id: truncatedIcon
    }

    function begin(): void {
        if (root.started)
            return;
        root.started = true;
        const ours = Quickshell.shellPath("tests").replace(/\/tree\/tests$/, "/data");
        if (Quickshell.env("XDG_DATA_HOME") !== ours) {
            check.report("the tests' own data directory", false, "got " + Quickshell.env("XDG_DATA_HOME"));
            check.done();
            return;
        }
        root.originalTheme = Settings.effectiveDark ? "dark" : "light";
        // A theme-only icon proves Qt selected Conflux; hicolor supplies an
        // icon absent from it. Neither depends on themes installed by the user.
        sh.run(`for variant in hicolor Conflux; do
                    target="$1/$variant"
                    mkdir -p "$target/48x48/apps"
                    inherits=hicolor
                    [ "$variant" = hicolor ] && inherits=
                    printf '[Icon Theme]\\nName=Test %s\\nInherits=%s\\nDirectories=48x48/apps\\n[48x48/apps]\\nSize=48\\nType=Fixed\\n' "$variant" "$inherits" > "$target/index.theme"
                done
                printf %s "$2" | base64 -d > "$1/Conflux/48x48/apps/shell-test-themed.png"
                printf %s "$2" | base64 -d > "$1/hicolor/48x48/apps/shell-test-system.png"
                for variant in hicolor Conflux; do
                    gtk-update-icon-cache -q -f -t "$1/$variant"
                done`, [root.icons, root.png], () => {
            themedIcon.source = "shell-test-themed";
            inheritedIcon.source = "shell-test-system";
            truncatedIcon.source = "shell-test-system-extra";
            check.report("the native module is loaded", IconThemes.watch !== null, "no IconThemeWatch");
            root.select("dark", () => root.select("light", () => root.select("dark", () => root.install())));
        });
    }

    function select(theme: string, then: var): void {
        Settings.setTheme(theme);
        Qt.callLater(() => selected.until(IconThemes.revisionChanged,
            () => IconThemes.themeName === "Conflux" && themedIcon.resolved !== "",
            ok => {
                check.report(theme + ": Qt selects Conflux artwork", ok);
                check.equal(theme + ": selected theme", IconThemes.themeName, "Conflux");
                check.equal(theme + ": theme artwork is drawn", themedIcon.usingFallback, false);
                check.equal(theme + ": missing artwork uses the system's icon",
                    inheritedIcon.resolved, "image://icon/shell-test-system");
                check.equal(theme + ": standard dash fallback stays available",
                    truncatedIcon.resolved, "image://icon/shell-test-system-extra");
                then();
            }));
    }

    function install(): void {
        icon.source = "shell-test-icon";
        check.equal("not installed: not found", icon.resolved, "");
        check.equal("not installed: the fallback glyph", icon.usingFallback, true);
        root.installing = true;
        timeout.start();
        sh.run(`printf %s "$2" | base64 -d > "$1/48x48/apps/shell-test-icon.png"
                gtk-update-icon-cache -q -f -t "$1"`, [root.theme, root.png], () => {});
    }

    function finish(): void {
        if (!root.installing)
            return;
        root.installing = false;
        timeout.stop();
        check.equal("installed: found", icon.resolved, "image://icon/shell-test-icon");
        check.equal("installed: drawn", icon.usingFallback, false);
        Settings.setTheme(root.originalTheme);
        check.done();
    }

    Connections {
        target: IconThemes

        function onRevisionChanged(): void {
            Qt.callLater(() => {
                if (icon.resolved !== "")
                    root.finish();
            });
        }
    }

    Connections {
        target: Settings

        function onReadyChanged(): void {
            if (Settings.ready)
                root.begin();
        }
    }

    Timer {
        id: timeout
        interval: 3000
        onTriggered: root.finish()
    }

    Component.onCompleted: {
        if (Settings.ready)
            root.begin();
    }
}
