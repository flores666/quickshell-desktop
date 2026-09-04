pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    A month view.

    Written directly against the locale's first day of week and day names rather
    than a controls calendar, so it inherits the shell's typography and states
    with no styling fight.
*/
Item {
    id: root

    /*! First of the displayed month. */
    property date shownMonth: new Date(Time.now.getFullYear(), Time.now.getMonth(), 1)

    readonly property var locale: Qt.locale()
    readonly property int firstDay: root.locale.firstDayOfWeek
    readonly property date today: Time.now

    readonly property date gridStart: {
        const first = new Date(root.shownMonth.getFullYear(), root.shownMonth.getMonth(), 1);
        const shift = (first.getDay() - root.firstDay + 7) % 7;
        return new Date(first.getFullYear(), first.getMonth(), 1 - shift);
    }

    implicitWidth: 280
    implicitHeight: head.height + Appearance.s.md + weekdays.height + grid.height

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate();
    }

    function shift(months: int): void {
        root.shownMonth = new Date(root.shownMonth.getFullYear(),
            root.shownMonth.getMonth() + months, 1);
    }

    Item {
        id: head
        width: parent.width
        height: 32

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.locale.standaloneMonthName(root.shownMonth.getMonth(), Locale.LongFormat)
                + " " + root.shownMonth.getFullYear()
            role: Label.Role.Subtitle
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            IconButton {
                icon: "chevron-left"
                size: 28
                iconSize: Appearance.m.iconSm
                onClicked: root.shift(-1)
            }

            IconButton {
                icon: "calendar"
                size: 28
                iconSize: Appearance.m.iconSm
                enabled: root.shownMonth.getMonth() !== root.today.getMonth()
                    || root.shownMonth.getFullYear() !== root.today.getFullYear()
                onClicked: root.shownMonth = new Date(root.today.getFullYear(),
                    root.today.getMonth(), 1)
            }

            IconButton {
                icon: "chevron-right"
                size: 28
                iconSize: Appearance.m.iconSm
                onClicked: root.shift(1)
            }
        }
    }

    Row {
        id: weekdays
        y: head.height + Appearance.s.md
        width: parent.width
        height: 22

        Repeater {
            model: 7

            Label {
                required property int index

                width: root.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: root.locale.dayName((root.firstDay + index) % 7, Locale.NarrowFormat)
                role: Label.Role.Caption
                faint: true
            }
        }
    }

    Grid {
        id: grid
        y: weekdays.y + weekdays.height
        width: parent.width
        columns: 7
        rows: 6

        Repeater {
            model: 42

            Item {
                id: cell
                required property int index

                readonly property date day: new Date(root.gridStart.getFullYear(),
                    root.gridStart.getMonth(), root.gridStart.getDate() + cell.index)
                readonly property bool inMonth: cell.day.getMonth() === root.shownMonth.getMonth()
                readonly property bool isToday: root.sameDay(cell.day, root.today)

                width: root.width / 7
                height: 30

                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    radius: 13
                    visible: cell.isToday
                    color: Appearance.c.accent
                }

                Label {
                    anchors.centerIn: parent
                    text: cell.day.getDate()
                    role: Label.Role.Small
                    color: cell.isToday ? Appearance.c.accentText
                        : cell.inMonth ? Appearance.c.text : Appearance.c.textFaint
                    font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                }
            }
        }
    }
}
