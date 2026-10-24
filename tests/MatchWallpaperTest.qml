import QtQuick
import "root:/modules/settings"
import "root:/services"

/*!
    The Match wallpaper toggle (docs/specs/wallpaper-accent.md, item 3): under
    the Accent row once the wallpaper has a main colour, flipping
    Settings.accentFollowsWallpaper, and the Accent row not offered while it
    is on.
*/
Item {
    id: root

    Check {
        id: check
    }

    ColorsSection {
        id: section
        width: 480
    }

    /*! The first item under `item`, itself included, that `test` accepts. */
    function find(item: var, test: var): var {
        if (test(item))
            return item;
        for (const child of item.children) {
            const found = root.find(child, test);
            if (found)
                return found;
        }
        return null;
    }

    function named(name: string): var {
        return root.find(section, item => item.objectName === name);
    }

    function shown(item: var): bool {
        return item !== null && item.visible;
    }

    property bool started: false

    function begin(): void {
        if (root.started)
            return;
        root.started = true;
        const background = root.find(section, item => item.seed === "background");

        check.attempt("nothing measured", () => {
            Settings.setAccentFollowsWallpaper(false);
            Settings.setWallpaperAccent("");
            check.equal("nothing measured: no toggle", root.shown(root.named("matchWallpaper")), false);
        });

        check.attempt("measured", () => {
            Settings.setWallpaperAccent("#2050c0");
            const row = root.named("matchWallpaper");
            check.equal("measured: the toggle", root.shown(row), true);
            const toggle = row ? root.find(row, item => item.checked !== undefined && item !== row) : null;
            check.equal("off: the switch reads off", toggle ? toggle.checked : null, false);
            check.equal("off: the accent row", root.shown(root.named("accentPicker")), true);

            row.clicked(null);
            check.equal("clicked: following", Settings.accentFollowsWallpaper, true);
            check.equal("on: the switch reads on", toggle ? toggle.checked : null, true);
            check.equal("on: no accent row", root.shown(root.named("accentPicker")), false);
            check.equal("on: the background row", root.shown(background), true);

            row.clicked(null);
            check.equal("clicked again: not following", Settings.accentFollowsWallpaper, false);
            check.equal("off again: the accent row", root.shown(root.named("accentPicker")), true);
        });

        check.attempt("put back", () => {
            Settings.setAccentFollowsWallpaper(false);
            Settings.setWallpaperAccent("");
        });
        check.done();
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
