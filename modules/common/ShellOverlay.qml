pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The shared chrome for every shell popup: launcher, quick settings, the date
    menu and the two popup menus.

    The window is the size of the popup and nothing more. Dismissal comes from
    the compositor's focus grab, so a click outside lands on whatever is under
    it — the application still gets that click, hover keeps working everywhere,
    and the desktop is never covered by an invisible catcher.

    One instance exists per popup, not per screen; it follows Overlay.screen,
    which is set to the focused monitor when the popup opens.
*/
PanelWindow {
    id: root

    enum Placement { BelowBar, AboveDock, Centre }

    required property string overlayId
    property int placement: ShellOverlay.Placement.BelowBar
    /*! Size of the visible card. The window adds room for its shadow. */
    property int cardWidth: Appearance.m.popoverWidth
    property int cardHeight: 200
    property int elevation: 3
    property int cardRadius: Appearance.r.lg
    /*! What takes the keyboard when the popup opens. */
    property Item initialFocusItem: null

    default property alias content: body.data

    readonly property bool shown: Overlay.isOpen(root.overlayId)
    /*! Stays true through the closing animation so the popup can fade out. */
    property bool rendered: false
    /*! Room for the shadow to spread outside the card. */
    readonly property int pad: Appearance.shadowFor(root.elevation).blur + Appearance.s.md

    /*!
        Keys the popup did not handle itself. Escape is consumed here; anything
        else is offered to the popup, which owns its own navigation.
    */
    signal keyPressed(var event)

    screen: Overlay.screen
    visible: root.rendered
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: root.cardWidth + root.pad * 2
    implicitHeight: root.cardHeight + root.pad * 2

    anchors {
        left: true
        top: root.placement !== ShellOverlay.Placement.AboveDock
        bottom: root.placement === ShellOverlay.Placement.AboveDock
    }

    margins {
        left: {
            const screenWidth = root.screen ? root.screen.width : 1920;
            const centre = root.placement === ShellOverlay.Placement.Centre
                ? screenWidth / 2 : Overlay.anchorX;
            const edge = Appearance.s.md - root.pad;
            return Math.round(Math.max(edge,
                Math.min(screenWidth - root.width - edge, centre - root.width / 2)));
        }
        top: root.placement === ShellOverlay.Placement.Centre
            ? Math.round((root.screen ? root.screen.height : 1080) * 0.07) - root.pad
            : Appearance.m.barHeight + Appearance.s.md - root.pad
        bottom: Appearance.m.dockFootprint + Appearance.s.md - root.pad
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shell-" + root.overlayId
    /*!
        On-demand, never exclusive: an exclusive layer surface in Hyprland takes
        the pointer as well as the keyboard, which would stop clicks reaching
        the application underneath. On-demand still gives the popup the keyboard
        it needs for typing and Escape.
    */
    WlrLayershell.keyboardFocus: root.shown
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    /*!
        Input lands on the card and nowhere else — not even on the shadow around
        it, which is only paint.
    */
    mask: Region { item: root.shown ? card : null }

    /*!
        Dismissal on an outside click.

        Nothing here captures input. Hyprland reports every pointer press through
        a non-consuming bind (see hyprland.conf), and Overlay decides: the press
        closes the popup unless the pointer is over one of the shell's own
        surfaces. The click itself is delivered to whatever is underneath either
        way, and hover out there is never interrupted.
    */
    onShownChanged: if (!root.shown) Overlay.setPointerOver("popup", false)

    // Connected explicitly rather than through an `onShownChanged` handler on the
    // root, because several popups declare one of their own and a handler in a
    // derived component replaces the base component's.
    Connections {
        target: root

        function onShownChanged(): void {
            if (root.shown) {
                root.rendered = true;
                Qt.callLater(() => (root.initialFocusItem ?? card).forceActiveFocus());
            }
        }
    }

    Timer {
        // Unmaps the surface once the fade-out has played. This cannot hang off
        // the animation itself: an animation driven by a Behavior never emits
        // finished(). `running` is a plain binding, so the surface is unmapped
        // even if the property changes while no handler is watching.
        running: root.rendered && !root.shown
        interval: Appearance.t.fast + 60
        onTriggered: root.rendered = false
    }

    Surface {
        id: card

        x: root.pad
        y: root.pad + (root.shown ? 0 : -Appearance.s.md)
        width: root.cardWidth
        height: root.cardHeight
        radius: root.cardRadius
        elevation: root.elevation
        opacity: root.shown ? 1 : 0

        Behavior on y {
            NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
        }
        Behavior on opacity {
            NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
        }

        HoverHandler {
            id: pointer
            onHoveredChanged: Overlay.setPointerOver("popup", pointer.hovered && root.shown)
        }

        Item {
            id: body
            anchors.fill: parent
        }

        Keys.onPressed: event => {
            InputMode.keyboardUsed();
            if (event.key === Qt.Key_Escape) {
                Overlay.close();
                event.accepted = true;
                return;
            }
            root.keyPressed(event);
        }
    }
}
