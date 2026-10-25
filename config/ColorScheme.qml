pragma ComponentBehavior: Bound

import QtQuick

/*!
    The complete set of colour tokens.

    Declaring them once, here, is what guarantees the light and dark variants
    stay in step: a token added for one is a token the other must also answer
    for. Defaults are the light values.
*/
QtObject {
    id: scheme

    /*! Backdrop behind floating chrome; also the lock screen and overview canvas. */
    property color base: "#faf9f5"
    /*! Bars, docks, popovers, dialogs — opaque here; they are drawn as `chrome`. */
    property color surface: "#ffffff"
    /*!
        How much of `surface` a floating panel lays over what is behind it; the
        compositor blurs the rest (see the layer rule in hyprland.conf). High
        enough that text stays legible with blur switched off.
    */
    property real glass: 0.9
    /*! What floating chrome is drawn in: the surface, at glass opacity. */
    readonly property color chrome: Qt.alpha(scheme.surface, scheme.glass)

    /*!
        The four tokens below are translucent washes rather than colours, so
        they take on whatever they rest on: the glass, the background seed and
        the wallpaper behind it alike. That is what lets one set of them serve
        every palette the seeds can make.
    */
    /*! Cards and tiles resting on a surface. */
    property color raised: "#0d000000"
    /*! Wells: slider troughs, search fields, inset lists. */
    property color sunken: "#14000000"
    /*! Hairlines, and the edge of every surface. */
    property color border: "#1a000000"
    property color borderStrong: "#33000000"

    property color text: "#1c1b18"
    property color textMuted: "#6d6a60"
    property color textFaint: "#9b978b"
    property color textDisabled: "#b8b4a8"

    /*! The thumb of a slider or switch: near-white in either theme, as a
        physical knob would be, so it reads against the track and the fill. */
    property color knob: "#ffffff"

    property color accent: "#c15f3c"
    property color accentText: "#ffffff"
    /*! The accent as a tint: the chosen segment, a swatch's halo. Text on it
        is the ordinary text colour, not `accentText`. */
    property color accentSoft: "#2ec15f3c"

    property color success: "#3f7d51"
    property color warning: "#9a6b12"
    property color danger: "#b3392b"

    /*! Transient interaction layers, composited over whatever is beneath. */
    property color hoverLayer: "#0f000000"
    property color pressLayer: "#1f000000"
    property color selectLayer: "#14000000"
    property color scrim: "#59000000"
    property color shadow: "#000000"
    property real shadowStrength: 0.13
}
