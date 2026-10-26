pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    One of earlyoom's levels: a name, the percentage, and a slider over
    `min`–`max` in whole percents. It only says what was moved to; whoever
    holds the levels keeps them in order.
*/
Item {
    id: root

    required property string label
    required property real value
    property int min: 1
    property int max: 50

    signal moved(int value)

    implicitWidth: Appearance.m.popoverWidth
    implicitHeight: title.implicitHeight + slider.implicitHeight + Appearance.s.xxs

    Label {
        id: title
        text: root.label
        role: Label.Role.Small
    }

    Label {
        anchors.right: parent.right
        anchors.verticalCenter: title.verticalCenter
        text: qsTr("%1%").arg(root.value)
        role: Label.Role.Small
        muted: true
        font.features: { "tnum": 1 }
    }

    Slider {
        id: slider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        value: (root.value - root.min) / (root.max - root.min)
        stepSize: 1 / (root.max - root.min)
        onMoved: fraction => {
            const stepped = Math.round(root.min + fraction * (root.max - root.min));
            if (stepped !== root.value)
                root.moved(stepped);
        }
    }
}
