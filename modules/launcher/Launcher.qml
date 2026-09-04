pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"

/*!
    The application launcher: search plus a grid of everything installed.

    The search field keeps keyboard focus the whole time and forwards navigation
    keys to the grid, so typing and moving the selection never fight over focus.
*/
ShellOverlay {
    id: root

    overlayId: Overlay.launcher
    placement: ShellOverlay.Placement.Centre
    cardRadius: Appearance.r.xl
    cardWidth: Math.min(940, (root.screen ? root.screen.width : 1920) - Appearance.s.huge * 2)
    cardHeight: Math.min(600, (root.screen ? root.screen.height : 1080) - Appearance.s.huge * 3)
    initialFocusItem: search.input

    readonly property var results: Apps.search(search.text)

    onShownChanged: {
        if (root.shown) {
            search.clear();
            grid.currentIndex = 0;
            grid.positionViewAtBeginning();
        }
    }

    function launchCurrent(): void {
        const entry = root.results[grid.currentIndex];
        if (!entry)
            return;
        Overlay.close();
        Apps.launch(entry);
    }

    Item {
        id: card

        anchors.fill: parent

        SearchField {
            id: search

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Appearance.s.xxl
            width: Math.min(520, parent.width - Appearance.s.xxl * 2)
            placeholder: qsTr("Search applications…")

            onTextChanged: {
                grid.currentIndex = 0;
                grid.positionViewAtBeginning();
            }
            onAccepted: root.launchCurrent()
            onEscaped: Overlay.close()
            onNavigate: key => grid.navigate(key)
        }

        GridView {
            id: grid

            anchors.top: search.bottom
            anchors.topMargin: Appearance.s.xl
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.s.lg
            anchors.bottomMargin: Appearance.s.lg
            clip: true
            model: root.results
            cellWidth: Math.floor((width - 1) / Math.max(1, Math.floor(width / 118)))
            cellHeight: 118
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            readonly property int columns: Math.max(1, Math.floor(width / cellWidth))

            function navigate(key: int): void {
                const n = grid.count;
                if (n === 0)
                    return;
                let i = grid.currentIndex;
                switch (key) {
                case Qt.Key_Down: i += grid.columns; break;
                case Qt.Key_Up: i -= grid.columns; break;
                case Qt.Key_Tab: i += 1; break;
                case Qt.Key_Backtab: i -= 1; break;
                case Qt.Key_PageDown: i += grid.columns * 3; break;
                case Qt.Key_PageUp: i -= grid.columns * 3; break;
                default: return;
                }
                grid.currentIndex = Math.max(0, Math.min(n - 1, i));
                grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
            }

            delegate: AppTile {
                required property var modelData
                required property int index

                width: grid.cellWidth
                height: grid.cellHeight
                entry: this.modelData
                current: grid.currentIndex === this.index

                onClicked: {
                    Overlay.close();
                    Apps.launch(this.modelData);
                }
                onHoveredChanged: if (this.hovered) grid.currentIndex = this.index
            }
        }

        Column {
            anchors.centerIn: grid
            spacing: Appearance.s.md
            visible: root.results.length === 0

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "search"
                size: 28
                color: Appearance.c.textFaint
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("No results")
                faint: true
            }
        }

        ThinScrollBar { flickable: grid }
    }
}
