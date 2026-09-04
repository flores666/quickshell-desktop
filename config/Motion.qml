pragma ComponentBehavior: Bound

import QtQuick

/*! Animation durations and curves. Short and subtle, by design. */
QtObject {
    readonly property int instant: 90
    readonly property int fast: 140
    readonly property int base: 200

    readonly property int standardEasing: Easing.OutCubic
    readonly property int emphasizedEasing: Easing.OutQuint
}
