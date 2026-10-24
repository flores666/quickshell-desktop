import QtQuick
import "root:/config"
import "root:/services"
import "root:/modules/common"

/*!
    The active window border takes the accent while it follows the wallpaper
    (docs/specs/wallpaper-accent.md, item 4), and the config's own border comes
    back when it stops. In a nested Hyprland, whose border is read back with
    hyprctl.
*/
Item {
    id: root

    Check {
        id: check
    }

    Command {
        id: sh
    }

    CompositorTheme {
        id: theme
    }

    readonly property string option: "general:col.active_border"

    /*! Hyprland's border once it is no longer `from` (or is `to`, given
        one), or as it stands after two seconds. */
    function border(from: string, then: var): void {
        sh.run(`for i in $(seq 20); do
                v=$(hyprctl getoption ${root.option} | head -n 1)
                [ "$v" != "$1" ] && break
                sleep 0.1
            done
            printf '%s' "$v"`, [from], then);
    }

    /*! How hyprctl writes a colour back: aarrggbb. */
    function written(value: color): string {
        const hex = channel => Math.round(channel * 255).toString(16).padStart(2, "0");
        return hex(value.a) + hex(value.r) + hex(value.g) + hex(value.b);
    }

    property bool started: false

    function begin(): void {
        if (root.started)
            return;
        root.started = true;
        sh.run(`hyprctl getoption ${root.option} | head -n 1`, [], configured => {
            configured = configured.trim();
            check.attempt("following", () => {
                Settings.setWallpaperAccent("#2050c0");
                Settings.setAccentFollowsWallpaper(true);
                check.equal("following: the accent is a derived option",
                    CompositorOptions.derived[root.option], theme.rgba(Appearance.c.accent));
            });
            root.border(configured, now => {
                check.report("following: Hyprland's border is the accent",
                    now.includes(root.written(Appearance.c.accent)), "got " + now);
                check.attempt("not following", () => {
                    Settings.setAccentFollowsWallpaper(false);
                    check.equal("not following: no derived border",
                        CompositorOptions.derived[root.option], undefined);
                });
                root.border(now, after => {
                    check.equal("not following: the config's border back", after, configured);
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
