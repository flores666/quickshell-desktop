pragma ComponentBehavior: Bound

import QtQuick

/*! Animation durations and curves. Short and subtle, by design. */
QtObject {
    readonly property int instant: 45
    readonly property int fast: 70
    readonly property int base: 100
    /*! A whole popup changing size — a bigger move than any control makes. */
    readonly property int resize: 150

    readonly property int standardEasing: Easing.OutCubic
    readonly property int emphasizedEasing: Easing.OutQuint
    /*! For a container changing size: even at both ends, so the edge does not
        appear to leap and then crawl the way an out-curve makes it. */
    readonly property int resizeEasing: Easing.InOutCubic
}
