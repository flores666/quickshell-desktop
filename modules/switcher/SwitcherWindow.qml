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
*/
PanelWindow {
    id: root

    property bool glanced: false
    readonly property bool shown: Switcher.active && root.glanced
    property bool rendered: false
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

    onShownChanged: if (root.shown) root.rendered = true

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
        interval: Appearance.t.base
        onTriggered: root.rendered = false
    }

    Surface {
        id: card

        anchors.centerIn: parent
        width: body.width + root.pad * 2
        height: body.height + root.pad * 2
        radius: Appearance.r.panel
        elevation: 3
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96

        Behavior on opacity {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }
        Behavior on scale {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }

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

            Row {
                id: entries
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Appearance.s.xs

                Repeater {
                    id: row

                    model: ScriptModel { values: Switcher.entries }

                    SwitcherEntry {
                        required property var modelData

                        entry: this.modelData
                        fit: root.fit
                        hoverEnabled: root.pointerMoved
                    }
                }
            }

            Label {
                // The window's own title, read off it here rather than taken
                // into the entries, where it would go stale.
                text: Switcher.current ? (Switcher.current.window.title || Switcher.current.name) : ""
                width: body.width
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
