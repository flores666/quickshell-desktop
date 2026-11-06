pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*! Popup-only material and readable ink; no wallpaper sampling or preferences.
    The darker night tint preserves transmission while keeping the 70% endpoint
    readable over white. The theme's base glass and other surfaces stay intact. */
Singleton {
    id: root
    readonly property color tint: Appearance.dark
        ? Qt.hsla(Appearance.c.surface.hslHue, Appearance.c.surface.hslSaturation,
            Appearance.c.surface.hslLightness * 0.2, 1) : Appearance.c.surface
    readonly property color reflection: Qt.alpha(Appearance.white, Appearance.dark ? 0.012 : 0.12)
    readonly property color reflectionEnd: Qt.alpha(Appearance.white, 0)
    readonly property real reflectionKnee: 0.65
    readonly property color rimTop: Qt.alpha(Appearance.white, Appearance.dark ? 0.32 : 0.8)
    readonly property color rimBottom: Appearance.c.border
    // Small text cannot use the ordinary subdued ink on transmitting glass.
    readonly property color muted: Appearance.c.text
    readonly property color wash: Appearance.dark ? "#24000000" : "#24ffffff"
    readonly property color accent: Appearance.c.accent
    readonly property color accentInk: Appearance.farthest(Appearance.c.accent)
    // Tiles transmit the panel beneath them. Keep the fill and its ink as one
    // decision, increasing coverage only when the backdrop would spoil contrast.
    readonly property real tileAccentCoverage: 0.8
    readonly property var tileAccent: root.accentGlass()
    // Check both extrema: a light accent can read on the darker mix and still
    // disappear over white. The reflection's full strength is a safe upper bound.
    readonly property real minimumGlass: Tuning.spec.popupOpacity.min / 100
    readonly property color darkestCard: Appearance.laid(Qt.alpha(tint, Appearance.c.glass), "#000000", minimumGlass)
    readonly property color lightestCard: Appearance.laid(reflection,
        Appearance.laid(Qt.alpha(tint, Appearance.c.glass), Appearance.white, minimumGlass), 1)
    readonly property color darkest: Appearance.laid(wash,
        darkestCard, 1)
    readonly property color lightest: Appearance.laid(wash, lightestCard, 1)
    readonly property color indicator: Appearance.contrast(Appearance.c.accent, darkest) >= 3
        && Appearance.contrast(Appearance.c.accent, lightest) >= 3
        ? Appearance.c.accent : Appearance.c.text

    // Status ink keeps its hue; ordinary theme colors can disappear on the
    // lighter night mix or darker day mix at the opacity floor.
    readonly property color danger: root.readable(Appearance.c.danger)
    readonly property color warning: root.readable(Appearance.c.warning)
    readonly property color success: root.readable(Appearance.c.success)
    readonly property color accentIndicator: root.readable(Appearance.c.accent)

    function accentGlass(): var {
        let alpha = Appearance.c.glass * Appearance.popupOpacity * root.tileAccentCoverage;
        for (let step = 0; step < 8; step++) {
            const fill = Qt.alpha(root.accent, alpha);
            const dark = Appearance.laid(fill, root.darkestCard, 1);
            const light = Appearance.laid(root.reflection, Appearance.laid(fill, root.lightestCard, 1), 1);
            const white = Math.min(Appearance.contrast(Appearance.white, dark), Appearance.contrast(Appearance.white, light));
            const black = Math.min(Appearance.contrast("#000000", dark), Appearance.contrast("#000000", light));
            if (Math.max(white, black) >= 4.5)
                return { fill, ink: white > black ? Appearance.white : "#000000" };
            alpha = (alpha + 1) / 2;
        }
        return { fill: root.accent, ink: root.accentInk };
    }

    function contrastOnCard(ink: color): real {
        return Math.min(Appearance.contrast(ink, root.darkestCard), Appearance.contrast(ink, root.lightestCard));
    }
    function readable(ink: color): color {
        if (root.contrastOnCard(ink) >= 4.5) return ink;
        const toned = ColorMath.tone(ink, Appearance.c.text, () => true);
        return root.contrastOnCard(toned) >= 4.5 ? toned : Appearance.c.text;
    }
}
