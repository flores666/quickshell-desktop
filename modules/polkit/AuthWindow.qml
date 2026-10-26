pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/services"

/*!
    The polkit agent's password prompt (Polkit): a card in the middle of the
    focused screen, above everything the shell draws.

    A surface of its own on the overlay layer, ordered above the popups'
    (hyprland.conf's `shell-auth` rule), since what asks is usually one of
    them — the task manager applying earlyoom's options — and that popup
    stays open under it: while the prompt is up, Escape's bind and a click
    outside leave the popups alone (Overlay.authorizing). It spans the screen
    so the card can grow with what it says without the surface being resized,
    and takes input on the card alone; the keyboard on demand, never
    exclusive, which in Hyprland would take the pointer too. Hyprland gives
    it the keyboard as it maps, and the field takes it.

    Mapped exactly while there is a request or its card is fading out, on
    the screen that had focus as it came, kept there until it goes.
*/
PanelWindow {
    id: root

    /*! The request asked about (an AuthFlow), or null. shell.qml hands it
        Polkit's; a test hands it a stand-in, and so registers no agent. */
    property var flow: null
    readonly property bool shown: root.flow !== null
    /*! Stays true through the fade out. */
    property bool rendered: false
    readonly property alias card: authCard

    /*! The screen it came up on: the focused one, held while it is up, so
        moving the pointer to another screen does not take the prompt there
        (a new surface, and the keyboard asked for again). */
    property ShellScreen place: Compositor.focusedScreen

    onShownChanged: if (root.shown) {
        root.rendered = true;
        Qt.callLater(() => authCard.begin());
    }
    onRenderedChanged: root.place = root.rendered
        ? Compositor.focusedScreen
        : Qt.binding(() => Compositor.focusedScreen)

    screen: root.place
    visible: root.rendered
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-auth"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Nothing takes input but the card, and the card none once it is going.
    mask: Region { item: root.shown ? authCard : null }

    Binding {
        target: Overlay
        property: "authorizing"
        value: true
        when: root.rendered
    }

    Timer {
        // A Behavior's animation never emits finished(): the unmap is a
        // bound timer, as a popup's is.
        running: root.rendered && !root.shown
        interval: Appearance.t.popupFade + Appearance.t.grace
        onTriggered: root.rendered = false
    }

    AuthCard {
        id: authCard

        anchors.centerIn: parent
        flow: root.flow
        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Appearance.t.popupFade; easing.type: Appearance.t.standardEasing }
        }
    }
}
