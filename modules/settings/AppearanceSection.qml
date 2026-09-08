pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! Theme and the two colour seeds the rest of the palette is derived from. */
Column {
    id: root

    spacing: Appearance.s.lg

    MenuRow {
        width: root.width
        title: qsTr("Dark style")
        subtitle: qsTr("Both themes are hand-tuned; the seeds below apply to each separately")
        icon: "night-light"
        onClicked: Settings.toggleTheme()

        ToggleSwitch {
            anchors.verticalCenter: parent.verticalCenter
            checked: Appearance.dark
            onToggled: value => Settings.setTheme(value ? "dark" : "light")
        }
    }

    Divider { width: root.width }

    ColorsSection { width: root.width }
}
