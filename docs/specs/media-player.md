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
- `PlayerState` retains the latest seek intent until the matching backend
  reply, a source/track invalidation, or a one-second bound. Its ordered request
  history distinguishes repeated targets (A/B/A); an old A reply cannot confirm
  the final A. Older replies cannot roll back the value that the next key uses.
  Local setter notifications and clock reads never count as acknowledgements.
  Playback/rate changes rebase the intended position without losing the request.
  The history is pruned on requests by that same bound, without polling.
- `MediaTimeline` animates track changes, player position jumps and pointer or
  keyboard seeks. Its presentation value stays independent of the actual
  value used for dispatch. Rapid retargets use Qt's `SmoothedAnimation` without
  stopping or resetting its value first, preserving position and velocity.
  While `PlayerState.changing`
  holds, it keeps the previous position and elapsed time, so an early backend
  reset does not jump ahead of publication. Metadata and position notifications
  are collected with `Qt.callLater` before starting one transition. The timeline
  owns its local clock and marks those reads so playback ticks snap without
  starting another seek animation. The clock resumes after motion ends.
  Hiding the card stops motion and snaps to the actual position; reopening
  refreshes immediately without replaying hidden seeks.
  `Slider` owns value mapping and interaction; its separate `displayed` value
  never changes what a gesture dispatches.
- Artwork keeps two image slots and cross-fades once a new track's replacement
  decodes. A URL refresh on the same track replaces the image without a fade.
  Each slot includes its opaque well and fallback glyph; the incoming slot
  fades over the fully drawn outgoing slot, avoiding a brightness dip halfway
  through, including with transparent artwork. After the fade the outgoing
  source is released. Requests during a fade coalesce to the latest track and
  URL without reusing its outgoing slot early. Hidden updates load without
  animation; closing mid-fade completes it and applies any queued replacement.
  Returning to the displayed source cancels an obsolete pending load. A failed
  URL is retried once when another track or player requests it; repeated events
  for that same failed track do not form a retry loop.
- Player transitions share `t.mediaChange` (240 ms), 1.5 times faster than the
  previous 360 ms. Artwork uses `t.mediaEasing` (`InOutSine`); the timeline's
  native smoothing has short `t.mediaEasingTime` acceleration/deceleration ramps
  and immediate reversal without overshooting the slider's bounds. Playback
  clock ticks remain unanimated.
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
release when a slider becomes unavailable. `MediaTransitionsTest` checks
animated position changes, pointer and keyboard seeks, holding an early
position reset until track publication, track transitions and seeking during
them, same-track artwork refreshes, hidden updates, decoded cover retention,
rapid cover replacement, fallback fades and closing mid-transition.
`MediaSeekLifecycleTest` checks rapid pointer reversal, coalesced drag targets,
repeated keys and targets, stale acknowledgements, missing confirmations,
playback/rate changes, exact dispatch, hidden seeks and player removal during motion.
`MediaArtworkLifecycleTest` holds a real loopback HTTP reply until cancellation,
then releases it to check that obsolete work cannot replace the live image;
it also makes a failed file URL available before another track retries it.
`tools/test.sh MediaPlayerTest MediaTimelineTest MediaTransitionsTest
MediaSeekLifecycleTest MediaArtworkLifecycleTest DragControlsTest` runs these suites;
the media fixtures never address the session's real players.

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

## QML Code Review Report

**Scope**: files: `components/Slider.qml`, `config/Motion.qml`,
`modules/panels/MediaCard.qml`, `MediaTimeline.qml`, `MediaArtwork.qml`,
`services/PlayerState.qml`, `services/Players.qml`.
**Files reviewed**: 7
**Issues found**: 17 (13 lint recommendations, 4 confirmed behavioral findings, all fixed)
**Agents**: 0 (inline, A1–A7)
**qmllint**: ran through `tools/lint.sh`; only the documented native-registration warnings remain.

---

### Lint findings

The generic style checker reports the following recommendations. Dynamic
records keep metadata and seek intent atomic; the guarded native import must
continue to work when the optional module is absent. These are distinct from
the confirmed behavior faults below.

| Rule | Count | Locations | Mitigation |
|---|---:|---|---|
| BND-1 Dynamic properties | 4 | `PlayerState.qml:17,18,24`, `Players.qml:47` | Preserve coherent record updates; typed records would require an architectural change. |
| LDR-3 Dynamic creation | 1 | `Players.qml:50` | Preserve optional-module failure handling in any replacement. |
| ORD-1 Member ordering | 7 | `Slider.qml:50`, `MediaCard.qml:44`, `MediaArtwork.qml:67,95`, `PlayerState.qml:110,144`, `Players.qml:131` | Group members consistently when editing their responsibilities. |
| STY-3 Anchor notation | 1 | `MediaCard.qml:54` | Group the anchor assignments in a formatting change. |

---

### Deep analysis findings

#### [D-001] Seek retargets could jump to an old endpoint
- **File**: `modules/panels/MediaTimeline.qml:28`
- **Category**: States, Transitions & Migration
- **Confidence**: 100/100
- **Finding**: Fixed. Stopping the old animation switched presentation back to the raw value before another target could take over.
- **Trace**: `Slider.started/moved` → `MediaCard` scrub target → timeline animation. Interrupting a track transition exposed its old endpoint; repeated restarts also discarded velocity. Visibility changes could snapshot a stale derived value during teardown.
- **Mitigation**: Keep one persistent presentation value, retarget native `SmoothedAnimation` without stopping it, and snap from the live source on teardown. `MediaTransitionsTest` and `MediaSeekLifecycleTest` cover interruption, reversal, hiding and removal.

#### [D-002] Returning to the current cover left obsolete loading work
- **File**: `modules/panels/MediaArtwork.qml:38`
- **Category**: Component Loading & Lifecycle
- **Confidence**: 100/100
- **Finding**: Fixed. The same-source early return remembered the new track but retained the other slot's obsolete request.
- **Trace**: Decoded A → slow HTTP B → request A again. The pending B source remained populated and its late response still consumed resources.
- **Mitigation**: Clear the pending slot before the early return and validate decoded results through the coalesced load path. `MediaArtworkLifecycleTest` releases the real obsolete HTTP reply and checks that it cannot replace A.

#### [D-003] A failed cover URL could not recover for a later track
- **File**: `modules/panels/MediaArtwork.qml:49`
- **Category**: Component Loading & Lifecycle
- **Confidence**: 100/100
- **Finding**: Fixed. URL equality skipped replacement even when the displayed slot was in `Image.Error` and a new track requested it.
- **Trace**: Missing file → fallback → file becomes available → another track uses the same URL. The old equality guard prevented a new read.
- **Mitigation**: Retry an errored same-URL image on a new track/player identity, never repeatedly for the same failed identity. The lifecycle test creates the missing file and verifies recovery without a timer retry loop.

#### [D-004] Older seek acknowledgements could erase newer key steps
- **File**: `services/PlayerState.qml:40`
- **Category**: Logic & Wiring
- **Confidence**: 100/100
- **Finding**: Fixed. Five rapid arrow presses could advance three steps because earlier `Seeked` signals replaced the value used by a later key.
- **Trace**: Arrow → actual slider value → `Players.seekTo` → native setter → older asynchronous `Seeked` reply → next arrow. A single target comparison also cannot distinguish the first and last A in A/B/A.
- **Mitigation**: Retain bounded intent and ordered request identities at `PlayerState`, exclude local reads/writes from confirmation, and release on final acknowledgement or timeout. The rapid-seek suite covers repeated targets, stale replies, missing replies and playback/rate changes.

---

### Investigation targets (human verification needed)

No additional candidate met the review's confidence threshold after tracing A1–A7.

---

### Summary

| Category | Lint | Deep | Investigate | Total |
|---|---:|---:|---:|---:|
| Bindings & Properties | 4 | 0 | 0 | 4 |
| Component Loading & Lifecycle | 1 | 2 | 0 | 3 |
| Performance & Code Quality | 8 | 0 | 0 | 8 |
| States, Transitions & Migration | 0 | 1 | 0 | 1 |
| Logic & Wiring | 0 | 1 | 0 | 1 |
| **Total** | **13** | **4** | **0** | **17** |

Findings below confidence 60 are suppressed.
