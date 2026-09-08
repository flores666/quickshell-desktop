pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/services"

/*!
    The single source of truth for every colour, size, duration and font in the
    shell.  Nothing else is allowed to hardcode a colour or a magic pixel value.

    The palette is warm-neutral rather than the usual blue-grey, and both
    variants are fully opaque: no blur, no glass, no translucent surfaces.  Only
    modal scrims and transient state layers use alpha, deliberately.
*/
Singleton {
    id: root

    readonly property bool dark: Settings.effectiveDark
    readonly property ColorScheme c: root.dark ? root.night : root.day

    readonly property ColorScheme day: ColorScheme {
        base: root.hasBackground ? root.background : "#faf9f5"
        surface: root.hasBackground ? root.lift(root.background, 0.029) : "#ffffff"
        raised: root.hasBackground ? root.lift(root.background, -0.037) : "#f2f0ea"
        sunken: root.hasBackground ? root.lift(root.background, -0.077) : "#eae7de"
        border: root.hasBackground ? root.lift(root.background, -0.116) : "#e2ded2"
        borderStrong: root.hasBackground ? root.lift(root.background, -0.212) : "#cdc7b6"

        accent: root.accentFor("#c15f3c")
        accentText: root.accentInkFor("#ffffff")
    }

    readonly property ColorScheme night: ColorScheme {
        base: root.hasBackground ? root.background : "#191817"
        surface: root.hasBackground ? root.lift(root.background, 0.039) : "#232221"
        raised: root.hasBackground ? root.lift(root.background, 0.077) : "#2d2c2a"
        sunken: root.hasBackground ? root.lift(root.background, -0.020) : "#141312"
        border: root.hasBackground ? root.lift(root.background, 0.122) : "#393735"
        borderStrong: root.hasBackground ? root.lift(root.background, 0.210) : "#514e4a"

        text: "#f2f0ea"
        textMuted: "#a5a199"
        textFaint: "#7c7871"
        textDisabled: "#5e5b56"

        accent: root.accentFor("#d97757")
        accentText: root.accentInkFor("#231409")

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
    // Two seeds are user-settable: the accent, and the background the neutral
    // family is built from. When a seed is unset the hand-tuned tokens are used
    // verbatim, so the default appearance is exactly what it was; when one is
    // set, the rest of the family is derived from it by the same lightness steps
    // that separate the tuned values, which keeps both themes coherent.

    readonly property string accentSeed: Settings.accentColor
    readonly property bool hasAccent: root.accentSeed !== ""
    readonly property string background: root.dark ? Settings.backgroundDark : Settings.backgroundLight
    readonly property bool hasBackground: root.background !== ""

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

    readonly property string fontFamily: "Adwaita Sans"

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
