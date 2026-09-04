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
    property bool pressEnabled: true
    /*! Set false for items inside a list that manages keyboard focus itself. */
    property bool focusable: true
    /*! Suppress the built-in state layer when the caller paints its own. */
    property bool showStateLayer: true

    property alias containsMouse: mouse.containsMouse
    property alias acceptedButtons: mouse.acceptedButtons
    property alias cursorShape: mouse.cursorShape

    readonly property bool hovered: root.enabled && root.hoverEnabled && mouse.containsMouse
    readonly property bool down: root.enabled && root.pressEnabled && mouse.pressed && mouse.containsMouse
    readonly property bool focusVisible: root.enabled && root.focusable
        && root.activeFocus && InputMode.keyboard

    signal clicked(var event)
    signal rightClicked(var event)
    signal middleClicked(var event)

    activeFocusOnTab: root.focusable && root.enabled
    opacity: root.enabled ? 1 : 0.42

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
        color: root.down ? Appearance.c.pressLayer
            : root.hovered ? Appearance.c.hoverLayer
            : root.selected ? Appearance.c.selectLayer
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

        onPressed: {
            InputMode.pointerUsed();
            if (root.focusable)
                root.forceActiveFocus(Qt.MouseFocusReason);
        }

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
        }
    }

    // Focus ring, drawn outside the shape so it never crops the content.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: root.radius > 0 ? root.radius + 2 : 0
        color: "transparent"
        border.width: 2
        border.color: Appearance.c.accent
        visible: root.focusVisible
    }
}
