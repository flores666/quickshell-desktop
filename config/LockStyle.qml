pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

/*! The lock's static wallpaper and furniture. Blur a reduced image once;
    no live desktop texture or continuing backdrop animation is needed. */
QtObject {
    readonly property real wallpaperScale: 0.25
    readonly property real blurRadius: 64
    readonly property color shade: "#66000000"
    readonly property real clockPosition: 0.28
    readonly property real formOffset: 0.14
    readonly property int avatar: 64
    readonly property int avatarIcon: 32
    readonly property int fieldWidth: 300
    readonly property int statusWidth: 360
    readonly property int statusHeight: 36
}
