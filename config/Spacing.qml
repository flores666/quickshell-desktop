pragma ComponentBehavior: Bound

import QtQuick

/*! The spacing scale. Every gap and inset in the shell is one of these. */
QtObject {
    readonly property int xxs: 2
    readonly property int xs: 4
    readonly property int sm: 6
    readonly property int md: 8
    readonly property int lg: 12
    readonly property int xl: 16
    readonly property int xxl: 24
    readonly property int huge: 32
}
