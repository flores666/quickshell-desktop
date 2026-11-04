pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! The same slide and fade out for a toast and a notification-centre row. */
SequentialAnimation {
    id: root

    required property Item card
    required property Translate slide
    property int delay: 0

    PauseAnimation { duration: root.delay }
    ParallelAnimation {
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
}
