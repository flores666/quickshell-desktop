pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "root:/config"
import "root:/components"

FocusScope {
    id: root

    required property string time
    property bool selectionReady: false
    signal selected(string time)

    implicitWidth: Appearance.m.menuWidth
    implicitHeight: controls.implicitHeight

    function choose(): void {
        if (root.selectionReady)
            root.selected(root.twoDigits(hours.list.currentIndex) + ":" + root.twoDigits(minutes.list.currentIndex));
    }

    Component.onCompleted: {
        hours.list.currentIndex = root.time ? Number(root.time.slice(0, 2)) : 23;
        minutes.list.currentIndex = root.time ? Number(root.time.slice(3)) : 59;
        hours.list.positionViewAtIndex(hours.list.currentIndex, ListView.Contain);
        minutes.list.positionViewAtIndex(minutes.list.currentIndex, ListView.Contain);
        root.selectionReady = true;
    }

    function twoDigits(part: int): string {
        return String(part).padStart(2, "0");
    }

    RowLayout {
        id: controls
        anchors.fill: parent
        spacing: Appearance.s.xs

        TimeColumn {
            id: hours
            objectName: "noteHourList"
            label: qsTr("Hour")
            partCount: 24
            otherList: minutes.list
            list.focus: true
        }

        TimeColumn {
            id: minutes
            objectName: "noteMinuteList"
            label: qsTr("Minute")
            partCount: 60
            otherList: hours.list
        }
    }

    component TimeColumn: ColumnLayout {
        id: column

        required property string label
        required property int partCount
        required property Item otherList
        readonly property alias list: list

        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Appearance.s.xxs

        Label {
            text: column.label
            role: Label.Role.Small
            muted: true
            Layout.alignment: Qt.AlignHCenter
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Appearance.m.dailyNotesTimeRows * Appearance.m.compactButton

            ListView {
                id: list

                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                activeFocusOnTab: true
                keyNavigationEnabled: true
                KeyNavigation.tab: column.otherList
                KeyNavigation.backtab: column.otherList
                Accessible.role: Accessible.List
                Accessible.name: column.label
                model: column.partCount
                onCurrentIndexChanged: root.choose()
                Keys.onReturnPressed: root.choose()
                Keys.onEnterPressed: root.choose()

                delegate: Clickable {
                    id: option

                    required property int index

                    width: list.width - scroll.footprint
                    height: Appearance.m.compactButton
                    selected: option.index === list.currentIndex
                    focusable: list.activeFocus && option.selected
                    KeyNavigation.tab: column.otherList
                    KeyNavigation.backtab: column.otherList
                    Accessible.role: Accessible.ListItem
                    Accessible.name: valueLabel.text
                    Accessible.selected: option.selected
                    onClicked: {
                        if (option.selected)
                            root.choose();
                        else
                            list.currentIndex = option.index;
                        list.forceActiveFocus();
                    }

                    Label {
                        id: valueLabel
                        anchors.centerIn: parent
                        text: root.twoDigits(option.index)
                        role: Label.Role.Small
                    }
                }
            }

            ThinScrollBar { id: scroll; flickable: list }
        }
    }
}
