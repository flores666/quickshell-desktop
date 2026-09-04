pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    The transient volume / microphone / brightness indicator.

    It reacts to the *system* state changing rather than to any particular key
    binding, so it appears whether the change came from a media key, another
    application, or this shell — except while quick settings is open, where the
    slider itself is already the feedback.
*/
Singleton {
    id: root

    property string kind: ""
    property real value: 0
    property string icon: ""
    property string text: ""
    property bool shown: false

    /*! Suppresses the burst of change signals during startup. */
    property bool armed: false

    readonly property bool suppressed: Overlay.isOpen(Overlay.quickSettings)

    function show(kind: string, value: real, icon: string, text: string): void {
        if (!root.armed || root.suppressed)
            return;
        root.kind = kind;
        root.value = value;
        root.icon = icon;
        root.text = text;
        root.shown = true;
        hideTimer.restart();
    }

    function hide(): void {
        root.shown = false;
        hideTimer.stop();
    }

    Timer {
        id: hideTimer
        interval: 1600
        onTriggered: root.shown = false
    }

    Timer {
        // Long enough for PipeWire and the backlight to report their initial
        // values without any of it flashing an OSD at login.
        running: true
        interval: 2500
        onTriggered: root.armed = true
    }

    Connections {
        target: Audio
        enabled: Audio.hasSink

        function onVolumeChanged(): void {
            root.show("volume", Audio.volume, Audio.volumeIcon,
                Math.round(Audio.volume * 100) + "%");
        }

        function onMutedChanged(): void {
            root.show("volume", Audio.muted ? 0 : Audio.volume, Audio.volumeIcon,
                Audio.muted ? qsTr("Muted") : Math.round(Audio.volume * 100) + "%");
        }
    }

    Connections {
        target: Audio
        enabled: Audio.hasSource

        function onMicMutedChanged(): void {
            root.show("mic", Audio.micMuted ? 0 : Audio.micVolume, Audio.micIcon,
                Audio.micMuted ? qsTr("Mic Muted") : qsTr("Mic On"));
        }
    }

    Connections {
        target: Brightness
        enabled: Brightness.available

        function onValueChanged(): void {
            root.show("brightness", Brightness.value, Brightness.icon,
                Math.round(Brightness.value * 100) + "%");
        }
    }
}
