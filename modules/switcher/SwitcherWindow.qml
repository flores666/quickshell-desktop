pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The window switcher (Switcher) as macOS draws Command-Tab: a glass card in
    the middle of the screen in front, a row of the windows it goes round by
    their applications' icons, the one chosen highlighted and named under the
    row.

    It shows once Alt has been held a moment after Alt+Tab (`t.glance`), so a
    quick one only switches. It takes no keyboard focus — Hyprland holds the
    keys — and the pointer only on the card, and only once the pointer moves:
    one that happens to be where the card opens must not choose for you. Then
    resting on an entry chooses it, and a click brings it forward.

    It fades and slides into place and back out, at a pace of its own
    (`t.switcherPace`). What it shows
    is held through the fade out, and the title under the row changes only
    once the last has faded out.
*/
PanelWindow {
    id: root

    property bool glanced: false
    readonly property bool shown: Switcher.active && root.glanced
    property bool rendered: false

    /*! What it goes round and the one chosen, as drawn: held once Alt is let
        go of, so the row does not empty and the highlight does not jump to
        the first entry while the card fades out. */
    property var entries: []
    property int chosen: 0
    readonly property var current: root.entries[root.chosen] ?? null

    Binding {
        target: root
        property: "entries"
        when: Switcher.active
        value: Switcher.entries
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root
        property: "chosen"
        when: Switcher.active
        value: Switcher.index
        restoreMode: Binding.RestoreNone
    }

    /*! The entry whose title is under the row. It follows the one chosen only
        once the last title has faded out, as quick settings' pages do: two
        fading into each other are both legible at half strength, which reads
        as a smear. Set at once as the card comes up, which fades in itself. */
    property var named: null
    readonly property bool renaming: root.named !== root.current

    /*! A short slide into place, and the fade. */
    property real entry: root.shown ? 0 : -Appearance.s.md
    property real fade: root.shown ? 1 : 0

    Behavior on entry {
        NumberAnimation { duration: Appearance.t.switcherMove; easing.type: Appearance.t.emphasizedEasing }
    }

    Behavior on fade {
        NumberAnimation { duration: Appearance.t.switcherFade; easing.type: Appearance.t.standardEasing }
    }
    /*! Where the pointer was as the card came up, and whether it has moved. */
    property point entered: Qt.point(-1, -1)
    property bool pointerMoved: false

    readonly property int pad: Appearance.s.lg
    readonly property int count: row.count
    readonly property int slot: Appearance.m.switcherIcon + Appearance.m.switcherInset * 2
    readonly property int available: (root.screen ? root.screen.width : 1920) - Appearance.s.huge * 2 - root.pad * 2
    readonly property real fit: Math.min(1, root.available
        / Math.max(1, root.count * root.slot + Math.max(0, root.count - 1) * Appearance.s.xs))

    screen: Compositor.focusedScreen
    visible: root.rendered
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // No anchors: the layer shell centres the window on its screen. It is
    // the card's size and its shadow's, never the screen's.
    implicitWidth: card.width + Appearance.shadowFor(card.elevation).pad * 2
    implicitHeight: card.height + Appearance.shadowFor(card.elevation).pad * 2

    WlrLayershell.namespace: "shell-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: root.shown ? card : null }

    onShownChanged: if (root.shown) {
        root.rendered = true;
        root.named = root.current;
    }

    Connections {
        target: Switcher
        function onActiveChanged(): void {
            if (Switcher.active)
                return;
            root.glanced = false;
            root.pointerMoved = false;
            root.entered = Qt.point(-1, -1);
        }
    }

    Timer {
        running: Switcher.active && !root.glanced
        interval: Appearance.t.glance
        onTriggered: root.glanced = true
    }

    Timer {
        // A Behavior's animation never emits finished(): the unmap is a bound
        // timer, as the OSD's is.
        running: root.rendered && !root.shown
        interval: Appearance.t.switcherFade + Appearance.t.grace
        onTriggered: root.rendered = false
    }

    Timer {
        running: root.shown && root.renaming
        interval: Appearance.t.switcherFade
        onTriggered: root.named = root.current
    }

    Surface {
        id: card

        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.entry
        width: body.width + root.pad * 2
        height: body.height + root.pad * 2
        radius: Appearance.r.panel
        elevation: 3
        opacity: root.fade

        HoverHandler {
            onPointChanged: {
                const at = this.point.position;
                if (root.entered.x < 0)
                    root.entered = at;
                else if (Math.abs(at.x - root.entered.x) + Math.abs(at.y - root.entered.y) > Appearance.s.xs)
                    root.pointerMoved = true;
            }
        }

        // As wide as a popover at least, so a title has room under one or
        // two icons.
        Column {
            id: body

            x: root.pad
            y: root.pad
            width: Math.min(root.available, Math.max(entries.width, Appearance.m.popoverWidth))
            spacing: Appearance.s.md
            // Fades as one flattened image, as a popup's contents do: each
            // icon over its highlight would otherwise show through it.
            layer.enabled: card.opacity < 1

            Row {
                id: entries
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Appearance.s.xs

                Repeater {
                    id: row

                    model: ScriptModel { values: root.entries }

                    SwitcherEntry {
                        required property var modelData

                        entry: this.modelData
                        chosen: root.chosen
                        fit: root.fit
                        hoverEnabled: root.pointerMoved
                    }
                }
            }

            Label {
                // The window's own title, read off it here rather than taken
                // into the entries, where it would go stale.
                text: root.named ? (root.named.window?.title || root.named.name) : ""
                width: body.width
                horizontalAlignment: Text.AlignHCenter
                opacity: root.renaming ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: Appearance.t.switcherFade; easing.type: Appearance.t.standardEasing }
                }
            }
        }
    }
}
