pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"

/*!
    The application launcher: categories down the left, search above a grid
    of what is installed, and the grid's pages marked along the bottom.

    The search field keeps keyboard focus the whole time and forwards navigation
    keys to the grid, so typing and moving the selection never fight over focus.
    A search looks through everything: typing returns the sidebar to All Apps
    rather than quietly searching one category of them.
*/
ShellOverlay {
    id: root

    overlayId: Overlay.launcher
    placement: ShellOverlay.Placement.Centre
    cardWidth: Math.min(940, (root.screen ? root.screen.width : 1920) - Appearance.s.huge * 2)
    cardHeight: Math.min(600, (root.screen ? root.screen.height : 1080) - Appearance.s.huge * 3)
    initialFocusItem: search.input

    readonly property int navWidth: 200
    /*! The key of the category shown; "" is All Apps. */
    property string category: ""
    readonly property var categories: [{ key: "", title: qsTr("All Apps"), icon: "apps" }]
        .concat(Apps.categories)
    readonly property var results: Apps.search(search.text)
        .filter(e => Apps.inCategory(e, root.category))
    /*!
        Which tile is selected: the one the highlight sits on and the one Enter
        launches.

        Deliberately not the grid's own `currentIndex`. A GridView scrolls to
        keep its current item in view, so writing the hovered tile there fed
        back on itself — hovering the half-row at the bottom edge scrolled it
        into view, which put the next half-row under the pointer, which scrolled
        again. Measured as a runaway from contentY 82 to 1026 in one sweep of
        the pointer. The view scrolls only when the wheel, a page dot or
        `navigate()` moves it.
    */
    property int selectedIndex: 0

    onShownChanged: {
        if (root.shown) {
            search.clear();
            root.category = "";
            root.restart();
        }
    }

    function restart(): void {
        root.selectedIndex = 0;
        grid.positionViewAtBeginning();
    }

    function launchCurrent(): void {
        const entry = root.results[root.selectedIndex];
        if (!entry)
            return;
        Overlay.close();
        Apps.launch(entry);
    }

    Item {
        anchors.fill: parent

        Column {
            id: nav

            x: Appearance.s.md
            y: Appearance.s.md
            width: root.navWidth - Appearance.s.md * 2
            spacing: Appearance.s.xxs

            Repeater {
                model: root.categories

                MenuRow {
                    required property var modelData

                    width: nav.width
                    implicitWidth: nav.width
                    implicitHeight: Appearance.m.navRowHeight
                    spacing: Appearance.s.md
                    icon: this.modelData.icon
                    title: this.modelData.title
                    selected: root.category === this.modelData.key
                    // The search field keeps the keyboard; a category is a
                    // click, and typing carries on where it was.
                    focusable: false
                    onClicked: {
                        root.category = this.modelData.key;
                        search.clear();
                        root.restart();
                    }
                }
            }
        }

        Divider {
            id: spine
            x: root.navWidth
            height: parent.height
            vertical: true
        }

        SearchField {
            id: search

            anchors.top: parent.top
            anchors.topMargin: Appearance.s.lg
            x: spine.x + Appearance.s.xl
            width: parent.width - x - Appearance.s.xl
            placeholder: qsTr("Search applications…")

            onTextChanged: {
                if (search.text !== "")
                    root.category = "";
                root.restart();
            }
            onAccepted: root.launchCurrent()
            onEscaped: Overlay.close()
            onNavigate: key => grid.navigate(key)
            onMenuRequested: {
                grid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
                (grid.itemAtIndex(root.selectedIndex) as AppTile)?.openMenu();
            }
        }

        GridView {
            id: grid

            /*! Whole rows only, so a page is exactly what one dot stands for. */
            readonly property int rows: Math.max(1, Math.floor(
                (parent.height - search.height - dots.height - Appearance.s.lg * 4) / grid.cellHeight))
            readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
            /*! How far the grid can scroll, and so where its last page begins. */
            readonly property real reach: Math.max(0, grid.contentHeight - grid.height)
            readonly property int pages: Math.max(1, Math.ceil(Math.ceil(grid.count / grid.columns) / grid.rows))
            readonly property int page: grid.reach > 0 && grid.contentY - grid.originY >= grid.reach - 1
                ? grid.pages - 1 : Math.round((grid.contentY - grid.originY) / grid.height)

            anchors.top: search.bottom
            anchors.topMargin: Appearance.s.lg
            x: spine.x + Appearance.s.md
            width: parent.width - x - Appearance.s.md
            height: grid.rows * grid.cellHeight
            clip: true
            model: root.results
            cellWidth: Math.floor((width - 1) / Math.max(1, Math.floor(width / 112)))
            cellHeight: 112
            boundsBehavior: Flickable.StopAtBounds

            function navigate(key: int): void {
                const n = grid.count;
                if (n === 0)
                    return;
                let i = root.selectedIndex;
                switch (key) {
                case Qt.Key_Down: i += grid.columns; break;
                case Qt.Key_Up: i -= grid.columns; break;
                case Qt.Key_Tab: i += 1; break;
                case Qt.Key_Backtab: i -= 1; break;
                case Qt.Key_PageDown: i += grid.columns * grid.rows; break;
                case Qt.Key_PageUp: i -= grid.columns * grid.rows; break;
                default: return;
                }
                root.selectedIndex = Math.max(0, Math.min(n - 1, i));
                grid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
            }

            function turnTo(page: int): void {
                turn.to = grid.originY + Math.min(grid.reach, page * grid.height);
                turn.restart();
            }

            NumberAnimation {
                id: turn
                target: grid
                property: "contentY"
                duration: Appearance.t.resize
                easing.type: Appearance.t.resizeEasing
            }

            /*!
                Swallows every press that does not land on a tile — the ragged
                end of the last row, mostly. A tile holds its own press
                (`preventStealing`); without this the gaps between them are
                still enough for the Flickable to turn a click with a few pixels
                of movement in it into a scroll. The wheel, the keys and the
                page dots are what move the grid.
            */
            MouseArea {
                z: -1
                width: grid.contentWidth
                height: grid.contentHeight
                preventStealing: true
            }

            delegate: AppTile {
                required property var modelData
                required property int index

                width: grid.cellWidth
                height: grid.cellHeight
                entry: this.modelData
                current: root.selectedIndex === this.index

                onClicked: {
                    Overlay.close();
                    Apps.launch(this.modelData);
                }
                onHoveredChanged: if (this.hovered) root.selectedIndex = this.index
            }
        }

        // The grid's pages, in the shape the bar gives its workspaces: a dot
        // each, the one in view drawn out into a pill.
        Row {
            id: dots

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Appearance.s.lg
            anchors.horizontalCenter: grid.horizontalCenter
            height: 16
            spacing: Appearance.s.xxs
            visible: grid.pages > 1

            Repeater {
                model: grid.pages

                Clickable {
                    id: dot
                    required property int index

                    readonly property bool current: grid.page === dot.index

                    width: dot.current ? 26 : 16
                    height: parent.height
                    radius: Appearance.r.capsule(height)
                    focusable: false
                    onClicked: grid.turnTo(dot.index)

                    Behavior on width {
                        NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: dot.current ? 16 : 6
                        height: 6
                        radius: height / 2
                        color: dot.current ? Appearance.c.accent : Appearance.c.borderStrong

                        Behavior on width {
                            NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.emphasizedEasing }
                        }
                    }
                }
            }
        }

        Column {
            anchors.centerIn: grid
            spacing: Appearance.s.md
            visible: root.results.length === 0

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "search"
                size: Appearance.m.iconXl
                color: Appearance.c.textFaint
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("No results")
                faint: true
            }
        }
    }
}
