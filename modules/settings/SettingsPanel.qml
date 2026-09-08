pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"

/*!
    The settings surface: everything about the shell a user is allowed to change.

    One tab per thing that can be configured, and each thing in exactly one tab:
    the dock's hide delay is under Dock rather than filed with the other
    timings, and the border and corner radius every surface is drawn with are
    under Appearance rather than under the panel that happened to need them
    first.  Somewhere to look is worth more than a tidy grouping of like
    controls.

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
        { key: "wallpaper", title: qsTr("Wallpaper"), icon: "wallpaper" },
        { key: "panel", title: qsTr("Top panel"), icon: "display" },
        { key: "dock", title: qsTr("Dock"), icon: "apps" },
        { key: "notifications", title: qsTr("Notifications"), icon: "bell" }
    ]

    property string section: "appearance"

    onShownChanged: {
        if (!root.shown)
            return;
        root.section = "appearance";
        // The pane outlives being closed, so without this it reopens wherever
        // it was left — which since Appearance grew a type section is halfway
        // down a list the user came back to the top of.
        scroller.contentY = 0;
    }

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
            // The colour, font and wallpaper choices are picked from a list
            // rather than measured, and each list carries its own way back, so
            // this is only ever about the numbers.
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
                    case "wallpaper": return wallpaperSection;
                    case "panel": return panelSection;
                    case "dock": return dockSection;
                    case "notifications": return notificationsSection;
                    default: return appearanceSection;
                }
            }
        }

        ThinScrollBar { flickable: scroller }
    }

    Component { id: appearanceSection; AppearanceSection { width: pane.width } }
    Component { id: wallpaperSection; WallpaperSection { width: pane.width } }
    Component { id: panelSection; PanelSection { width: pane.width } }
    Component { id: dockSection; DockSection { width: pane.width } }
    Component { id: notificationsSection; NotificationsSection { width: pane.width } }
}
