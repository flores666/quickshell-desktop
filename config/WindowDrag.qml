import QtQuick

/*! One physical presentation for native moves and overview transfers. */
QtObject {
    readonly property real scale: 0.93
    readonly property real rotation: 2
    readonly property real deformation: 0.025
    readonly property real velocity: 1800
    readonly property int lift: 120
    readonly property int settle: 180
    readonly property int landing: 300
    readonly property int edgeDwell: 350
    readonly property int workspaceSlide: 350
    readonly property int edge: 24
    readonly property int indicatorWidth: 4
    readonly property int indicatorHeight: 96
    readonly property real indicatorOpacity: 0.35
    readonly property int shadowRange: 56
    readonly property int shadowDrop: 12
    readonly property real shadowOpacity: 0.22
}
