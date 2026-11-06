pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

/*! One player's track, retained across incomplete MPRIS updates. Browsers can
    publish a page title between track updates, withdraw artwork just after
    publishing it, and send the old duration before the new one. Capture every
    update, then publish one coherent track after a bounded coalescing window. */
Scope {
    id: root

    required property MprisPlayer player
    readonly property int playbackState: root.player ? root.player.playbackState : MprisPlaybackState.Stopped

    property var track: ({ key: "", title: "", artist: "", artUrl: "", length: 0 })
    property var candidates: ({})
    property string pendingKey: ""
    readonly property bool changing: root.pendingKey !== root.track.key
    readonly property real length: root.track.length
    readonly property bool canSeek: root.hasTimeline() && root.player.canSeek && !root.changing
    property var pendingSeek: null
    property bool writingPosition: false
    property bool readingPosition: false
    readonly property real position: {
        // Keep the native dependency even while a requested position is held:
        // the visible clock still advances by notifying that property locally.
        const reported = root.player && root.player.positionSupported ? root.player.position : 0;
        const seconds = root.pendingSeek ? root.intendedPosition(root.pendingSeek, Date.now()) : reported;
        return Number.isFinite(seconds) ? Math.max(0, Math.min(root.length || Infinity, seconds)) : 0;
    }
    onPendingKeyChanged: if (root.pendingSeek && root.pendingKey !== root.pendingSeek.key) root.cancelSeek()

    /*! Read the live subject even during signal delivery, before derived flags
        settle. Timing does not require seek permission or a settled track. */
    function hasTimeline(): bool {
        return root.player !== null && root.player.positionSupported && root.track.length > 0;
    }

    function intendedPosition(seek: var, now: real): real {
        return seek.position + (seek.playing ? (now - seek.at) / 1000 * seek.rate : 0);
    }

    function requestSeek(seconds: real): void {
        // Players validated the live subject, raw track identity and capability
        // in this event. Hold its latest intent across older Seeked replies.
        const now = Date.now();
        const requests = root.pendingSeek
            ? root.pendingSeek.requests.filter(request => now - request.at < seekBound.interval) : [];
        root.pendingSeek = { position: seconds, at: now, key: root.track.key,
            playing: root.player.playbackState === MprisPlaybackState.Playing, rate: root.player.rate,
            requests: requests.concat([{ target: seconds, at: now }]) };
        root.writingPosition = true;
        root.player.position = seconds;
        root.writingPosition = false;
        seekBound.restart();
    }

    function refreshPosition(): void {
        root.readingPosition = true;
        root.player.positionChanged();
        root.readingPosition = false;
    }

    function cancelSeek(): void {
        seekBound.stop();
        root.pendingSeek = null;
    }

    function rebaseSeek(): void {
        if (!root.pendingSeek) return;
        const now = Date.now();
        root.pendingSeek = Object.assign({}, root.pendingSeek, {
            position: root.intendedPosition(root.pendingSeek, now), at: now,
            playing: root.player.playbackState === MprisPlaybackState.Playing, rate: root.player.rate
        });
    }

    function acceptPosition(): void {
        const seek = root.pendingSeek;
        if (!seek || root.writingPosition || root.readingPosition) return;
        const position = root.player.position;
        const index = seek.requests.findIndex(request => Math.abs(position - request.target) < 0.001);
        if (index < 0) return;
        // A target can be requested again: the first A reply in A/B/A cannot
        // acknowledge the last A. Coalesced replies remain bounded by timeout.
        if (index === seek.requests.length - 1) root.cancelSeek();
        else root.pendingSeek = Object.assign({}, seek, { requests: seek.requests.slice(index + 1) });
    }

    Timer {
        id: seekBound
        // A bound on an unconfirmed backend write, not presentation timing.
        interval: 1000
        onTriggered: root.cancelSeek()
    }

    function describe(): var {
        const player = root.player;
        const metadata = player ? player.metadata : ({});
        function text(key) { return typeof metadata[key] === "string" ? metadata[key] : ""; }
        // Read one metadata snapshot: the convenience properties can still
        // describe the preceding update while metadataChanged is delivered.
        // A D-Bus QStringList is a QML sequence, not a JavaScript Array.
        const title = text("xesam:title");
        const artists = metadata["xesam:artist"];
        const artist = artists && typeof artists !== "string" && typeof artists.length === "number"
            ? Array.from(artists).filter(a => typeof a === "string").join(", ") : "";
        // Browser track IDs and URLs can name the whole tab. The track's
        // actual identity must also include its title, artist and album.
        const key = JSON.stringify([String(metadata["mpris:trackid"] ?? ""), text("xesam:url"),
            title, artist, text("xesam:album")]);
        const seconds = Number(metadata["mpris:length"]) / 1000000;
        return { key, title, artist, artUrl: text("mpris:artUrl"),
            length: Number.isFinite(seconds) && seconds > 0 ? seconds : 0 };
    }

    function collect(): void {
        const next = root.describe();
        const previous = root.candidates[next.key] ?? (root.track.key === next.key ? root.track : null);
        next.artUrl = next.artUrl || previous?.artUrl || "";
        next.length = next.length || previous?.length || 0;
        root.candidates[next.key] = next;
        root.pendingKey = next.key;
        if (!settle.running) settle.start();
    }

    Timer {
        id: settle
        // Backend burst coalescing, not a presentation duration or a poll.
        interval: 150
        onTriggered: {
            root.track = root.candidates[root.pendingKey];
            root.candidates = ({});
        }
    }
    Connections {
        target: root.player
        function onMetadataChanged(): void { root.collect(); }
        function onPositionChanged(): void {
            root.acceptPosition();
        }
        function onCanSeekChanged(): void { if (!root.player?.canSeek) root.cancelSeek(); }
        function onPositionSupportedChanged(): void { if (!root.player?.positionSupported) root.cancelSeek(); }
        function onPlaybackStateChanged(): void { root.rebaseSeek(); }
        function onRateChanged(): void { root.rebaseSeek(); }
    }
    Component.onCompleted: if (root.player) root.collect()
}
