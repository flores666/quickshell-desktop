pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! The active keyboard layout, shown only when more than one is configured. */
BarButton {
    id: root

    visible: Keyboard.available
    padding: Appearance.m.barLayoutPadding

    onClicked: Keyboard.cycle()

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: Keyboard.code
        role: Label.Role.Small
        font.weight: Font.DemiBold
        surface: root.surface
    }
}
