pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"

/*!
    The settings surface: everything about the shell a user is allowed to change.

    Sections down the left, one of them on the right.  A list rather than the
    sub-page slide quick settings uses — quick settings is a popover you dip
    into and dismiss, where a page at a time is the point; this is somewhere you
    stay while you try values, and losing your place on every move would make
    comparing two of them tedious.

    Every control writes straight through to Settings and the shell redraws as
    you drag.  Bar height and the gaps around it change what the bar reserves,
    so the compositor relays out the windows underneath while you move them —
    that is the honest cost of seeing the change rather than a preview of it.
    Nothing here previews; there is no apply button and nothing to cancel.
*/
ShellOverlay {
    id: root

    overlayId: Overlay.settings
    placement: ShellOverlay.Placement.Centre
    cardRadius: Appearance.r.xl
    cardWidth: Math.min(660, (root.screen ? root.screen.width : 1920) - Appearance.s.huge * 2)
    cardHeight: Math.min(520, (root.screen ? root.screen.height : 1080) - Appearance.s.huge * 3)

    readonly property var sections: [
        { key: "appearance", title: qsTr("Appearance"), icon: "night-light" },
        { key: "panel", title: qsTr("Top panel"), icon: "display" },
        { key: "dock", title: qsTr("Dock"), icon: "apps" },
        { key: "behaviour", title: qsTr("Behaviour"), icon: "bell" }
    ]

    property string section: "appearance"

    onShownChanged: if (root.shown) root.section = "appearance"

    readonly property int navWidth: 168

    Item {
        anchors.fill: parent

        Label {
            id: heading
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Appearance.s.xl
            anchors.topMargin: Appearance.s.lg
            text: qsTr("Settings")
            role: Label.Role.Subtitle
        }

        TextButton {
            id: resetAll
            anchors.right: parent.right
            anchors.verticalCenter: heading.verticalCenter
            anchors.rightMargin: Appearance.s.lg
            text: qsTr("Reset all")
            icon: "refresh"
            // Colours are seeds rather than sizes and are reset by their own
            // default swatch, so this is only ever about the numbers.
            enabled: Settings.overrideKeys.some(k => Settings.isOverridden(k))
            onClicked: Settings.resetOverrides()
        }

        Divider {
            id: rule
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: heading.bottom
            anchors.topMargin: Appearance.s.lg
        }

        Column {
            id: nav

            anchors.left: parent.left
            anchors.top: rule.bottom
            anchors.leftMargin: Appearance.s.md
            anchors.topMargin: Appearance.s.md
            width: root.navWidth - Appearance.s.md
            spacing: Appearance.s.xxs

            Repeater {
                model: root.sections

                MenuRow {
                    required property var modelData

                    width: nav.width
                    implicitWidth: nav.width
                    title: this.modelData.title
                    icon: this.modelData.icon
                    selected: root.section === this.modelData.key
                    onClicked: root.section = this.modelData.key
                }
            }
        }

        Divider {
            id: spine
            anchors.left: parent.left
            anchors.leftMargin: root.navWidth
            anchors.top: rule.bottom
            anchors.bottom: parent.bottom
            vertical: true
        }

        Flickable {
            id: scroller

            anchors.left: spine.right
            anchors.right: parent.right
            anchors.top: rule.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.s.xl
            clip: true
            contentHeight: pane.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: pane

                width: scroller.width - Appearance.s.md
                sourceComponent: switch (root.section) {
                    case "panel": return panelSection;
                    case "dock": return dockSection;
                    case "behaviour": return behaviourSection;
                    default: return appearanceSection;
                }
            }
        }

        ThinScrollBar { flickable: scroller }
    }

    Component { id: appearanceSection; AppearanceSection { width: pane.width } }
    Component { id: panelSection; PanelSection { width: pane.width } }
    Component { id: dockSection; DockSection { width: pane.width } }
    Component { id: behaviourSection; BehaviourSection { width: pane.width } }
}
