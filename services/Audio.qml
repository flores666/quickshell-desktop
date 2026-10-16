pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

/*!
    Audio state, derived entirely from the PipeWire registry.

    Everything here degrades to a safe, inert state when PipeWire is missing or
    restarting: the default nodes simply become null and `ready` goes false, so
    the UI can hide or disable controls without any of it throwing.
*/
Singleton {
    id: root

    readonly property bool ready: Pipewire.ready
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // Until a node is bound its volume "may be missing or incorrect", and the
    // values it then reports are its state, not a change to announce.
    readonly property bool hasSink: root.ready && root.sink !== null && root.sink.ready
        && root.sink.audio !== null
    readonly property bool hasSource: root.ready && root.source !== null && root.source.ready
        && root.source.audio !== null

    readonly property real volume: root.hasSink ? root.sink.audio.volume : 0
    readonly property bool muted: root.hasSink ? root.sink.audio.muted : true
    /*! The level last asked for while the device has yet to report it, so a
        drag is followed at once (see setMicVolume). */
    readonly property real micVolume: !root.hasSource ? 0
        : root.micTarget >= 0 ? root.micTarget : root.source.audio.volume
    readonly property bool micMuted: root.hasSource ? root.source.audio.muted : true

    /*! The level asked of the microphone and not yet reported back by it, and
        the one waiting for the write in flight to finish; -1 for none. */
    property real micTarget: -1
    property real micQueued: -1

    onSourceChanged: {
        root.micTarget = -1;
        root.micQueued = -1;
    }

    /*! True while some application is actually capturing from the default source. */
    readonly property bool micInUse: sourceLinks.linkGroups.length > 0

    readonly property string volumeIcon: root.hasSink ? root.volumeIconFor(root.volume, root.muted)
        : "volume-muted"

    function volumeIconFor(volume: real, muted: bool): string {
        if (muted || volume < 0.01) return "volume-muted";
        if (volume <= 0.34) return "volume-low";
        if (volume <= 0.7) return "volume-medium";
        if (volume <= 1.0) return "volume-high";
        return "volume-over";
    }

    readonly property string micIcon: root.micMuted ? "mic-muted" : "mic"

    /*! Selectable output/input devices, excluding per-application streams. */
    readonly property var sinks: root.nodeList(true)
    readonly property var sources: root.nodeList(false)

    function nodeList(wantSink: bool): var {
        return Pipewire.nodes.values.filter(n =>
            n && n.isSink === wantSink && !n.isStream && n.audio !== null);
    }

    function deviceIcon(node: PwNode): string {
        if (!node)
            return "audio-card";
        const hint = [node.properties["device.icon-name"], node.name, node.description]
            .join(" ").toLowerCase();
        if (hint.includes("headset"))
            return "headset";
        if (hint.includes("headphone"))
            return "headphones";
        if (hint.includes("hdmi") || hint.includes("displayport"))
            return "display";
        if (hint.includes("bluetooth") || hint.includes("bluez"))
            return "bluetooth";
        return node.isSink ? "speakers" : "mic";
    }

    function nodeLabel(node: PwNode): string {
        if (!node)
            return "";
        return node.description !== "" ? node.description
            : node.nickname !== "" ? node.nickname : node.name;
    }

    /*! Asking for a level you can hear unmutes: that is what a drag means. */
    function setVolume(v: real): void {
        if (!root.hasSink)
            return;
        const level = Math.max(0, Math.min(1, v));
        if (root.muted && level > 0)
            root.sink.audio.muted = false;
        root.sink.audio.volume = level;
    }

    /*! A volume key: up unmutes, down only lowers what unmuting comes back to. */
    function stepVolume(delta: real): void {
        if (!root.hasSink)
            return;
        if (delta > 0 || !root.muted)
            root.setVolume(root.volume + delta);
        else
            root.sink.audio.volume = Math.max(0, root.volume + delta);
    }

    function toggleMute(): void {
        if (!root.hasSink)
            return;
        root.sink.audio.muted = !root.sink.audio.muted;
    }

    /*!
        Sets the microphone's level through WirePlumber, not on the node.

        Quickshell 0.3.1 writes the node's own volume, and a Bluetooth
        headset's microphone ignores that: Quickshell reported the new level,
        the device kept its old one (measured: wrote 0.3, `wpctl` still read
        0.6). Muting does reach the device, and the level it then reported —
        the real one, untouched — was what made the slider jump to 100% when
        its icon was clicked. `wpctl set-volume` sets the device's route, which
        every source honours; the speaker's writes do reach it and stay as
        they are. A drag asks for many levels: one write runs at a time, and
        only the latest asked for during it follows.
    */
    function setMicVolume(v: real): void {
        if (!root.hasSource)
            return;
        root.micTarget = Math.max(0, Math.min(1, v));
        if (micWriter.running)
            root.micQueued = root.micTarget;
        else
            root.writeMicLevel(root.micTarget);
    }

    function writeMicLevel(level: real): void {
        micWriter.command = ["wpctl", "set-volume", String(root.source.id), level.toFixed(3)];
        micWriter.running = true;
    }

    /*! Hands the slider back to the device once it reports what was asked. */
    function settleMicTarget(): void {
        if (root.micTarget >= 0 && root.micQueued < 0 && !micWriter.running && root.hasSource
                && Math.abs(root.source.audio.volume - root.micTarget) < 0.01)
            root.micTarget = -1;
    }

    Process {
        id: micWriter
        onExited: {
            const next = root.micQueued;
            root.micQueued = -1;
            if (next >= 0 && root.hasSource)
                root.writeMicLevel(next);
            else
                root.settleMicTarget();
        }
    }

    Connections {
        target: root.hasSource ? root.source.audio : null
        function onVolumesChanged(): void { root.settleMicTarget(); }
    }

    function toggleMicMute(): void {
        if (!root.hasSource)
            return;
        root.source.audio.muted = !root.source.audio.muted;
    }

    function setSink(node: PwNode): void {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setSource(node: PwNode): void {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    // Keeping the selectable devices bound means their volume, mute state and
    // description stay live without anyone polling for them.
    PwObjectTracker {
        objects: root.sinks.concat(root.sources)
    }

    PwNodeLinkTracker {
        id: sourceLinks
        node: root.source
    }
}
