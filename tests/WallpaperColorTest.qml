import QtQuick
import Quickshell
import "root:/components"
import "root:/services"

/*!
    The wallpaper's main colour (docs/specs/wallpaper-accent.md, item 1): the
    colour covering the most of the picture among its colours, greys counting
    for nothing and a large muted area beating a small vivid one; measured,
    it is kept as Settings.wallpaperAccent while the picture is still the
    wallpaper.
*/
Item {
    id: root

    Check {
        id: check
    }

    Oklab {
        id: ok
    }

    /*! A picture of the given colours, each over its share of the pixels
        ([[colour, share], …]), as BackdropProbe hands one over: RGBA bytes,
        row by row. */
    function picture(parts: var): var {
        const width = 40, height = 25;
        const data = new Uint8Array(width * height * 4);
        let i = 0;
        for (const [hex, share] of parts) {
            const c = Qt.color(hex);
            for (let n = Math.round(share * width * height); n > 0; n--, i += 4) {
                data[i] = Math.round(c.r * 255);
                data[i + 1] = Math.round(c.g * 255);
                data[i + 2] = Math.round(c.b * 255);
                data[i + 3] = 255;
            }
        }
        return { width, height, data };
    }

    function main(parts: var): var {
        const p = root.picture(parts);
        return Backdrop.mainColor(p.data, p.width, p.height);
    }

    readonly property string current: "/nonexistent/wallpaper-accent-test.png"
    property bool started: false

    function begin(): void {
        if (root.started)
            return;
        root.started = true;
        const sky = [["#2a3f66", 0.7], ["#e8702a", 0.3]];

        check.attempt("muted blue over most, vivid orange over the rest", () =>
            check.sameColor("muted blue over most, vivid orange over the rest: the blue",
                root.main(sky), "#2a3f66", 2));
        check.attempt("grey over most, red over the rest", () =>
            check.sameColor("grey over most, red over the rest: the red",
                root.main([["#808080", 0.8], ["#c03030", 0.2]]), "#c03030", 2));
        check.attempt("all grey", () =>
            check.sameColor("all grey: its grey", root.main([["#808080", 1]]), "#808080", 2));
        check.attempt("a faint blue-grey", () => {
            const c = root.main([["#7a7f8a", 0.9], ["#808080", 0.1]]);
            check.report("a faint blue-grey: its hue",
                c !== null && ok.hueApart(ok.lch(c).h, ok.lch("#7a7f8a").h) <= 5, "got " + c);
        });
        check.attempt("no pixels", () =>
            check.equal("no pixels: nothing", Backdrop.mainColor(new Uint8Array(0), 0, 0), null));

        check.attempt("measured", () => {
            Settings.setWallpaperAccent("");
            Settings.setWallpaper(root.current);
            const screen = Quickshell.screens[0];
            Backdrop.measure(screen, root.current, Qt.size(40, 25), root.picture(sky));
            check.sameColor("the wallpaper measured: its main colour kept",
                Qt.color(Settings.wallpaperAccent), "#2a3f66", 2);
            Backdrop.measure(screen, "/nonexistent/another.png", Qt.size(40, 25),
                root.picture([["#c03030", 1]]));
            check.sameColor("another picture measured: nothing kept",
                Qt.color(Settings.wallpaperAccent), "#2a3f66", 2);
        });

        check.attempt("put back", () => {
            Settings.setWallpaper("");
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
