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

    What is drawn is `shown`, not `Notifs.popups` directly: a toast that drops
    out of the service's list stays drawn while it fades back out to the edge,
    then removes itself, and the ones below slide up into its place.  Leaving
    is a presentation detail, so it lives here rather than in the service.
*/
PanelWindow {
    id: root

    /*! Toasts on screen, newest last, including any still fading out. */
    property var shown: []

    function forget(n: var): void {
        root.shown = root.shown.filter(x => x && x !== n);
    }

    Connections {
        target: Notifs
        function onPopupsChanged(): void {
            const added = Notifs.popups.filter(p => p && root.shown.indexOf(p) === -1);
            if (added.length > 0)
                root.shown = root.shown.filter(x => x).concat(added);
        }
    }

    screen: Compositor.focusedScreen
    visible: root.shown.length > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // The full cap rather than the stack's height: when a toast leaves, the
    // ones below slide up from where they were, and a surface that shrank to
    // the new height at once would cut the bottom one off mid-slide.
    implicitHeight: 600
    implicitWidth: 400
    anchors { top: true; right: true }
    // Clear the bar: an "ignore exclusive zones" surface starts at the screen edge.
    margins.top: Appearance.m.barFootprint + Appearance.m.popupGap
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

        // The others close the gap instead of jumping into it.
        move: Transition {
            NumberAnimation { property: "y"; duration: Appearance.t.resize; easing.type: Appearance.t.standardEasing }
        }

        Repeater {
            // A ScriptModel rather than the bare array: reassigning an array
            // rebuilds every delegate, so each new toast would restart the
            // others' fade-in and expiry. This keeps the ones still listed.
            model: ScriptModel { values: root.shown }

            NotificationCard {
                id: toast
                required property var modelData

                width: column.width
                notification: toast.modelData
                standalone: true
                onDismissed: Notifs.dismissPopup(toast.modelData)

                readonly property int expiry: Notifs.timeoutFor(toast.modelData)
                readonly property bool leaving: Notifs.popups.indexOf(toast.modelData) === -1

                Timer {
                    running: toast.expiry > 0 && !toast.leaving
                    interval: toast.expiry
                    onTriggered: Notifs.dismissPopup(toast.modelData)
                }

                // The card slides in from the edge it appears at...
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

                // ...and back out to it. A plain animation rather than a
                // Behavior, so its end can be relied on to free the slot.
                onLeavingChanged: {
                    if (toast.leaving)
                        leave.start();
                }

                ParallelAnimation {
                    id: leave
                    NumberAnimation { target: toast; property: "x"; to: 40; duration: Appearance.t.resize; easing.type: Appearance.t.standardEasing }
                    NumberAnimation { target: toast; property: "opacity"; to: 0; duration: Appearance.t.resize }
                    onFinished: root.forget(toast.modelData)
                }
            }
        }
    }
}
