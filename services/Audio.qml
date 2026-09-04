pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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

    readonly property bool hasSink: root.ready && root.sink !== null && root.sink.audio !== null
    readonly property bool hasSource: root.ready && root.source !== null && root.source.audio !== null

    readonly property real volume: root.hasSink ? root.sink.audio.volume : 0
    readonly property bool muted: root.hasSink ? root.sink.audio.muted : true
    readonly property real micVolume: root.hasSource ? root.source.audio.volume : 0
    readonly property bool micMuted: root.hasSource ? root.source.audio.muted : true

    /*! True while some application is actually capturing from the default source. */
    readonly property bool micInUse: sourceLinks.linkGroups.length > 0

    readonly property string volumeIcon: !root.hasSink || root.muted ? "volume-muted"
        : root.volume < 0.01 ? "volume-muted"
        : root.volume <= 0.34 ? "volume-low"
        : root.volume <= 0.7 ? "volume-medium"
        : root.volume <= 1.0 ? "volume-high"
        : "volume-over"

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

    function setVolume(v: real): void {
        if (!root.hasSink)
            return;
        root.sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function stepVolume(delta: real): void {
        if (!root.hasSink)
            return;
        if (root.muted && delta > 0)
            root.sink.audio.muted = false;
        root.setVolume(root.volume + delta);
    }

    function toggleMute(): void {
        if (!root.hasSink)
            return;
        root.sink.audio.muted = !root.sink.audio.muted;
    }

    function setMicVolume(v: real): void {
        if (!root.hasSource)
            return;
        root.source.audio.volume = Math.max(0, Math.min(1, v));
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
