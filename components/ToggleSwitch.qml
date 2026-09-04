pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*! A pill switch. Reports intent via toggled(); the owner decides the new state. */
Clickable {
    id: root

    property bool checked: false

    signal toggled(bool value)

    implicitWidth: 44
    implicitHeight: 26
    radius: Appearance.r.full
    showStateLayer: false

    onClicked: root.toggled(!root.checked)

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Appearance.c.accent : Appearance.c.sunken
        border.width: root.checked ? 0 : 1
        border.color: Appearance.c.borderStrong

        Behavior on color {
            ColorAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.down ? Appearance.c.pressLayer
                : root.hovered ? Appearance.c.hoverLayer : "transparent"

            Behavior on color {
                ColorAnimation { duration: Appearance.t.instant }
            }
        }

        Rectangle {
            id: knob
            y: 3
            x: root.checked ? track.width - width - 3 : 3
            width: 20
            height: 20
            radius: height / 2
            color: root.checked ? Appearance.c.accentText : Appearance.c.surface

            Behavior on x {
                NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.emphasizedEasing }
            }
            Behavior on color {
                ColorAnimation { duration: Appearance.t.fast }
            }

            Shadow {
                anchors.fill: parent
                radius: parent.radius
                level: 1
            }
        }
    }
}
