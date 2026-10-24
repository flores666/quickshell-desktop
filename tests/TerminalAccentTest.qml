import QtQuick
import Quickshell
import "root:/services"

/*!
    The terminal's accent while the accent follows the wallpaper
    (docs/specs/wallpaper-accent.md, item 6): a palette file of this machine's
    state with the wallpaper's hue at the terminal's own lightness, which
    kitty-colors.py lays over palette.conf, and kitty told to reload; gone
    again when it stops. Only under tools/test.sh, whose pkill signals
    nothing and whose gsettings is its own: anywhere else the test touches
    nothing and fails.
*/
Item {
    id: root

    Check {
        id: check
    }

    Command {
        id: sh
    }

    Oklab {
        id: ok
    }

    // Loaded only once the stand-ins are known to be the tests' own.
    Loader {
        id: theme
        active: false
        source: Quickshell.shellPath("modules/common/DesktopTheme.qml")
    }

    readonly property string stateFile: Quickshell.env("XDG_STATE_HOME") + "/quickshell-desktop/palette.conf"
    readonly property string colors: Quickshell.shellPath("terminal/kitty-colors.py")
    readonly property string signals: Quickshell.env("TEST_SIGNALS")

    /*! The state file once it is there (`present`) or gone, or as it stands
        after two seconds; then what kitty-colors.py prints, and what pkill was
        asked, after a line of '#' each. */
    function look(present: bool, then: var): void {
        sh.run(`for i in $(seq 20); do
                if [ "$2" = yes ]; then [ -e "$1" ] && break; else [ -e "$1" ] || break; fi
                sleep 0.1
            done
            sleep 0.3
            cat "$1" 2>/dev/null
            echo '#'
            python3 "$3"
            echo '#'
            cat "$4" 2>/dev/null`,
            [root.stateFile, present ? "yes" : "no", root.colors, root.signals], text => {
                const [file, kitty, signals] = text.split("#\n");
                then(root.pairs(file), root.pairs(kitty), signals.split("\n").filter(l => l !== ""));
            });
    }

    /*! "name value" lines as an object, and the names in order as `names`. */
    function pairs(text: string): var {
        const out = { names: [] };
        for (const line of text.split("\n")) {
            const words = line.trim().split(/\s+/);
            if (words.length === 2) {
                out[words[0]] = words[1];
                out.names.push(words[0]);
            }
        }
        return out;
    }

    function reloads(signals: var): int {
        return signals.filter(l => l.includes("USR1") && l.includes("kitty")).length;
    }

    property bool started: false

    function begin(): void {
        if (root.started)
            return;
        root.started = true;
        // Asked first, before anything is set.
        sh.run("command -v pkill gsettings", [], where => {
            const ours = where.trim().split("\n");
            if (ours.length !== 2 || !ours.every(p => p.startsWith(Quickshell.shellPath("tests/bin")))) {
                check.report("the tests' own pkill and gsettings", false, "got " + ours.join(", "));
                check.done();
                return;
            }
            root.run();
        });
    }

    function run(): void {
        check.attempt("before", () => {
            Settings.setAccentFollowsWallpaper(false);
            Settings.setWallpaperAccent("");
        });
        root.look(false, (_, plain, signalsBefore) => {
            theme.active = true;
            check.equal("DesktopTheme loads", theme.status, Loader.Ready);
            check.attempt("following", () => {
                Settings.setWallpaperAccent("#2050c0");
                Settings.setAccentFollowsWallpaper(true);
            });
            root.look(true, (file, kitty, signals) => {
                check.equal("following: the accent and its brighter one, only",
                    JSON.stringify(file.names), JSON.stringify(["accent", "accent_bright"]));
                check.attempt("following: the colours", () => {
                    const accent = ok.lch(file.accent);
                    check.within("following: the accent at the terminal's lightness", accent.l, ok.lch("#7d93ee").l, 0.01);
                    check.within("following: the accent in the wallpaper's hue", ok.hueApart(accent.h, ok.lch("#2050c0").h), 0, 2);
                    check.within("following: the brighter one at the terminal's lightness",
                        ok.lch(file.accent_bright).l, ok.lch("#9aaef5").l, 0.01);
                });
                check.equal("following: kitty's blue", kitty.color4, file.accent);
                check.equal("following: kitty's links", kitty.url_color, file.accent);
                check.equal("following: kitty's bright blue", kitty.color12, file.accent_bright);
                const others = plain.names.filter(n => !["color4", "color12", "url_color"].includes(n));
                check.equal("following: the rest of kitty's colours as they were",
                    JSON.stringify(others.map(n => kitty[n])), JSON.stringify(others.map(n => plain[n])));
                check.equal("following: kitty told to reload", root.reloads(signals) - root.reloads(signalsBefore), 1);

                check.attempt("not following", () => Settings.setAccentFollowsWallpaper(false));
                root.look(false, (gone, back, after) => {
                    check.equal("not following: the file gone", gone.names.length, 0);
                    check.equal("not following: kitty's own blue", back.color4, "#7d93ee");
                    check.equal("not following: kitty's own bright blue", back.color12, "#9aaef5");
                    check.equal("not following: kitty told to reload again", root.reloads(after) - root.reloads(signals), 1);
                    check.attempt("put back", () => Settings.setWallpaperAccent(""));
                    check.done();
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
