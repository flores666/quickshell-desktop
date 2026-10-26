pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The date menu's CPU and memory, side by side: a figure and the last
    minute of each. A click opens the task manager on its Performance tab, as
    a flight from the date menu.

    Sampling runs while `tracking`, which the date menu binds to its being
    shown, so nothing is read while it is closed.
*/
Item {
    id: root

    property bool tracking: false

    readonly property string cpuFigure: root.figureOf(Usage.cpu)
    readonly property string memoryFigure: root.figureOf(Usage.memory)

    /*! Title, figure and a chart tall enough to read, on the card's padding. */
    implicitHeight: Appearance.s.md * 2 + Appearance.font.small * 1.5 + Appearance.font.subtitle * 1.5
        + Appearance.s.xs + Appearance.m.usageChart

    function figureOf(value: real): string {
        return value < 0 ? "–" : Math.round(value) + "%";
    }

    /*! The task manager's Performance tab, flown to from the date menu. Its
        card is centred, so where it is anchored only keeps the record true. */
    function openPerformance(): void {
        Overlay.openWith(Overlay.taskManager, Overlay.screen, root.mapToItem(null, root.width / 2, 0).x,
            { tab: "performance" });
    }

    onTrackingChanged: Processes.watch("dateMenu", root.tracking)
    Component.onDestruction: Processes.watch("dateMenu", false)

    Row {
        anchors.fill: parent
        spacing: Appearance.s.md

        Repeater {
            model: [
                { title: qsTr("CPU"), memory: false },
                { title: qsTr("Memory"), memory: true }
            ]

            Clickable {
                id: card

                required property var modelData

                width: (root.width - Appearance.s.md) / 2
                height: parent.height
                radius: Appearance.r.lg
                onClicked: root.openPerformance()

                StatCard {
                    anchors.fill: parent
                    title: card.modelData.title
                    figure: card.modelData.memory ? root.memoryFigure : root.cpuFigure
                    series: [{
                        points: card.modelData.memory ? Usage.history.memory : Usage.history.cpu,
                        color: card.modelData.memory ? Appearance.c.seriesMemory : Appearance.c.seriesCpu
                    }]
                    now: Usage.now
                    span: Usage.span
                }
            }
        }
    }
}
