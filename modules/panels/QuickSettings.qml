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
    cardWidth: Appearance.m.popoverWidth
    cardHeight: content.implicitHeight + Appearance.s.lg * 2

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

    /*! Every sub-page, by the name `page` holds. */
    readonly property var pages: ({
        wifi: { title: qsTr("Wi-Fi"), component: wifiPage },
        bluetooth: { title: qsTr("Bluetooth"), component: bluetoothPage },
        output: { title: qsTr("Output Device"), component: outputPage },
        input: { title: qsTr("Input Device"), component: inputPage },
        power: { title: qsTr("Power"), component: powerPage },
        colors: { title: qsTr("Colours"), component: colorsPage }
    })
    readonly property var current: root.pages[root.visiblePage] ?? null

    Timer {
        // Hands the card over to the incoming page. A Behavior animation never
        // emits finished(), so the handover is timed rather than chained off the
        // fade; `running` is a plain binding, which cannot fail to fire.
        running: root.swapping
        interval: Appearance.t.fast
        onTriggered: root.visiblePage = root.page
    }

    // Restored once the surface is gone, not as the popup starts closing: doing
    // it on the way out fades the front page back in over the sub-page and grows
    // the card again, all through the closing fade.
    onRenderedChanged: if (!root.rendered) {
        root.page = "";
        root.visiblePage = "";
    }

    Item {
        id: content

        anchors.fill: parent
        anchors.margins: Appearance.s.lg
        implicitHeight: root.visiblePage === "" ? main.implicitHeight
            : header.height + Appearance.s.md + pageLoader.implicitHeight

        // ------------------------------------------------------- sub-page

        Item {
            id: header
            width: parent.width
            height: 32
            visible: opacity > 0
            opacity: !root.swapping && root.visiblePage !== "" ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: Appearance.t.fast }
            }

            IconButton {
                id: back
                anchors.verticalCenter: parent.verticalCenter
                icon: "chevron-left"
                size: 30
                onClicked: root.page = ""
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                x: back.width + Appearance.s.sm
                width: parent.width - x
                text: root.current?.title ?? ""
                role: Label.Role.Subtitle
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
                NumberAnimation { duration: Appearance.t.fast }
            }

            sourceComponent: root.current?.component ?? null
        }

        Component { id: wifiPage; WifiPage {} }
        Component { id: bluetoothPage; BluetoothPage {} }
        Component { id: outputPage; AudioDevicePage { output: true } }
        Component { id: inputPage; AudioDevicePage { output: false } }
        Component {
            id: powerPage
            PowerPage { onActionTaken: Overlay.close() }
        }
        Component { id: colorsPage; ColorsSection {} }

        // ----------------------------------------------------- front page

        FrontPage {
            id: main
            width: parent.width
            visible: opacity > 0
            opacity: !root.swapping && root.visiblePage === "" ? 1 : 0
            // Fades as one flattened image. Without this every child is faded
            // separately, and the tiles — which are opaque shapes painted over
            // each other — show through themselves as bright accent blocks.
            layer.enabled: opacity < 1

            Behavior on opacity {
                NumberAnimation { duration: Appearance.t.fast }
            }

            onPageRequested: page => root.page = page
        }
    }
}
