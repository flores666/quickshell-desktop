pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
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
    /*! Where the stack starts: clear of the bar, since an "ignore exclusive
        zones" surface starts at the screen edge. */
    readonly property int stackTop: Appearance.m.barFootprint + Appearance.m.popupGap
    /*! Room around the stack for the toasts' shadow, as much as the screen
        leaves, as in ShellOverlay: the surface reaches up over the bar and out
        to the screen's edge, and the stack sits where it belongs inside it. */
    readonly property int pad: Appearance.shadowFor(3).pad
    readonly property int padTop: Math.min(root.pad, root.stackTop)

    // The full cap rather than the stack's height: when a toast leaves, the
    // ones below slide up from where they were, and a surface that shrank to
    // the new height at once would cut the bottom one off mid-slide.
    implicitHeight: root.padTop + 600 + root.pad
    implicitWidth: root.pad + column.width + Appearance.s.lg
    anchors { top: true; right: true }
    margins.top: root.stackTop - root.padTop

    WlrLayershell.namespace: "shell-toasts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: column }

    Column {
        id: column

        anchors.top: parent.top
        anchors.topMargin: root.padTop
        anchors.right: parent.right
        anchors.rightMargin: Appearance.s.lg
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
                    id: arrive
                    from: 0
                    to: 1
                    duration: Appearance.t.base
                    easing.type: Appearance.t.standardEasing
                }

                // ...and back out to it. A plain animation rather than a
                // Behavior, so its end can be relied on to free the slot.
                // One pushed out by a burst before it has finished arriving
                // was never really seen and goes at once: played out, each
                // would hold its slot and push the ones shown down the screen.
                onLeavingChanged: {
                    if (!toast.leaving)
                        return;
                    if (arrive.running)
                        root.forget(toast.modelData);
                    else
                        leave.start();
                }

                ParallelAnimation {
                    id: leave
                    NumberAnimation { target: toast; property: "x"; to: 40; duration: Appearance.t.resize; easing.type: Appearance.t.standardEasing }
                    NumberAnimation { target: toast; property: "opacity"; to: 0; duration: Appearance.t.resize; easing.type: Appearance.t.standardEasing }
                    onFinished: root.forget(toast.modelData)
                }
            }
        }
    }
}
