pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

FocusScope {
    id: root

    required property string category
    signal selected(string key)

    implicitWidth: Appearance.m.fieldWidth
    implicitHeight: search.height + list.anchors.topMargin + root.shownRows * Appearance.m.navRowHeight
        + Math.max(0, root.shownRows - 1) * list.spacing

    readonly property string query: search.text.trim().toLowerCase()
    readonly property var matches: DailyNotes.categories.filter(
        key => key.toLowerCase().includes(root.query))
    readonly property int shownRows: Math.min(root.matches.length, Appearance.m.dailyNotesCategoryRows)

    onQueryChanged: {
        list.currentIndex = 0;
        list.positionViewAtBeginning();
    }

    function selectCurrent(): void {
        const key = root.matches[list.currentIndex];
        if (key !== undefined)
            root.selected(key);
    }

    function submitSearch(): void {
        if (root.query === "") {
            root.selectCurrent();
            return;
        }
        const key = DailyNotes.addCategory(search.text);
        if (key !== null)
            root.selected(key);
    }

    InputField {
        id: search
        objectName: "noteCategorySearch"
        width: parent.width
        placeholder: qsTr("Find or create a category…")
        placeholderColor: Appearance.c.textMuted
        input.focus: true
        input.KeyNavigation.tab: list.count > 0 ? list : search.input
        input.KeyNavigation.backtab: list.count > 0 ? list : search.input
        input.Accessible.name: qsTr("Find or create a category")
        input.Accessible.description: qsTr("Press Enter to use this name as the category.")
        onAccepted: root.submitSearch()
    }

    ListView {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: search.bottom
        anchors.topMargin: root.shownRows > 0 ? Appearance.s.xs : 0
        anchors.bottom: parent.bottom
        spacing: Appearance.s.xxs
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true
        KeyNavigation.tab: search.input
        KeyNavigation.backtab: search.input
        Accessible.role: Accessible.List
        Accessible.name: qsTr("Categories")
        Keys.onReturnPressed: root.selectCurrent()
        Keys.onEnterPressed: root.selectCurrent()

        model: ScriptModel { values: root.matches }
        delegate: MenuRow {
            required property int index
            required property string modelData

            width: list.width - scroll.footprint
            implicitHeight: Appearance.m.navRowHeight
            focusable: false
            // ListView can give its current delegate the keyboard.
            KeyNavigation.tab: search.input
            KeyNavigation.backtab: search.input
            title: this.modelData
            selected: list.activeFocus ? list.currentIndex === this.index : root.category === this.modelData
            Accessible.role: Accessible.ListItem
            Accessible.name: title
            onClicked: root.selected(this.modelData)
        }
    }

    ThinScrollBar { id: scroll; flickable: list }
}
