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

    property MprisPlayer current: null

    readonly property bool hasPlayer: root.current !== null
    readonly property bool playing: root.hasPlayer
        && root.current.playbackState === MprisPlaybackState.Playing
    readonly property bool paused: root.hasPlayer
        && root.current.playbackState === MprisPlaybackState.Paused
    readonly property bool active: root.playing || root.paused

    readonly property string title: root.hasPlayer ? root.current.trackTitle : ""
    readonly property string artist: root.hasPlayer ? root.current.trackArtist : ""
    readonly property string artUrl: root.hasPlayer ? root.current.trackArtUrl : ""
    readonly property string identity: root.hasPlayer ? root.current.identity : ""
    readonly property string appIcon: root.hasPlayer ? root.current.desktopEntry : ""

    readonly property bool canPlay: root.hasPlayer && root.current.canTogglePlaying
    readonly property bool canNext: root.hasPlayer && root.current.canGoNext
    readonly property bool canPrev: root.hasPlayer && root.current.canGoPrevious
    readonly property bool canSeek: root.hasPlayer && root.current.canSeek
        && root.current.lengthSupported && root.current.length > 0

    readonly property real length: root.hasPlayer && root.current.lengthSupported
        ? root.current.length : 0

    /*! A one-line "Artist — Title", or just the title, or "" when idle. */
    readonly property string summary: {
        if (!root.active || root.title === "")
            return "";
        return root.artist !== "" ? `${root.artist} — ${root.title}` : root.title;
    }

    function pick(): void {
        const list = root.players;
        if (list.length === 0) {
            root.current = null;
            return;
        }
        // Keep the current choice while it is still playing, or while nothing
        // else is; only a different player actually starting steals the slot.
        if (root.current && list.indexOf(root.current) !== -1) {
            if (root.current.playbackState === MprisPlaybackState.Playing)
                return;
            const other = list.find(p => p.playbackState === MprisPlaybackState.Playing);
            root.current = other ?? root.current;
            return;
        }
        root.current = list.find(p => p.playbackState === MprisPlaybackState.Playing) ?? list[0];
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

    function seekTo(fraction: real): void {
        if (root.canSeek)
            root.current.position = Math.max(0, Math.min(1, fraction)) * root.length;
    }

    function raise(): void {
        if (root.hasPlayer && root.current.canRaise)
            root.current.raise();
    }

    function formatTime(seconds: real): string {
        if (!(seconds > 0))
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
        // Watching every player's playback state (not just the current one) is
        // what lets the selection follow whichever player the user just started.
        model: Mpris.players

        delegate: QtObject {
            required property MprisPlayer modelData
            readonly property int state: this.modelData ? this.modelData.playbackState : 0
            onStateChanged: root.pick()
        }
    }
}
