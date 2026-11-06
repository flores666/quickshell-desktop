pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/modules/bar"
import "root:/services"

/*! Each bar label chooses its existing light or dark palette from its own
    wallpaper rectangle. Synthetic pixels and settings stay in the runner. */
Item {
    id: root

    property ShellScreen screen: Quickshell.screens[0] ?? null
    property string wallpaper: ""

    Check { id: check }
    Command { id: sh }
    Until { id: ready }
    ColorScheme { id: custom; text: "#123456"; textMuted: "#abcdef" }
    Label { id: ordinary; text: "Existing label"; scheme: custom; muted: true }

    Surface {
        id: panel
        screen: root.screen
        width: root.screen?.width ?? 0
        height: root.screen?.height ?? 0
        glass: 0

        Item {
            id: ancestor
            BarButton {
                id: button
                x: panel.width / 2 - button.padding - left.width - button.contentItem.spacing / 2
                y: 10
                surface: panel
                scheme: panel.schemeOver(button)

                Label { id: left; text: "Fri 6 Nov"; muted: true; surface: button.surface }
                Label { id: right; text: "10:49 AM"; surface: button.surface }
            }
        }
    }

    /*! The vertical split stays centred after Backdrop's cover mapping. */
    function measure(first: color, second: color): void {
        const width = 64, height = 64;
        const data = new Uint8Array(width * height * 4);
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                const c = x < width / 2 ? first : second;
                const i = (y * width + x) * 4;
                data[i] = Math.round(c.r * 255);
                data[i + 1] = Math.round(c.g * 255);
                data[i + 2] = Math.round(c.b * 255);
                data[i + 3] = 255;
            }
        }
        Backdrop.measure(root.screen, root.wallpaper, Qt.size(width, height), { width, height, data });
    }

    function begin(): void {
        Settings.setWallpaper(root.wallpaper);
        button.contentItem.forceLayout();

        for (const theme of ["light", "dark"]) {
            Settings.setTheme(theme);
            check.attempt(theme + " theme", () => {
                root.measure("#ffffff", "#ffffff");
                check.equal(theme + ": pale wallpaper chooses day palette", left.scheme, Appearance.day);
                root.measure("#000000", "#000000");
                check.equal(theme + ": dark wallpaper chooses night palette", left.scheme, Appearance.night);
                check.equal(theme + ": existing explicit palette preserved", ordinary.scheme, custom);
                check.equal(theme + ": existing muted ink preserved", Qt.colorEqual(ordinary.color, custom.textMuted), true);
            });
        }

        check.attempt("separate labels in one button", () => {
            root.measure("#000000", "#ffffff");
            check.equal("labels share their button's content parent", left.parent, right.parent);
            check.equal("date over dark area chooses light palette", left.scheme, Appearance.night);
            check.equal("time over light area chooses dark palette", right.scheme, Appearance.day);
            check.equal("muted ink stays the palette's muted ink", Qt.colorEqual(left.color, left.scheme.textMuted), true);
            left.faint = true;
            check.equal("faint ink stays the palette's faint ink", Qt.colorEqual(left.color, left.scheme.textFaint), true);
            left.faint = false;
            check.equal("text has no outline or other style", left.style, Text.Normal);
            check.equal("other text has no outline or other style", right.style, Text.Normal);

            ancestor.x = panel.width / 4;
            check.equal("ancestor moved onto light area: palette updates", left.scheme, Appearance.day);
            ancestor.x = 0;
            check.equal("ancestor moved back: palette updates", left.scheme, Appearance.night);

            button.x = panel.width / 2 - button.padding - 20;
            left.text = "I";
            button.contentItem.forceLayout();
            check.equal("narrow text before split chooses light ink", left.scheme, Appearance.night);
            const narrow = left.width;
            left.text = "Wide text extending across the wallpaper split";
            button.contentItem.forceLayout();
            check.report("changed text resizes its own sample", left.width > narrow, "width " + left.width);
            check.equal("resized text includes light area: palette updates", left.scheme, Appearance.day);
        });

        check.attempt("caller palette and missing background", () => {
            ordinary.surface = panel;
            check.equal("explicit caller palette wins with surface set", ordinary.scheme, custom);
            check.equal("explicit caller ink stays unchanged", Qt.colorEqual(ordinary.color, custom.textMuted), true);
            panel.screen = null;
            check.equal("missing screen uses the theme palette", left.scheme, Appearance.c);
            panel.screen = root.screen;
            Settings.setWallpaper("");
            check.equal("missing wallpaper uses the theme palette", left.scheme, Appearance.c);
            check.equal("missing wallpaper adds no style", left.style, Text.Normal);
            Settings.setWallpaper(root.wallpaper);
        });

        root.measure("#000000", "#000000");
        panel.color = Qt.rgba(1, 1, 1, 0.8);
        panel.glass = 0.5;
        ready.until(panel.glassChanged, () => panel.glass === 0.5, ok => {
            check.equal("partial glass settles", ok, true);
            check.equal("existing glass composite chooses light ink", left.scheme, Appearance.night);
            check.equal("partial glass adds no text style", left.style, Text.Normal);
            panel.glass = 1;
            ready.until(panel.glassChanged, () => panel.glass === 1, settled => {
                check.equal("full glass settles", settled, true);
                check.equal("existing glass composite now chooses dark ink", left.scheme, Appearance.day);
                check.equal("full glass adds no text style", left.style, Text.Normal);
                check.equal("explicit caller palette still unchanged", ordinary.scheme, custom);
                Settings.setWallpaper("");
                check.done();
            });
        });
    }

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "" || root.screen === null) {
            check.report("isolated fixture and screen required", false, "run tools/test.sh in nested Hyprland");
            check.done(); return;
        }
        sh.run('python3 "$1" backdrop',
            [Qt.resolvedUrl("ServiceFixtures.py").toString().replace("file://", "")], path => {
                root.wallpaper = path.trim();
                ready.until(Settings.readyChanged, () => Settings.ready, ok => {
                    if (ok) root.begin();
                    else { check.report("settings loaded", false, "timed out"); check.done(); }
                });
            });
    }
}
