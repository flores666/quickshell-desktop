pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Full media controls for the current MPRIS player.

    MPRIS pushes a jump in position (a seek, a new track) but not the clock
    running on, so the seek bar has the player re-announce it once a second —
    only while this card is actually on screen and the player actually playing.
*/
Surface {
    id: root

    property bool tracking: false

    readonly property bool hasLength: Players.length > 0
    readonly property real position: root.hasLength && Players.hasPlayer
        ? Math.min(1, Players.current.position / Players.length) : 0
    /*! Where a drag has the knob, held until the seek lands. */
    property real scrubValue: 0
    property bool scrubbing: false
    readonly property real shownValue: root.scrubbing ? root.scrubValue : root.position

    visible: Players.active
    implicitHeight: Players.active ? layout.implicitHeight + Appearance.s.lg * 2 : 0
    color: Appearance.c.raised
    radius: Appearance.r.md
    elevation: 0
    bordered: false

    // Time passing has no event, so while a track plays in view a clock on
    // the second has the bindings read the position again. Reading it asks
    // the player nothing — Quickshell works it out from the last position it
    // reported — so this is a clock, as Time's minute is, not a poll.
    SystemClock {
        enabled: root.visible && root.tracking && root.hasLength && Players.playing
        precision: SystemClock.Seconds
        onDateChanged: Players.current.positionChanged()
    }

    Row {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.s.lg
        spacing: Appearance.s.lg

        ClippingRectangle {
            width: 64
            height: 64
            radius: Appearance.r.sm
            color: Appearance.c.sunken

            Image {
                id: art
                anchors.fill: parent
                source: Players.artUrl
                visible: art.status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 128
                sourceSize.height: 128
                asynchronous: true
                cache: true
            }

            Icon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                name: "music"
                size: 26
                color: Appearance.c.textFaint
            }
        }

        Column {
            width: layout.width - 64 - layout.spacing
            spacing: Appearance.s.xs

            Label {
                width: parent.width
                text: Players.title !== "" ? Players.title : Players.identity
                font.weight: Font.DemiBold
            }

            Label {
                width: parent.width
                visible: Players.artist !== ""
                text: Players.artist
                role: Label.Role.Small
                muted: true
            }

            Item {
                width: parent.width
                height: 18
                visible: root.hasLength

                Slider {
                    id: seek
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    implicitHeight: 18
                    value: root.shownValue
                    interactive: Players.canSeek
                    onMoved: v => {
                        root.scrubbing = true;
                        root.scrubValue = v;
                    }
                    onCommitted: v => {
                        // Seek first, so the knob never shows the old place.
                        Players.seekTo(v);
                        root.scrubbing = false;
                    }
                }
            }

            Item {
                width: parent.width
                height: 30

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.s.xs

                    IconButton {
                        icon: "prev"
                        size: 30
                        enabled: Players.canPrev
                        onClicked: Players.previous()
                    }

                    IconButton {
                        icon: Players.playing ? "pause" : "play"
                        size: 30
                        accented: true
                        enabled: Players.canPlay
                        onClicked: Players.playPause()
                    }

                    IconButton {
                        icon: "next"
                        size: 30
                        enabled: Players.canNext
                        onClicked: Players.next()
                    }
                }

                Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasLength
                    text: Players.formatTime(root.shownValue * Players.length)
                        + " / " + Players.formatTime(Players.length)
                    role: Label.Role.Caption
                    faint: true
                }
            }
        }
    }
}
