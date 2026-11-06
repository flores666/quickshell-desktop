pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import "root:/config"
import "root:/components"
import "root:/services"

/*! Live profile choices, using the same detail-page navigation as power actions. */
Column {
    id: root
    property string owner: ""
    enabled: Power.hasProfiles && Power.profileOwner === root.owner
    spacing: Appearance.m.rowGap
    signal backRequested
    Component.onCompleted: root.owner = Power.profileOwner

    // A backend replacement must release choices shown for the previous owner.
    Connections {
        target: Power
        function onProfileOwnerChanged(): void { root.backRequested(); }
    }

    Repeater {
        model: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        MenuRow {
            id: choice
            required property int modelData
            objectName: "profile:" + choice.modelData
            width: root.width
            visible: choice.modelData !== PowerProfile.Performance || Power.hasPerformance
            selected: choice.modelData === Power.profile
            icon: Power.profileIcon(choice.modelData)
            title: Power.profileLabel(choice.modelData)
            Accessible.role: Accessible.RadioButton
            Accessible.name: choice.title
            Accessible.checkable: true
            Accessible.checked: choice.selected
            // The old page remains drawn through the navigation fade.
            onClicked: if (Power.profileOwner === root.owner) Power.setProfile(choice.modelData)

            Icon {
                visible: choice.selected
                name: "check"
                size: Appearance.m.icon
            }
        }
    }
}
