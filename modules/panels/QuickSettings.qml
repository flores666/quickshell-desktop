pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"
import "root:/modules/panels/qs"
import "root:/modules/settings"

/*!
    The system panel, opened from the right of the top bar.

    The front page carries the controls that get used constantly; anything that
    needs a list — networks, Bluetooth devices, audio outputs, power actions —
    slides in as a sub-page rather than making the panel taller. Controls for
    hardware this machine does not have are disabled rather than removed, so the
    layout is the same on every machine (see FrontPage).
*/
ShellOverlay {
    id: root

    overlayId: Overlay.quickSettings
    cardWidth: Math.min(Appearance.m.popoverWidth,
        (root.screen ? root.screen.width : Appearance.m.popoverWidth) - Appearance.s.md * 2)
    cardHeight: Math.min(body.implicitHeight + Appearance.s.lg * 2,
        root.height)

    /*! "" is the front page; anything else is a key of `pages`. */
    property string page: ""
    /*!
        The page actually on screen.

        It follows `page` only once whatever was there has faded out. Fading the
        two into each other instead leaves both legible at half strength for the
        length of the transition, which reads as the controls smearing.
    */
    property string visiblePage: ""
    readonly property bool swapping: root.page !== root.visiblePage
    // Overflow is a property of the destination size, not the animated viewport.
    // A page becoming taller must not briefly narrow its tiles and show a bar.
    readonly property bool scrollable: body.implicitHeight > root.cardHeight - Appearance.s.lg * 2 + 1

    /*! Every sub-page, by the name `page` holds. `action` is an optional button
        for the page's title row, beside the way back. */
    readonly property var pages: ({
        wifi: { title: qsTr("Wi-Fi"), component: wifiPage, action: restartWifi },
        bluetooth: { title: qsTr("Bluetooth"), component: bluetoothPage },
        output: { title: qsTr("Output Device"), component: outputPage },
        input: { title: qsTr("Input Device"), component: inputPage },
        profile: { title: qsTr("Power profile"), component: profilePage },
        power: { title: qsTr("Power"), component: powerPage },
        colors: { title: qsTr("Colors"), component: colorsPage }
    })
    readonly property var current: root.pages[root.visiblePage] ?? null

    onShownChanged: if (root.shown) {
        NightLight.refresh();
        scroll.contentY = 0;
    }

    Timer {
        // Hands the card over to the incoming page. A Behavior animation never
        // emits finished(), so the handover is timed rather than chained off the
        // fade; `running` is a plain binding, which cannot fail to fire.
        running: root.swapping
        interval: Appearance.t.popupFade
        onTriggered: root.visiblePage = root.page
    }

    onVisiblePageChanged: scroll.contentY = 0

    // Restored once the surface is gone, not as the popup starts closing: doing
    // it on the way out fades the front page back in over the sub-page and grows
    // the card again, all through the closing fade.
    onRenderedChanged: if (!root.rendered) {
        root.page = "";
        root.visiblePage = "";
    }

    // Custom controls keep keyboard focus inside the scrolled viewport too.
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged(): void {
            const item = root.Window.activeFocusItem;
            let owner = item;
            while (owner && owner !== body) owner = owner.parent;
            if (!item || !owner) return;
            const at = item.mapToItem(body, 0, 0, item.width, item.height);
            const leading = at.y - Appearance.m.focusRing;
            const trailing = at.y + at.height + Appearance.m.focusRing;
            scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height,
                leading < scroll.contentY ? leading
                    : trailing > scroll.contentY + scroll.height ? trailing - scroll.height : scroll.contentY));
        }
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.margins: Appearance.s.lg
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: body
            width: scroll.width - (root.scrollable ? scrollbar.footprint : 0)
            height: implicitHeight
            implicitHeight: root.visiblePage === "" ? main.implicitHeight
                : header.height + Appearance.s.md + pageLoader.implicitHeight

            // ------------------------------------------------------- sub-page

            Item {
                id: header
                width: parent.width
                height: Appearance.m.touchTarget
                visible: opacity > 0
                opacity: !root.swapping && root.visiblePage !== "" ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: Appearance.t.popupFade; easing.type: Appearance.t.standardEasing }
                }

                QsIconButton {
                    id: back
                    label: qsTr("Back")
                    tipBelow: true
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "chevron-left"
                    size: Appearance.m.qsChevron
                    onClicked: root.page = ""
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    x: back.width + Appearance.s.sm
                    width: (action.item ? action.x - Appearance.s.sm : parent.width) - x
                    text: root.current?.title ?? ""
                    role: Label.Role.Subtitle
                }

                Loader {
                    id: action
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: root.current?.action ?? null
                }
            }

            Loader {
                id: pageLoader
                y: header.height + Appearance.s.md
                width: parent.width
                height: pageLoader.implicitHeight
                active: root.visiblePage !== ""
                opacity: !root.swapping && root.visiblePage !== "" ? 1 : 0
                visible: opacity > 0
                layer.enabled: opacity < 1

                Behavior on opacity {
                    NumberAnimation { duration: Appearance.t.popupFade; easing.type: Appearance.t.standardEasing }
                }

                sourceComponent: root.current?.component ?? null
            }

            Tooltip {
                id: actionTip
                below: true
                z: 1
            }

            Component { id: wifiPage; WifiPage {} }
            Component {
                // For an adapter that has stopped finding or holding networks: the
                // radio off and on again, which NetworkManager does without
                // privilege. While it runs, the page says so beside a spinner.
                // A wand — the fix-it — rather than a refresh glyph, which could as
                // well mean "scan again"; it also says what it does when pointed at
                // or tabbed to.
                id: restartWifi
                IconButton {
                    id: restartButton
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Restart Wi-Fi")
                    visible: Network.wifiEnabled && !Network.restarting
                    icon: "magic-wand"
                    size: Appearance.m.qsChevron
                    onClicked: Network.restartWifi()

                    readonly property bool explaining: restartButton.hovered || restartButton.focusVisible
                    onExplainingChanged: {
                        const at = restartButton.mapToItem(body, restartButton.width / 2, restartButton.height);
                        actionTip.anchorX = at.x;
                        actionTip.anchorY = at.y;
                        actionTip.text = qsTr("Restart Wi-Fi");
                        actionTip.show = restartButton.explaining;
                    }
                    Component.onDestruction: actionTip.show = false
                }
            }
            Component { id: bluetoothPage; BluetoothPage {} }
            Component { id: outputPage; AudioDevicePage { output: true } }
            Component { id: inputPage; AudioDevicePage { output: false } }
            Component {
                id: profilePage
                PowerProfilePage { onBackRequested: root.page = "" }
            }
            Component {
                id: powerPage
                PowerPage { onActionTaken: Overlay.close() }
            }
            Component {
                id: colorsPage
                Column {
                    spacing: Appearance.s.lg

                    ColorsSection { width: parent.width }

                    NightLightControl {
                        width: parent.width
                        visible: NightLight.available
                    }
                }
            }

            // ----------------------------------------------------- front page

            FrontPage {
                id: main
                width: parent.width
                visible: opacity > 0
                opacity: !root.swapping && root.visiblePage === "" ? 1 : 0
                // Fades as one flattened image. Without this every child is faded
                // separately, and the tiles — shapes painted over each other —
                // show through themselves as bright accent blocks.
                layer.enabled: opacity < 1

                Behavior on opacity {
                    NumberAnimation { duration: Appearance.t.popupFade; easing.type: Appearance.t.standardEasing }
                }

                onPageRequested: page => root.page = page
            }
        }
    }
    ThinScrollBar {
        id: scrollbar
        objectName: "pageScrollbar"
        flickable: scroll
        visible: root.scrollable && scrollbar.overflowing && !root.swapping
            && root.settled && !root.cardItem.resizing && !root.cardItem.rolling
    }
}
