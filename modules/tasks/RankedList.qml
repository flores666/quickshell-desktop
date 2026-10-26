pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"

/*!
    The processes that used an entity tab's thing most (`entries`, as
    `Activity.top` gives them), under a heading in SettingGroup's style: a
    row each (BusyRow), on a card that keeps its room for `most` whether or
    not that many are listed, so what is above it does not change size as
    processes come and go. With none, a muted line says so (`empty`) — once
    there could be one (`ready`), not before the first readings are in.

    The rows are kept by pid, each reading its entry as it stands.
*/
Column {
    id: root

    property string title: ""
    property var entries: []
    property var format: v => String(v)
    property string empty: ""
    property bool ready: true
    property int most: 5

    spacing: Appearance.s.sm

    Label {
        text: root.title
        role: Label.Role.Small
        font.weight: Font.DemiBold
        muted: true
        leftPadding: Appearance.s.xxs
    }

    Card {
        id: card

        width: root.width
        height: Appearance.m.touchTarget * root.most + Appearance.s.sm * 2

        Column {
            id: rows
            x: card.padding
            y: Appearance.s.sm
            width: card.width - card.padding * 2

            Repeater {
                model: ScriptModel { values: root.entries.map(e => e.pid) }

                BusyRow {
                    required property int modelData

                    width: rows.width
                    entry: root.entries.find(e => e.pid === this.modelData) ?? null
                    format: root.format
                }
            }
        }

        Label {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, card.width - card.padding * 2)
            visible: root.ready && root.entries.length === 0
            text: root.empty
            role: Label.Role.Small
            muted: true
        }
    }
}
