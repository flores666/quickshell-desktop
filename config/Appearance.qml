pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/services"

/*!
    The single source of truth for every colour, size, duration and font in the
    shell.  Nothing else is allowed to hardcode a colour or a magic pixel value.

    The palette is warm-neutral rather than the usual blue-grey.  Floating
    chrome is glass: the surface colour at `c.glass` opacity over a blur the
    compositor draws, with fills and hairlines as translucent washes on top, so
    every token reads the same over whatever the seeds and the wallpaper make.
    Only the lock screen, which nothing shows through, is opaque.
*/
Singleton {
    id: root

    readonly property bool dark: Settings.effectiveDark
    readonly property ColorScheme c: root.dark ? root.night : root.day

    /*!
        How much of its glass the top panel lays down, and the dock (Surface's
        `glass`): 1 is the theme's own, as tuned, and 0 none, the hairline and
        shadow going with it. Never more than the theme's: the lock screen is
        the one opaque surface. Below about 57% the panel is no longer over
        half opaque, and the compositor stops blurring what is behind it (the
        shell-glass layer rule).
    */
    readonly property real barOpacity: Tuning.pick("barOpacity") / 100
    readonly property real dockOpacity: Settings.dockOpacityFollowsBar
        ? root.barOpacity : Tuning.pick("dockOpacity") / 100

    readonly property ColorScheme day: ColorScheme {
        id: dayScheme

        base: root.lightSeed !== "" ? root.lightSeed : "#faf9f5"
        surface: root.lightSeed !== "" ? root.lift(root.lightSeed, 0.029) : "#ffffff"

        accent: root.accentFor("#c15f3c")
        accentText: root.accentInkFor("#ffffff", dayScheme.accent)
        accentSoft: Qt.alpha(dayScheme.accent, 0.16)
    }

    readonly property ColorScheme night: ColorScheme {
        id: nightScheme

        base: root.darkSeed !== "" ? root.darkSeed : "#191817"
        surface: root.darkSeed !== "" ? root.lift(root.darkSeed, 0.039) : "#232221"
        glass: 0.88

        raised: "#17ffffff"
        sunken: "#38000000"
        border: "#1fffffff"
        borderStrong: "#3dffffff"

        text: "#f2f0ea"
        textMuted: "#a5a199"
        textFaint: "#7c7871"
        textDisabled: "#5e5b56"
        knob: "#f2f0ea"

        accent: root.accentFor("#d97757")
        accentText: root.accentInkFor("#231409", nightScheme.accent)
        accentSoft: Qt.alpha(nightScheme.accent, 0.3)

        success: "#6bbf83"
        warning: "#d7a13f"
        danger: "#e0705f"

        hoverLayer: "#14ffffff"
        pressLayer: "#26ffffff"
        selectLayer: "#1affffff"
        scrim: "#8c000000"
        shadowStrength: 0.30
    }

    // ---------------------------------------------------------- user colours
    //
    // Two seeds are user-settable: the accent, and the background each theme's
    // neutral family is built from. When a seed is unset the hand-tuned tokens
    // are used verbatim, so an untouched shell renders exactly what was tuned;
    // when one is set, the surface is derived from it by the same lightness step
    // that separates the tuned values, and the washes take on the rest.
    // Each theme reads its own seed, so either can be drawn while the other is
    // up — the settings panel previews both. The accent may instead follow the
    // wallpaper's main colour (Settings.accentFollowsWallpaper), each theme
    // taking it at its own accent's lightness.

    readonly property string accentSeed: Settings.accentColor
    /*! The wallpaper's main colour while the accent follows it and it has
        been measured; empty otherwise, and the accent is the one chosen. */
    readonly property string wallpaperSeed: Settings.accentFollowsWallpaper ? Settings.wallpaperAccent : ""
    readonly property bool followsWallpaper: root.wallpaperSeed !== ""
    readonly property bool hasAccent: root.followsWallpaper || root.accentSeed !== ""
    readonly property string lightSeed: Settings.backgroundLight
    readonly property string darkSeed: Settings.backgroundDark

    /*!
        How far a picked seed may go, in HSV saturation and value. The derived
        family and the hand-tuned text colours only stay legible over a
        background near the theme's own, so a background is held to a narrow
        band; an accent only has to stay a colour, neither grey nor black.
    */
    function seedRange(seed: string): var {
        if (seed === "accent")
            return { saturation: [0.2, 1], value: [0.35, 1] };
        return root.dark
            ? { saturation: [0, 0.4], value: [0.04, 0.2] }
            : { saturation: [0, 0.15], value: [0.9, 1] };
    }

    /*! The curated choices a seed's row offers ahead of the picker, the
        theme's own colour ("") first; a background's are the current theme's. */
    function seedChoices(seed: string): var {
        if (seed === "accent")
            return ["", "#c15f3c", "#b5453f", "#a8632a", "#6f7f45", "#3f7d6d", "#4a6f9c", "#7a5a9b", "#5c6470"];
        return root.dark
            ? ["", "#191817", "#141414", "#17181c", "#151a19", "#1b1720", "#1a1a1a"]
            : ["", "#faf9f5", "#ffffff", "#f6f5f2", "#f7f6f9", "#f4f7f6", "#f8f5f1"];
    }

    function inSeedRange(c: color, range: var): bool {
        const within = (x, span) => x >= span[0] - 0.005 && x <= span[1] + 0.005;
        return within(c.hsvSaturation, range.saturation) && within(c.hsvValue, range.value);
    }

    function accentFor(tuned: color): color {
        if (root.followsWallpaper)
            return root.fromWallpaper(tuned);
        return root.accentSeed !== "" ? root.accentSeed : tuned;
    }

    /*!
        The wallpaper's main colour at `tuned`'s lightness (ColorMath.tone):
        its hue and saturation, so it matches the picture, at the lightness an
        accent was tuned to read at, and never less colourful than a picked
        accent may be. A wallpaper with hardly any colour gives the nearest
        that is; one with none, the tuned colour's hue.
    */
    function fromWallpaper(tuned: color): color {
        return ColorMath.tone(root.wallpaperSeed, tuned,
            c => root.inSeedRange(c, root.seedRange("accent")));
    }

    /*! Whichever of near-black or white reads better on the accent. */
    function accentInkFor(tuned: color, accent: color): color {
        if (!root.hasAccent)
            return tuned;
        return root.contrast(accent, root.ink) >= root.contrast(accent, "#ffffff")
            ? root.ink : "#ffffff";
    }

    /*! libadwaita's accent colours, by the names GTK's `accent-color` takes:
        the one nearest the accent is GTK's while it follows the wallpaper
        (modules/common/DesktopTheme). */
    readonly property var gtkAccents: ({
        blue: "#3584e4", teal: "#2190a4", green: "#3a944a", yellow: "#c88800", orange: "#ed5b00",
        red: "#e62d42", pink: "#d56199", purple: "#9141ac", slate: "#6f8396"
    })

    readonly property color ink: "#1c1508"

    /*!
        The scheme a panel's glass is tinted with, laying `share` of it over
        `behind` (Surface.glass): the theme's while its text still reads on
        the mix at WCAG's 4.5:1 — which at the theme's own glass it does over
        any wallpaper, black or white — and past that the other theme's, if
        its text reads better on its own glass. The night theme's bar thinned
        over a pale sky frosts light, rather than turning a grey on which only
        the darkest text would read and the muted text none.
    */
    function glassOver(behind: color, share: real): ColorScheme {
        const other = root.dark ? root.day : root.night;
        const own = root.contrast(root.c.text, root.laid(root.c.chrome, behind, share));
        if (own >= 4.5)
            return root.c;
        return root.contrast(other.text, root.laid(other.chrome, behind, share)) > own ? other : root.c;
    }

    /*!
        The colours that read on what lies under them: the theme's own, or
        the other theme's where its text stands out more — what is laid on a
        panel's glass, each part over the wallpaper behind it alone
        (Surface.schemeOver).
    */
    function schemeOn(under: color): ColorScheme {
        const other = root.dark ? root.day : root.night;
        return root.contrast(other.text, under) > root.contrast(root.c.text, under) ? other : root.c;
    }

    /*! What shows where `share` of a fill lies over a colour. */
    function laid(fill: color, behind: color, share: real): color {
        const a = fill.a * share;
        return Qt.rgba(fill.r * a + behind.r * (1 - a), fill.g * a + behind.g * (1 - a),
            fill.b * a + behind.b * (1 - a), 1);
    }

    /*! Shift a colour's HSL lightness, keeping its hue and saturation. */
    function lift(seed: color, delta: real): color {
        return Qt.hsla(seed.hslHue, seed.hslSaturation,
            Math.max(0, Math.min(1, seed.hslLightness + delta)), 1);
    }

    /*! WCAG relative luminance. */
    function luminance(c: color): real {
        const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    /*! Black or white, whichever stands further from a colour, as contrast
        goes. */
    function farthest(c: color): color {
        return root.contrast(c, "#000000") > root.contrast(c, "#ffffff") ? "#000000" : "#ffffff";
    }

    /*! WCAG contrast ratio, 1 to 21. */
    function contrast(a: color, b: color): real {
        const la = root.luminance(a);
        const lb = root.luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    /*! The face the whole shell is set in. Any installed family will do; the
        settings panel only ever offers ones Qt reports as present. */
    readonly property string defaultFontFamily: "Adwaita Sans"
    readonly property string fontFamily: Settings.fontFamily === ""
        ? root.defaultFontFamily : Settings.fontFamily

    readonly property Typography font: Typography {}
    readonly property Spacing s: Spacing {}
    readonly property Radii r: Radii {}
    readonly property Metrics m: Metrics { dockBackground: root.dockOpacity > 0 }
    readonly property Motion t: Motion {}

    /*!
        The shadow of everything that floats: every application window, which
        Hyprland draws (modules/common/CompositorTheme pushes it), and the
        shell's own floating surfaces — popups, toasts, the OSD, the dock —
        which are Shadow level 3. macOS's, in CSS drop-shadow terms: a long
        soft shadow dropped below, and a tight dark edge all round. The same in
        both themes, as macOS's is. Hyprland draws one shadow per window and
        cannot drop it far without a hard edge, so a window's is the nearest
        soft one it draws: dropped a few pixels, shorter below, a little above.
    */
    readonly property var windowShadow: [
        { y: 25, blur: 45, alpha: 0.40 },
        { y: 0, blur: 2, alpha: 0.50 }
    ]

    /*! Elevation presets consumed by Shadow.qml, as layers in CSS drop-shadow
        terms — offset `y`, `blur` (twice the gaussian's σ) and `alpha` — and
        `pad`, the room the deepest layer needs around the shape: dropped by `y`,
        its tail reaches 3σ past that, and a surface that budgets less shears
        the bottom of its own shadow. Resting chrome and raised cards are tuned
        to each theme's shadowStrength; level 3 is windowShadow as it stands. */
    function shadowFor(level: int): var {
        const k = root.c.shadowStrength;
        let layers;
        switch (level) {
        case 1: layers = [{ y: 1, blur: 4, alpha: 0.7 * k }]; break;
        case 2: layers = [{ y: 2, blur: 6, alpha: 0.85 * k }]; break;
        case 3: layers = root.windowShadow; break;
        default: layers = []; break;
        }
        const pad = Math.max(0, ...layers.map(l => Math.ceil(l.y + l.blur * 1.5)));
        return { layers, pad };
    }
}
