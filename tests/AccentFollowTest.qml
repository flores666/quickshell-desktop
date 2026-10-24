import QtQuick
import "root:/config"
import "root:/services"

/*!
    The accent follows the wallpaper (docs/specs/wallpaper-accent.md, item 2):
    while Settings.accentFollowsWallpaper is on and the wallpaper has a main
    colour, each theme's accent is that colour's chroma and hue at the theme's
    own accent's lightness, never less colourful than a picked accent may be;
    otherwise the accent is the one chosen.
*/
Item {
    id: root

    Check {
        id: check
    }

    Oklab {
        id: ok
    }

    readonly property color tunedDay: "#c15f3c"
    readonly property color tunedNight: "#d97757"

    function legible(name: string, accent: color): void {
        check.report(name, Appearance.inSeedRange(accent, Appearance.seedRange("accent")),
            "got " + accent + ", saturation " + accent.hsvSaturation + ", value " + accent.hsvValue);
    }

    /*! The accent `accent` is `wallpaper` at `tuned`'s lightness. */
    function toned(name: string, accent: color, wallpaper: color, tuned: color, hueSlack: real): void {
        const got = ok.lch(accent);
        check.within(name + ": the theme's lightness", got.l, ok.lch(tuned).l, 0.01);
        check.within(name + ": the wallpaper's hue", ok.hueApart(got.h, ok.lch(wallpaper).h), 0, hueSlack);
    }

    function follow(on: bool, wallpaper: string): void {
        Settings.setAccentFollowsWallpaper(on);
        Settings.setWallpaperAccent(wallpaper);
    }

    property bool started: false

    function begin(): void {
        if (root.started)
            return;
        root.started = true;
        const chosen = Qt.color(Settings.accentColor !== "" ? Settings.accentColor : root.tunedDay);

        check.attempt("a muted blue", () => {
            root.follow(true, "#2a3f66");
            const day = Appearance.day.accent;
            const night = Appearance.night.accent;
            root.toned("a muted blue, day", day, "#2a3f66", root.tunedDay, 2);
            check.within("a muted blue, day: the wallpaper's chroma", ok.lch(day).c, ok.lch("#2a3f66").c, 0.01);
            root.toned("a muted blue, night", night, "#2a3f66", root.tunedNight, 2);
            root.legible("a muted blue, day: legible", day);
            root.legible("a muted blue, night: legible", night);

            const ink = Appearance.contrast(Appearance.ink, day) >= Appearance.contrast("#ffffff", day)
                ? Appearance.ink : Qt.color("#ffffff");
            check.equal("a muted blue: the text on it reads best", Appearance.day.accentText.toString(), ink.toString());
            const soft = Appearance.day.accentSoft;
            check.report("a muted blue, day: the soft accent is it at 0.16",
                Qt.colorEqual(Qt.alpha(soft, 1), day) && Math.abs(soft.a - 0.16) < 0.005, "got " + soft);
            const nightSoft = Appearance.night.accentSoft;
            check.report("a muted blue, night: the soft accent is it at 0.3",
                Qt.colorEqual(Qt.alpha(nightSoft, 1), night) && Math.abs(nightSoft.a - 0.3) < 0.005, "got " + nightSoft);
        });

        check.attempt("a vivid magenta", () => {
            root.follow(true, "#ff00ff");
            root.toned("a vivid magenta, day", Appearance.day.accent, "#ff00ff", root.tunedDay, 3);
            root.legible("a vivid magenta, day: legible", Appearance.day.accent);
        });

        check.attempt("a faint blue-grey", () => {
            root.follow(true, "#7a7f8a");
            const day = Appearance.day.accent;
            check.within("a faint blue-grey: its hue", ok.hueApart(ok.lch(day).h, ok.lch("#7a7f8a").h), 0, 5);
            root.legible("a faint blue-grey: legible", day);
        });

        check.attempt("a grey", () => {
            root.follow(true, "#808080");
            const day = Appearance.day.accent;
            check.within("a grey: the theme's hue", ok.hueApart(ok.lch(day).h, ok.lch(root.tunedDay).h), 0, 2);
            root.legible("a grey: legible", day);
        });

        check.attempt("nothing measured", () => {
            root.follow(true, "");
            check.equal("nothing measured: the chosen accent", Appearance.day.accent.toString(), chosen.toString());
        });

        check.attempt("not following", () => {
            root.follow(false, "#2a3f66");
            check.equal("not following: the chosen accent", Appearance.day.accent.toString(), chosen.toString());
        });

        check.attempt("put back", () => root.follow(false, ""));
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
