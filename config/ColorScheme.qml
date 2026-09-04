pragma ComponentBehavior: Bound

import QtQuick

/*!
    The complete set of colour tokens.

    Declaring them once, here, is what guarantees the light and dark variants
    stay in step: a token added for one is a token the other must also answer
    for. Defaults are the light values.
*/
QtObject {
    /*! Backdrop behind floating chrome; also the launcher and overview canvas. */
    property color base: "#faf9f5"
    /*! Bars, docks, popovers, dialogs. */
    property color surface: "#ffffff"
    /*! Cards and tiles resting on a surface. */
    property color raised: "#f2f0ea"
    /*! Wells: slider troughs, search fields, inset lists. */
    property color sunken: "#eae7de"
    property color border: "#e2ded2"
    property color borderStrong: "#cdc7b6"

    property color text: "#1c1b18"
    property color textMuted: "#6d6a60"
    property color textFaint: "#9b978b"
    property color textDisabled: "#b8b4a8"

    property color accent: "#c15f3c"
    property color accentText: "#ffffff"

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
