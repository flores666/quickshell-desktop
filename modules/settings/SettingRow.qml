pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    One numeric preference: a name, a slider, the value it currently has, and a
    way back to the value it shipped with.

    The row knows nothing about which setting it is beyond the key it is given.
    Its range comes from whoever owns the value — `Tuning.spec` for the layout
    keys, the calling section for a timing — so a row can never offer a value
    the owner would clamp away.

    The reset control is only there when there is something to undo, which is
    also how the row shows that a setting has been changed at all.
*/
Item {
    id: root

    required property string key
    required property string label
    required property int min
    required property int max
    /*! What the setting resolves to right now, override or default. */
    required property int value
    property string suffix: qsTr("px")
    /*! Whole steps: an integer knob is what keeps a live drag from asking the
        compositor to relayout on every frame of it. */
    property int step: 1

    readonly property bool overridden: Settings.isOverridden(root.key)

    implicitWidth: Appearance.m.popoverWidth
    implicitHeight: text.implicitHeight + slider.implicitHeight + Appearance.s.xxs

    Label {
        id: text
        anchors.left: parent.left
        anchors.top: parent.top
        text: root.label
        role: Label.Role.Small
    }

    IconButton {
        id: reset
        anchors.right: parent.right
        anchors.verticalCenter: text.verticalCenter
        visible: root.overridden
        icon: "refresh"
        iconSize: Appearance.m.iconSm
        size: 22
        iconColor: Appearance.c.textMuted
        onClicked: Settings.setOverride(root.key, -1)
    }

    Label {
        anchors.right: reset.visible ? reset.left : parent.right
        anchors.rightMargin: reset.visible ? Appearance.s.xs : 0
        anchors.verticalCenter: text.verticalCenter
        text: root.suffix === "" ? root.value : qsTr("%1 %2").arg(root.value).arg(root.suffix)
        role: Label.Role.Small
        muted: !root.overridden
    }

    Slider {
        id: slider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        value: (root.value - root.min) / Math.max(1, root.max - root.min)
        stepSize: root.step / Math.max(1, root.max - root.min)
        onMoved: fraction => {
            const stepped = Math.round(root.min + fraction * (root.max - root.min));
            if (stepped !== root.value)
                Settings.setOverride(root.key, stepped);
        }
    }
}
