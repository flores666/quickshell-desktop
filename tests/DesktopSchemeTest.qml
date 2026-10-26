import QtQuick
import Quickshell
import "root:/services"

/*!
    The shell's theme handed to other applications (DesktopScheme): GNOME's
    color-scheme, what the portal tells browsers, is prefer-dark under the
    dark theme and prefer-light under the light one, and follows a switch.
    Only against tools/test.sh's gsettings, which keeps its values in a file
    of the run's own: anywhere else the test touches nothing and fails.
*/
Item {
    id: root

    Check {
        id: check
    }

    Command {
        id: sh
    }

    // DesktopScheme is not touched until the gsettings is known to be the
    // tests' own: it sets the key as soon as it is up.
    property bool ours: false

    Settle {
        id: scheme
        busy: root.ours && DesktopScheme.setting
    }

    readonly property string key: "org.gnome.desktop.interface color-scheme"

    /*! GNOME's color-scheme once it is `want`, or as it stands after two
        seconds. */
    function read(want: string, then: var): void {
        scheme.until(`gsettings get ${root.key}`, [], v => v.trim() === `'${want}'`, v => then(v.trim()));
    }

    property bool started: false

    function begin(): void {
        if (root.started)
            return;
        root.started = true;
        sh.run("command -v gsettings", [], where => {
            if (!where.trim().startsWith(Quickshell.shellPath("tests/bin"))) {
                check.report("the tests' own gsettings", false, "got " + where.trim());
                check.done();
                return;
            }
            root.ours = true;
            root.run();
        });
    }

    function run(): void {
        const theme = Settings.effectiveDark ? "dark" : "light";
        check.attempt("dark", () => {
            Settings.setTheme("dark");
            check.equal("dark: the scheme", DesktopScheme.scheme, "prefer-dark");
        });
        root.read("prefer-dark", dark => {
            check.equal("dark: GNOME's color-scheme", dark, "'prefer-dark'");
            check.attempt("light", () => Settings.setTheme("light"));
            root.read("prefer-light", light => {
                check.equal("light: GNOME's color-scheme", light, "'prefer-light'");
                check.attempt("put back", () => Settings.setTheme(theme));
                check.done();
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
