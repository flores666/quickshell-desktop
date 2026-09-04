pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Full media controls for the current MPRIS player.

    The position readout is the one thing MPRIS will not push, so the seek bar
    polls — but only while this card is actually on screen and the player is
    actually playing.
*/
Surface {
    id: root

    property bool tracking: false

    readonly property bool hasLength: Players.length > 0
    property real scrubValue: 0
    property bool scrubbing: false

    visible: Players.active
    implicitHeight: Players.active ? layout.implicitHeight + Appearance.s.lg * 2 : 0
    color: Appearance.c.raised
    radius: Appearance.r.md
    elevation: 0
    bordered: false

    Timer {
        // MPRIS does not signal position changes, so the seek bar is the one
        // place the shell polls — and only while it is visible and playing.
        running: root.visible && root.tracking && root.hasLength
        interval: 1000
        // One read when the card appears; repeating only while it is moving.
        repeat: Players.playing
        triggeredOnStart: true
        onTriggered: if (!root.scrubbing && Players.hasPlayer)
            root.scrubValue = Players.current.position / Players.length
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
                    value: root.scrubValue
                    interactive: Players.canSeek
                    onMoved: v => {
                        root.scrubbing = true;
                        root.scrubValue = v;
                    }
                    onCommitted: v => {
                        root.scrubbing = false;
                        Players.seekTo(v);
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
                    text: Players.formatTime(root.scrubValue * Players.length)
                        + " / " + Players.formatTime(Players.length)
                    role: Label.Role.Caption
                    faint: true
                }
            }
        }
    }
}
