pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Notification toasts, stacked under the top bar of the focused monitor.

    Each toast owns its own expiry timer; critical notifications have none and
    stay until they are acted on.  Input is masked to the cards themselves, so
    the rest of the strip stays click-through.
*/
PanelWindow {
    id: root

    readonly property bool active: Notifs.popups.length > 0

    screen: Compositor.focusedScreen
    visible: root.active
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitHeight: Math.max(1, Math.min(600, column.implicitHeight + Appearance.s.lg * 2))
    implicitWidth: 400
    anchors { top: true; right: true }
    // Clear the bar: an "ignore exclusive zones" surface starts at the screen edge.
    margins.top: Appearance.m.barHeight + Appearance.s.md
    margins.right: Appearance.s.lg

    WlrLayershell.namespace: "shell-toasts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: column }

    Column {
        id: column

        anchors.top: parent.top
        anchors.right: parent.right
        width: 372
        spacing: Appearance.s.md

        Repeater {
            model: Notifs.popups

            NotificationCard {
                id: toast
                required property var modelData

                width: column.width
                notification: toast.modelData
                standalone: true
                onDismissed: Notifs.dismissPopup(toast.modelData)

                readonly property int expiry: Notifs.timeoutFor(toast.modelData)

                Timer {
                    running: toast.expiry > 0
                    interval: toast.expiry
                    onTriggered: Notifs.dismissPopup(toast.modelData)
                }

                // The card slides in from the edge it appears at.
                NumberAnimation on x {
                    from: 40
                    to: 0
                    duration: Appearance.t.base
                    easing.type: Appearance.t.emphasizedEasing
                }
                NumberAnimation on opacity {
                    from: 0
                    to: 1
                    duration: Appearance.t.base
                }
            }
        }
    }
}
