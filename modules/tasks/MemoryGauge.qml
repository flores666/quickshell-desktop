pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

/*!
    How much of memory or swap is left, as a bar that empties, with a mark
    across it at each level earlyoom acts at: past the first the bar is in
    the danger colour.
*/
Column {
    id: root

    property string title: ""
    /*! What is left, in percent. */
    property real percent: 0
    property string detail: ""
    /*! Levels in percent, the first the one earlyoom starts at. */
    property var marks: []

    spacing: Appearance.s.xs

    Item {
        width: root.width
        height: heading.implicitHeight

        Label {
            id: heading
            text: root.title
            font.weight: Font.Medium
        }

        Label {
            anchors.right: parent.right
            anchors.verticalCenter: heading.verticalCenter
            text: qsTr("%1% left").arg(Math.round(root.percent))
            role: Label.Role.Small
            muted: true
            font.features: { "tnum": 1 }
        }
    }

    Item {
        width: root.width
        height: Appearance.m.gaugeHeight

        Rectangle {
            anchors.fill: parent
            radius: Appearance.r.capsule(height)
            color: Appearance.c.sunken
        }

        Rectangle {
            width: Math.max(height, parent.width * Math.min(100, root.percent) / 100)
            height: parent.height
            radius: Appearance.r.capsule(height)
            color: root.marks.length > 0 && root.percent <= root.marks[0] ? Appearance.c.danger : Appearance.c.accent

            Behavior on width {
                NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.standardEasing }
            }
        }

        Repeater {
            model: root.marks

            Rectangle {
                required property real modelData

                x: parent.width * this.modelData / 100 - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: Appearance.m.gaugeMark
                height: parent.height + Appearance.s.sm
                radius: width / 2
                color: Appearance.c.text
            }
        }
    }

    Label {
        width: root.width
        visible: root.detail !== ""
        text: root.detail
        role: Label.Role.Small
        muted: true
        wrapMode: Text.Wrap
    }
}
