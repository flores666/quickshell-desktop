pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! The same slide and fade out for a toast and a notification-centre row. */
ParallelAnimation {
    id: root

    required property Item card
    required property Translate slide

    NumberAnimation {
        target: root.slide
        property: "x"
        to: Appearance.m.notificationSlide
        duration: Appearance.t.resize
        easing.type: Appearance.t.standardEasing
    }
    NumberAnimation {
        target: root.card
        property: "opacity"
        to: 0
        duration: Appearance.t.resize
        easing.type: Appearance.t.standardEasing
    }
}
