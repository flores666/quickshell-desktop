pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The date menu's CPU and memory, side by side: a figure and the last
    minute of each, which Usage keeps whether or not anything shows it. A
    click opens the task manager on its Performance tab, as a flight from the
    date menu.
*/
Item {
    id: root

    /*! The two cards: the processor, and memory as RAM, as the Performance
        tab names it — "Memory" read as the disk as well. */
    readonly property var cards: [
        { title: qsTr("CPU"), memory: false },
        { title: qsTr("RAM"), memory: true }
    ]
    readonly property string cpuFigure: root.figureOf(Usage.cpu)
    readonly property string memoryFigure: root.figureOf(Usage.memory)

    /*! Title, figure and a chart tall enough to read, on StatCard's padding. */
    implicitHeight: Appearance.s.lg * 2 + Appearance.font.small * 1.5 + Appearance.font.subtitle * 1.5
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

    Row {
        anchors.fill: parent
        spacing: Appearance.s.md

        Repeater {
            model: root.cards

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
