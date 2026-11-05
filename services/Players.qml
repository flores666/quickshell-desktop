pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

/*!
    MPRIS media state.

    Exactly one player is "current" at a time.  The choice is sticky — it only
    moves when the current player stops being a sensible answer — so the panel
    does not flip between players while several are open.  A player quitting is
    an ordinary event here: the list changes, the selection is re-derived, and
    every accessor degrades to empty.
*/
Singleton {
    id: root

    readonly property var players: Mpris.players.values.filter(p => p)
    readonly property bool any: root.players.length > 0

    property PlayerState selected: null
    readonly property MprisPlayer current: root.selected ? root.selected.player : null

    readonly property bool hasPlayer: root.current !== null
    readonly property bool playing: root.hasPlayer
        && root.current.playbackState === MprisPlaybackState.Playing
    readonly property bool paused: root.hasPlayer
        && root.current.playbackState === MprisPlaybackState.Paused
    readonly property bool active: root.playing || root.paused

    readonly property string title: root.selected ? root.selected.track.title : ""
    readonly property string artist: root.selected ? root.selected.track.artist : ""
    readonly property string artUrl: root.selected ? root.selected.track.artUrl : ""
    readonly property string trackKey: root.selected ? root.selected.track.key : ""
    readonly property string identity: root.hasPlayer ? root.current.identity : ""

    readonly property bool canPlay: root.hasPlayer && root.current.canTogglePlaying
    readonly property bool canNext: root.hasPlayer && root.current.canGoNext
    readonly property bool canPrev: root.hasPlayer && root.current.canGoPrevious
    readonly property bool canSeek: root.hasPlayer && root.selected.canSeek

    readonly property real length: root.hasPlayer ? root.selected.length : 0
    readonly property real position: root.hasPlayer ? root.selected.position : 0

    property var discovery: null
    Component.onCompleted: {
        try {
            root.discovery = Qt.createQmlObject("import Desktop.Native; MprisWatch {}", root, "Players");
            root.discovery.model = Mpris.players;
        } catch (e) {
            console.warn("Players: native MPRIS discovery recovery is unavailable (tools/build-native-module.sh)");
        }
    }

    function pick(): void {
        const live = Mpris.players.values;
        const list = [];
        for (let i = 0; i < states.count; ++i) {
            const state = states.objectAt(i) as PlayerState;
            if (state && live.indexOf(state.player) !== -1)
                list.push(state);
        }
        if (list.length === 0) {
            root.selected = null;
            return;
        }
        // Keep the current choice while it is still playing, or while nothing
        // else is; only a different player actually starting steals the slot.
        if (root.selected && list.indexOf(root.selected) !== -1) {
            if (root.selected.player.playbackState === MprisPlaybackState.Playing)
                return;
            const other = list.find(p => p.player.playbackState === MprisPlaybackState.Playing);
            root.selected = other ?? root.selected;
            return;
        }
        root.selected = list.find(p => p.player.playbackState === MprisPlaybackState.Playing) ?? list[0];
    }

    function playPause(): void {
        if (root.canPlay)
            root.current.togglePlaying();
    }

    function next(): void {
        if (root.canNext)
            root.current.next();
    }

    function previous(): void {
        if (root.canPrev)
            root.current.previous();
    }

    function seekTo(fraction: real, subject: PlayerState, key: string): void {
        // A gesture belongs to the player and track it began on. Capabilities
        // and the raw pending identity are checked again at dispatch.
        const player = root.current;
        if (player && subject && subject === root.selected && Number.isFinite(fraction)
            && player.canSeek && player.positionSupported && subject.track.length > 0
            && key === subject.track.key && subject.describe().key === key)
            subject.requestSeek(Math.max(0, Math.min(1, fraction)) * subject.track.length);
    }

    function refreshPosition(): void {
        // Quickshell extrapolates locally. This reads no D-Bus property.
        if (root.hasPlayer && root.current.positionSupported)
            root.selected.refreshPosition();
    }

    function formatTime(seconds: real): string {
        if (!Number.isFinite(seconds) || !(seconds > 0))
            return "0:00";
        const total = Math.floor(seconds);
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        const mm = h > 0 ? String(m).padStart(2, "0") : String(m);
        return (h > 0 ? `${h}:` : "") + `${mm}:${String(s).padStart(2, "0")}`;
    }
    onPlayersChanged: root.pick()

    Instantiator {
        id: states
        // Watching every player's playback state (not just the current one) is
        // what lets the selection follow whichever player the user just started.
        model: Mpris.players

        delegate: PlayerState {
            required property MprisPlayer modelData
            player: this.modelData
            onPlaybackStateChanged: root.pick()
        }
        onObjectAdded: root.pick()
        onObjectRemoved: root.pick()
    }
}
