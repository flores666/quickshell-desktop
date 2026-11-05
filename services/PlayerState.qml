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
    readonly property bool canSeek: root.player !== null && root.player.canSeek
        && root.player.positionSupported && root.length > 0 && !root.changing
    readonly property real position: {
        const seconds = root.player && root.player.positionSupported ? root.player.position : 0;
        return Number.isFinite(seconds) ? Math.max(0, Math.min(root.length || Infinity, seconds)) : 0;
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
    }
    Component.onCompleted: if (root.player) root.collect()
}
