import QtQuick
import Quickshell
import "root:/services"

/*!
    The shell's theme handed to other applications (DesktopScheme): GNOME's
    color-scheme, what the portal tells browsers, is prefer-dark under the
    dark theme and prefer-light under the light one. Conflux stays selected
    across that switch, including a new request while the setter is busy.
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

    /*! Both GTK keys once the requested pair has landed. */
    function read(want: string, icons: string, then: var): void {
        scheme.until(`gsettings get ${root.key}; gsettings get org.gnome.desktop.interface icon-theme`, [],
            v => v.trim() === `'${want}'\n'${icons}'`, v => then(v.trim().split("\n")));
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
        root.read("prefer-dark", "Conflux", dark => {
            check.equal("dark: GNOME's color-scheme", dark[0], "'prefer-dark'");
            check.equal("dark: Conflux artwork", dark[1], "'Conflux'");
            check.equal("dark: Qt and GTK share a theme", DesktopScheme.iconTheme, IconThemes.themeName);
            check.attempt("light", () => Settings.setTheme("light"));
            root.read("prefer-light", "Conflux", light => {
                check.equal("light: GNOME's color-scheme", light[0], "'prefer-light'");
                check.equal("light: Conflux artwork", light[1], "'Conflux'");
                // These arrive before the first external setter can finish.
                Settings.setTheme("dark");
                Settings.setTheme("light");
                Settings.setTheme("dark");
                root.read("prefer-dark", "Conflux", latest => {
                    check.equal("rapid changes keep the final scheme", latest[0], "'prefer-dark'");
                    check.equal("rapid changes keep Conflux", latest[1], "'Conflux'");
                    Settings.setTheme(theme);
                    root.read(theme === "dark" ? "prefer-dark" : "prefer-light",
                        "Conflux", () => check.done());
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
