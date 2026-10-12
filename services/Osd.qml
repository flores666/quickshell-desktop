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

    /*! How long the indicator stays up after the last change. */
    readonly property int holdTime: 1600

    readonly property bool suppressed: Overlay.isOpen(Overlay.quickSettings)

    function show(kind: string, value: real, icon: string, text: string): void {
        if (root.suppressed)
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
        interval: root.holdTime
        onTriggered: root.shown = false
    }

    // Each source is listened to only once it holds a true reading, so what
    // it reports while it comes up (at login, or a new default device) is
    // never announced, and nothing has to guess how long that takes. The
    // values are read off the node itself: the derived ones on Audio may not
    // have caught up with this very signal yet.
    Connections {
        target: Audio.hasSink ? Audio.sink.audio : null

        function onVolumesChanged(): void { root.showVolume(); }
        function onMutedChanged(): void { root.showVolume(); }
    }

    function showVolume(): void {
        const audio = Audio.sink.audio;
        root.show("volume", audio.muted ? 0 : audio.volume,
            Audio.volumeIconFor(audio.volume, audio.muted),
            audio.muted ? qsTr("Muted") : Math.round(audio.volume * 100) + "%");
    }

    Connections {
        target: Audio.hasSource ? Audio.source.audio : null

        function onMutedChanged(): void {
            const audio = Audio.source.audio;
            root.show("mic", audio.muted ? 0 : audio.volume, audio.muted ? "mic-muted" : "mic",
                audio.muted ? qsTr("Mic Muted") : qsTr("Mic On"));
        }
    }

    Connections {
        target: Brightness.available ? Brightness : null

        function onValueChanged(): void {
            root.show("brightness", Brightness.value, Brightness.icon,
                Math.round(Brightness.value * 100) + "%");
        }
    }
}
