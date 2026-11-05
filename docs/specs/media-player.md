# Stable MPRIS media player

Yandex Music through Zen publishes several incomplete snapshots during a track
change: the page title, the new title with the previous duration, a snapshot
without duration, artwork available for a few milliseconds, then the new
duration without artwork. Its track ID and URL identify the tab rather than
the song. Passing those snapshots straight to the card erased the cover and
collapsed the timeline.

## Ownership and behavior

- `Players` keeps the sticky player selection and dispatches its actions.
  `PlayerState`, one instance per live MPRIS player, owns track metadata and
  position. Returning to a player retains its own track state; removing it
  destroys that state.
- Capture every metadata event and coalesce publication for a bounded 150 ms
  window. The window does not restart indefinitely when more metadata arrives.
  Within it, retain candidates for the transient page title and real track
  separately. Afterwards keep only the published track.
- Track identity includes the MPRIS ID, URL, title, artist and album. Missing
  cover and duration retain previously reported values only for that identity.
  A genuinely unknown duration or unsupported position has no seek control.
- Read one raw metadata snapshot at the event boundary. Quickshell's
  convenience bindings can still describe the preceding event during
  `metadataChanged`; D-Bus artist lists are QML sequences, so convert them with
  `Array.from` rather than testing `Array.isArray`.
- Position uses Quickshell's local extrapolation, clamped to finite,
  nonnegative values and the known duration. The card refreshes it with a
  `SystemClock` only while shown and playing, and immediately when reopened.
  The clock never queries the player.
- `Slider.started` captures each pointer or keyboard gesture's player and
  track. A change of track, player, capability or panel lifetime cancels that
  gesture until a fresh interaction starts. At dispatch, validate the actual
  player's capabilities and metadata identity again. A pending track change
  must reject a seek even before the published track changes.
- Artwork retains its decoded image while a replacement loads. The fallback
  glyph sits behind it and appears when no image is available.
- A control becoming nonfocusable releases focus before leaving the tab order,
  as Qt requires. Interaction state continues to belong to `Clickable`.

## Regression checks

`MediaPlayerTest` uses real MPRIS objects on the runner's private D-Bus session:
cover/duration withdrawal, transient page titles, track changes with constant
browser IDs, unknown duration, unsupported position, position bounds, player
selection and removal, and per-player retention.

`MediaTimelineTest` exercises the real card in a nested compositor: decoded
artwork, unchanged card height and timeline presence during updates, actual Qt
pointer events across a track change, dispatch identity checks, microsecond
seeking, visible/hidden clocks, immediate reopening and pausing. It counts
position reads at the protocol boundary to prove the clock does not poll.

`DragControlsTest` covers the shared pointer/keyboard/wheel behavior and focus
release when a slider becomes unavailable. `tools/test.sh MediaPlayerTest
MediaTimelineTest DragControlsTest` runs these suites; the media fixtures never
address the session's real players.

Live verification with Yandex Music through Zen retained a decoded cover after
the browser withdrew its URL. A subsequent track change kept the timeline
mapped throughout and replaced the previous duration with the newly reported
one. Screenshots and `hyprctl layers` confirmed the real card's geometry in a
nested compositor; the restarted desktop shell logged no unexpected messages.

## Browser player discovery

Zen can acquire its MPRIS name before exporting `/org/mpris/MediaPlayer2`.
Quickshell 0.3's initial `GetAll` then fails with `UnknownMethod`. Later property
signals fill the hidden native player, but the watcher only admits it after a
successful initial read, so the whole media card stays absent.

`Players` loads `MprisWatch` from the existing optional native module. The hook
observes initial read failures and real property signals. Once a failed
player's current D-Bus owner announces readiness, it asks Quickshell's own
watcher to recreate that registration and read all properties. Attaching after
an earlier failure also recognizes an already populated hidden player. Healthy
players retain their objects and receive no additional reads.

There is no public Quickshell API to retry discovery. The hook checks the
watcher's exact class, model property and registration slots before invoking
those internal slots. An incompatible version or missing native module uses
ordinary MPRIS discovery with a warning. It never supplies replacement player
data or control implementations. The module is rebuilt by the existing native
build/install path and links Qt DBus, already supplied by Qt Base.

Queued work is tied to the native player object, model generation and D-Bus
owner. Retired objects and healthy or replaced registrations are rejected both
when work is queued and before it acts. A failed attempt waits for a new real
readiness event; no timer retries or player polling are introduced.

`MediaDiscoveryTest` publishes a name before its object, reproduces the failed
initial read, then exports a playing YouTube-style player. It checks visible
controls, artwork and timeline, unchanged healthy-player read counts, and
withdrawal/replacement under the same name. `MediaDiscoveryAttachTest` loads
the service after discovery has already failed and the browser has already
sent its metadata, proving recovery without another event.
