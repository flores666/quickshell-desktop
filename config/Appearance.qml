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

    readonly property ColorScheme day: ColorScheme {
        base: root.lightSeed !== "" ? root.lightSeed : "#faf9f5"
        surface: root.lightSeed !== "" ? root.lift(root.lightSeed, 0.029) : "#ffffff"

        accent: root.accentFor("#c15f3c")
        accentText: root.accentInkFor("#ffffff")
        accentSoft: Qt.alpha(root.accentFor("#c15f3c"), 0.16)
    }

    readonly property ColorScheme night: ColorScheme {
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
        accentText: root.accentInkFor("#231409")
        accentSoft: Qt.alpha(root.accentFor("#d97757"), 0.3)

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
    // up — the settings panel previews both.

    readonly property string accentSeed: Settings.accentColor
    readonly property bool hasAccent: root.accentSeed !== ""
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
        return root.hasAccent ? root.accentSeed : tuned;
    }

    /*! Whichever of near-black or white reads better on the accent. */
    function accentInkFor(tuned: color): color {
        if (!root.hasAccent)
            return tuned;
        const y = root.luminance(root.accentSeed);
        const onWhite = 1.05 / (y + 0.05);
        const onInk = (y + 0.05) / (root.inkLuminance + 0.05);
        return onInk >= onWhite ? root.ink : "#ffffff";
    }

    readonly property color ink: "#1c1508"
    readonly property real inkLuminance: root.luminance(root.ink)

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

    /*! The face the whole shell is set in. Any installed family will do; the
        settings panel only ever offers ones Qt reports as present. */
    readonly property string defaultFontFamily: "Adwaita Sans"
    readonly property string fontFamily: Settings.fontFamily === ""
        ? root.defaultFontFamily : Settings.fontFamily

    readonly property Typography font: Typography {}
    readonly property Spacing s: Spacing {}
    readonly property Radii r: Radii {}
    readonly property Metrics m: Metrics {}
    readonly property Motion t: Motion {}

    /*! Elevation presets consumed by Shadow.qml: offset, blur radius, strength,
        and `pad` — the room the blurred silhouette needs around the shape. The
        silhouette is dropped by `y`, so its tail reaches `blur` past that; a
        surface that budgets only `blur` shears the bottom of its own shadow. */
    function shadowFor(level: int): var {
        let spec;
        switch (level) {
        case 1: spec = { y: 1, blur: 8, alpha: 0.7 }; break;
        case 2: spec = { y: 2, blur: 14, alpha: 0.85 }; break;
        case 3: spec = { y: 3, blur: 22, alpha: 1.0 }; break;
        default: spec = { y: 0, blur: 0, alpha: 0 }; break;
        }
        spec.pad = spec.blur + spec.y;
        return spec;
    }
}
