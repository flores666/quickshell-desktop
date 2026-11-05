pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/services"

/*!
    The interaction primitive every button, row and tile in the shell is built
    from.

    It owns one consistent implementation of the five interaction states the
    design system requires — hover, pressed, selected, disabled and keyboard
    focus — so no widget has to reinvent them.  Visual content goes in as
    children; the state layer paints beneath it and the focus ring above.
*/
Item {
    id: root

    property int radius: Appearance.r.sm
    /*! Painted underneath the state layer. Transparent by default. */
    property color background: "transparent"
    /*! Persistent "this one is active" state, e.g. a selected list row. */
    property bool selected: false
    property bool hoverEnabled: true
    /*! Dwell before hover effects; pointer entry and presses stay immediate. */
    property int hoverDelay: 0
    property bool pressEnabled: true
    /*! Set false for items inside a list that manages keyboard focus itself. */
    property bool focusable: true
    /*! Suppress the built-in state layer when the caller paints its own. */
    property bool showStateLayer: true
    /*! A drag control may put its ring around its moving knob. */
    property Item focusRingTarget: root
    property real focusRingRadius: root.radius
    property real focusRingGap: Appearance.m.focusRing
    /*! The colours its state layer and focus ring are drawn in: the theme's,
        unless it stands on thinned glass over a wallpaper that wants the
        other theme's (Surface.schemeOver). */
    property ColorScheme scheme: Appearance.c

    property alias containsMouse: mouse.containsMouse
    property alias acceptedButtons: mouse.acceptedButtons
    property alias cursorShape: mouse.cursorShape
    /*! Keep the press even inside a Flickable, which would otherwise steal it. */
    property alias preventStealing: mouse.preventStealing

    readonly property bool pointerOver: root.enabled && root.hoverEnabled && mouse.containsMouse
    readonly property bool hovered: root.pointerOver && (root.hoverDelay <= 0 || root.hoverReady)
    property bool hoverReady: false
    readonly property bool pressed: root.enabled && root.pressEnabled && mouse.pressed
    readonly property bool down: root.pressed && mouse.containsMouse
    readonly property bool focusVisible: root.enabled && root.focusable
        && root.activeFocus && InputMode.keyboard

    signal clicked(var event)
    signal rightClicked(var event)
    signal middleClicked(var event)
    /*! Drag/value mapping belongs to the control; interaction state stays here. */
    signal pointerPressed(var event)
    signal pointerMoved(var event)
    signal pointerReleased(var event)

    onPointerOverChanged: root.hoverReady = false
    onHoverDelayChanged: root.hoverReady = false

    Timer {
        interval: root.hoverDelay
        running: root.pointerOver && root.hoverDelay > 0 && !root.hoverReady
        onTriggered: root.hoverReady = true
    }

    // Qt refuses to clear activeFocusOnTab on the active item. Relinquish
    // focus first when a control stops accepting keyboard interaction.
    activeFocusOnTab: root.activeFocus || (root.focusable && root.enabled)
    onFocusableChanged: if (!root.focusable) root.focus = false
    opacity: root.enabled ? 1 : Appearance.m.disabledOpacity

    Behavior on opacity {
        NumberAnimation { duration: Appearance.t.fast; easing.type: Appearance.t.standardEasing }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.background
        visible: root.background.a > 0
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.showStateLayer
        color: root.down ? root.scheme.pressLayer
            : root.hovered ? root.scheme.hoverLayer
            : root.selected ? root.scheme.selectLayer
            : "transparent"

        Behavior on color {
            ColorAnimation { duration: Appearance.t.instant; easing.type: Appearance.t.standardEasing }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: root.hoverEnabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onPressed: event => {
            InputMode.pointerUsed();
            if (root.focusable)
                root.forceActiveFocus(Qt.MouseFocusReason);
            root.pointerPressed(event);
        }
        onPositionChanged: event => root.pointerMoved(event)
        onReleased: event => root.pointerReleased(event)

        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.rightClicked(event);
            else if (event.button === Qt.MiddleButton)
                root.middleClicked(event);
            else
                root.clicked(event);
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            InputMode.keyboardUsed();
            root.clicked(null);
            event.accepted = true;
        } else if (event.key === Qt.Key_Menu
                || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
            // The keyboard's right click, so nothing is reachable by pointer alone.
            InputMode.keyboardUsed();
            root.rightClicked(null);
            event.accepted = true;
        }
    }

    // Focus ring, drawn outside the shape so it never crops the content.
    Rectangle {
        anchors.fill: root.focusRingTarget
        anchors.margins: -root.focusRingGap
        radius: root.focusRingRadius > 0 ? root.focusRingRadius + root.focusRingGap : 0
        color: "transparent"
        border.width: Appearance.m.focusRing
        border.color: root.scheme.accent
        visible: root.focusVisible
    }
}
