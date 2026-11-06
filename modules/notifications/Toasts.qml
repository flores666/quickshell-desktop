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

    /*! Toasts on screen, including any still fading out. */
    readonly property var shown: column.shown

    screen: Compositor.focusedScreen
    visible: root.shown.length > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    /*! Where the stack starts: clear of the bar, since an "ignore exclusive
        zones" surface starts at the screen edge. */
    readonly property int stackTop: Appearance.m.barFootprint + Appearance.m.popupGap
    /*! Room around the stack for the toasts' shadow, as much as the screen
        leaves, as in OverlaySurface: the surface reaches up over the bar and out
        to the screen's edge, and the stack sits where it belongs inside it. */
    readonly property int pad: Appearance.shadowFor(3).pad
    readonly property int padTop: Math.min(root.pad, root.stackTop)

    // The full cap rather than the stack's height: when a toast leaves, the
    // ones below slide up from where they were, and a surface that shrank to
    // the new height at once would cut the bottom one off mid-slide.
    implicitHeight: root.padTop + 600 + root.pad
    implicitWidth: root.pad + column.width + Appearance.s.md
    anchors { top: true; right: true }
    margins.top: root.stackTop - root.padTop

    WlrLayershell.namespace: "shell-toasts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: column }

    NotificationStack {
        id: column

        anchors.top: parent.top
        anchors.topMargin: root.padTop
        anchors.right: parent.right
        anchors.rightMargin: Appearance.s.md
        // Match the system panel's width and screen-edge clearance.
        width: Math.min(Appearance.m.popoverWidth,
            (Compositor.focusedScreen ? Compositor.focusedScreen.width : Appearance.m.popoverWidth) - Appearance.s.md * 2)
        notifications: Notifs.popups
        standalone: true
    }
}
