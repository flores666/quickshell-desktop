pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Full media controls for the current MPRIS player.

    Players owns track metadata and position. This card only refreshes the
    local clock while it is shown, and holds a seek's subject for its gesture.
*/
Surface {
    id: root

    property bool tracking: false

    readonly property bool hasLength: Players.length > 0 && Players.hasPlayer && Players.current.positionSupported
    readonly property real position: root.hasLength ? Players.position / Players.length : 0
    /*! Where a drag has the knob, held until the seek lands. */
    property real scrubValue: 0
    property bool scrubbing: false
    property bool scrubCancelled: false
    property PlayerState scrubSubject: null
    property string scrubKey: ""
    readonly property real shownValue: root.scrubbing ? root.scrubValue : root.position

    function cancelScrub(): void {
        // Keep a cancelled gesture cancelled through capability changes.
        // Clickable.pressed can fall and rise while the mouse stays held.
        if (root.scrubbing) root.scrubCancelled = true;
        root.scrubbing = false;
        root.scrubSubject = null;
    }
    onTrackingChanged: {
        if (root.tracking) Players.refreshPosition();
        else root.cancelScrub();
    }
    Connections {
        target: Players
        function onCurrentChanged(): void { root.cancelScrub(); }
        function onTrackKeyChanged(): void { root.cancelScrub(); }
        function onCanSeekChanged(): void { if (!Players.canSeek) root.cancelScrub(); }
    }

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
        onDateChanged: Players.refreshPosition()
    }

    Row {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.s.lg
        spacing: Appearance.s.lg

        ClippingRectangle {
            width: Appearance.m.mediaArt
            height: Appearance.m.mediaArt
            radius: Appearance.r.sm
            color: Appearance.c.sunken

            Icon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                name: "music"
                size: Appearance.m.mediaFallback
                color: Appearance.c.textFaint
            }

            Image {
                id: art
                anchors.fill: parent
                source: Players.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: Appearance.m.mediaArt * 2
                sourceSize.height: Appearance.m.mediaArt * 2
                asynchronous: true
                cache: true
                retainWhileLoading: true
            }
        }

        Column {
            width: layout.width - Appearance.m.mediaArt - layout.spacing
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
                height: Appearance.m.mediaSeek
                visible: root.hasLength

                Slider {
                    id: seek
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    implicitHeight: Appearance.m.mediaSeek
                    value: root.shownValue
                    interactive: Players.canSeek
                    onStarted: {
                        root.scrubCancelled = false;
                        root.scrubSubject = Players.selected;
                        root.scrubKey = Players.trackKey;
                    }
                    onMoved: v => {
                        if (root.scrubCancelled || !Players.canSeek) return;
                        root.scrubbing = true;
                        root.scrubValue = v;
                    }
                    onCommitted: v => {
                        // Seek first, so the knob never shows the old place.
                        if (root.scrubbing && !root.scrubCancelled) Players.seekTo(v, root.scrubSubject, root.scrubKey);
                        root.cancelScrub();
                        root.scrubCancelled = false;
                    }
                }
            }

            Item {
                width: parent.width
                height: Appearance.m.mediaButton

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.s.xs

                    IconButton {
                        icon: "prev"
                        size: Appearance.m.mediaButton
                        enabled: Players.canPrev
                        onClicked: Players.previous()
                    }

                    IconButton {
                        icon: Players.playing ? "pause" : "play"
                        size: Appearance.m.mediaButton
                        accented: true
                        enabled: Players.canPlay
                        onClicked: Players.playPause()
                    }

                    IconButton {
                        icon: "next"
                        size: Appearance.m.mediaButton
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
