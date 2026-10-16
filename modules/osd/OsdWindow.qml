pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The volume / microphone / brightness indicator.

    Purely informational: it takes no input at all (its input region is empty),
    so it can never swallow a click even while it is fading out.
*/
PanelWindow {
    id: root

    readonly property bool shown: Osd.shown
    property bool rendered: false

    screen: Compositor.focusedScreen
    visible: root.rendered
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    /*! Exactly the room the pill needs: it sits a fixed distance above the
        dock, and the dock is settable. The literal this replaced was two pixels
        short of the tuned layout and clipped the pill's shadow outright. */
    implicitHeight: Appearance.m.dockFootprint + Appearance.s.lg + pill.height
        + Appearance.shadowFor(pill.elevation).pad
    anchors { bottom: true; left: true; right: true }

    WlrLayershell.namespace: "shell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {}

    onShownChanged: if (root.shown) root.rendered = true

    Timer {
        // As in ShellOverlay: a Behavior's animation never emits finished(), so
        // the unmap is driven by a bound timer instead.
        running: root.rendered && !root.shown
        interval: Appearance.t.fast + 60
        onTriggered: root.rendered = false
    }

    Surface {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.m.dockFootprint + Appearance.s.lg
        width: 280
        height: 52
        radius: Appearance.r.capsule(pill.height)
        elevation: 3
        opacity: root.shown ? 1 : 0
        y: root.shown ? 0 : 8

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.t.fast
                easing.type: Appearance.t.standardEasing
            }
        }

        Icon {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            x: Appearance.s.xl
            name: Osd.icon
            size: Appearance.m.iconLg
        }

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            x: glyph.x + glyph.width + Appearance.s.lg
            width: value.x - x - Appearance.s.lg
            height: 8
            radius: height / 2
            color: Appearance.c.sunken

            Rectangle {
                width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, Osd.value)))
                height: parent.height
                radius: parent.radius
                color: Appearance.c.accent

                Behavior on width {
                    NumberAnimation { duration: Appearance.t.instant; easing.type: Appearance.t.standardEasing }
                }
            }
        }

        Label {
            id: value
            anchors.verticalCenter: parent.verticalCenter
            x: pill.width - width - Appearance.s.xl
            width: 44
            horizontalAlignment: Text.AlignRight
            text: Osd.text
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
        }
    }
}
