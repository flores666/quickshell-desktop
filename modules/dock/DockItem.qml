pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

/*! One application in the dock: its icon in the slot every dock item has
    (see Metrics), a dot under it for each window it has open, and the slot's
    highlight while one of them has focus. */
Clickable {
    id: root

    required property var item
    required property ShellScreen screen
    /*! The glass it stands on: its highlight takes the colours that read
        on its slot there, its dots those that read on their own strip. */
    required property Surface panel
    readonly property ColorScheme dotScheme: root.panel.schemeOver(dots)

    /*! Whether one of its windows has focus; read here, not in the model. */
    readonly property bool active: root.item.windows.some(w => w?.activated ?? false)
    /*! Reported to the dock, which owns the tooltip and the preview. */
    signal hoverChanged(string key, string label, real centerX, bool entered)

    /*! How far the dock wants this icon shifted to make room for a drag. */
    property real slide: 0
    /*! Whether a drag is still in flight somewhere in the dock. */
    property bool rearranging: false
    readonly property bool dragging: dragging_.active
    /*!
        How far the icon has been carried, measured from where the drag became
        active. `activeTranslation` cannot be used for this: it counts from the
        press, so it opens a whole drag threshold wide — 15px, measured — and
        the icon would leap that far sideways the moment it is picked up.
    */
    readonly property real dragX: dragging_.centroid.scenePosition.x - root.dragOrigin
    /*! Where the pointer was when the drag became active. */
    property real dragOrigin: 0

    signal dragMoved(real dx)
    signal dragEnded

    implicitWidth: Appearance.m.dockSlot
    implicitHeight: Appearance.m.dockSlot
    // Round, so at either end of the row the highlight is concentric with the
    // dock's round edge.
    radius: Appearance.r.capsule(Appearance.m.dockSlot)
    focusable: false
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    selected: root.active
    scheme: root.panel.schemeOver(root)

    transform: Translate {
        x: root.dragging ? root.dragX : root.slide

        Behavior on x {
            // Only while a drag is in flight, and never for the icon under the
            // pointer — that one has to track the hand exactly. At the drop the
            // dock's order changes in the same frame, so every offset has to
            // vanish with it; animating them away instead leaves the icons
            // sliding out of a layout that no longer exists.
            enabled: root.rearranging && !root.dragging
            NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
        }
    }

    /*!
        Rearranging the dock. `target: null` because the icon is moved by the
        transform above, which leaves the Row's layout alone — the dock decides
        where the icon lands, and only when the drag ends.
    */
    DragHandler {
        id: dragging_

        target: null
        yAxis.enabled: false
        cursorShape: Qt.ClosedHandCursor
        onActiveChanged: {
            if (dragging_.active)
                root.dragOrigin = dragging_.centroid.scenePosition.x;
            else
                root.dragEnded();
        }
        onCentroidChanged: if (dragging_.active) root.dragMoved(root.dragX)
    }

    /*! Its middle, across the dock's window: where a tooltip, the preview
        or the menu is centred. A click is the dock's to act on (DockPanel). */
    function centerX(): real {
        const surface = root.QsWindow.contentItem;
        return surface ? root.mapToItem(surface, root.width / 2, 0).x : 0;
    }

    onMiddleClicked: Dock.launchNew(root.item)
    onRightClicked: {
        Overlay.anchorX = root.centerX();
        Overlay.openWith(Overlay.dockMenu, root.screen, root.item);
    }

    onHoveredChanged: root.hoverChanged(root.item.key, root.item.name, root.centerX(), root.hovered)

    AppIcon {
        id: icon
        x: Appearance.m.dockInset
        y: Appearance.m.dockInset
        source: root.item.icon
        size: Appearance.m.dockIcon
        optical: true
        scale: root.down ? 0.9 : root.hovered ? 1.06 : 1

        Behavior on scale {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }
    }

    // A dot for each window, three at most, just under the slot. Which
    // application has focus is the highlight's to say, so the dots only ever
    // count. Each comes and goes with its window, in a place of its own with
    // half the gap either side, so the row stays centred while one grows.
    // They stand in a strip as wide as the slot, the gap above them repeated
    // below: what their colours are read against.
    Item {
        id: dots

        y: root.height
        width: root.width
        height: Appearance.m.dockDotGap * 2 + Appearance.m.dockDot

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Appearance.m.dockDotGap

            Repeater {
                model: 3

                Item {
                    id: dot

                    required property int index
                    property real presence: dot.index < root.item.windows.length ? 1 : 0

                    Behavior on presence {
                        NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
                    }

                    width: (Appearance.m.dockDot + Appearance.s.xs) * dot.presence
                    height: Appearance.m.dockDot

                    Rectangle {
                        anchors.centerIn: parent
                        width: Appearance.m.dockDot
                        height: Appearance.m.dockDot
                        radius: Appearance.m.dockDot / 2
                        color: root.dotScheme.text
                        opacity: dot.presence
                        scale: dot.presence
                    }
                }
            }
        }
    }
}
