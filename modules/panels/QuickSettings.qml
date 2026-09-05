pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"
import "root:/modules/panels/qs"

/*!
    The system panel, opened from the right of the top bar.

    The front page carries the controls that get used constantly; anything that
    needs a list — networks, Bluetooth devices, audio outputs, power actions —
    slides in as a sub-page rather than making the panel taller.  Controls for
    hardware this machine does not have are simply absent.
*/
ShellOverlay {
    id: root

    overlayId: Overlay.quickSettings
    cardWidth: Appearance.m.popoverWidth
    cardHeight: content.implicitHeight + Appearance.s.lg * 2

    /*! "" is the front page; anything else names the sub-page component. */
    property string page: ""
    /*!
        The page actually on screen.

        It follows `page` only once whatever was there has faded out. Fading the
        two into each other instead leaves both legible at half strength for the
        length of the transition, which reads as the controls smearing.
    */
    property string visiblePage: ""
    readonly property bool swapping: root.page !== root.visiblePage

    readonly property string pageTitle: switch (root.visiblePage) {
        case "wifi": return qsTr("Wi-Fi");
        case "bluetooth": return qsTr("Bluetooth");
        case "output": return qsTr("Output Device");
        case "input": return qsTr("Input Device");
        case "power": return qsTr("Power");
        case "colors": return qsTr("Colours");
        default: return "";
    }

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
                text: root.pageTitle
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

            sourceComponent: switch (root.visiblePage) {
                case "wifi": return wifiPage;
                case "bluetooth": return bluetoothPage;
                case "output": return outputPage;
                case "input": return inputPage;
                case "power": return powerPage;
                case "colors": return colorsPage;
                default: return null;
            }
        }

        Component { id: wifiPage; WifiPage {} }
        Component { id: bluetoothPage; BluetoothPage {} }
        Component { id: outputPage; AudioDevicePage { output: true } }
        Component { id: inputPage; AudioDevicePage { output: false } }
        Component {
            id: powerPage
            PowerPage { onActionTaken: Overlay.close() }
        }
        Component { id: colorsPage; ColorsPage {} }

        // ----------------------------------------------------- front page

        Column {
            id: main
            width: parent.width
            spacing: Appearance.s.lg
            visible: opacity > 0
            opacity: !root.swapping && root.visiblePage === "" ? 1 : 0
            // Fades as one flattened image. Without this every child is faded
            // separately, and the tiles — which are opaque shapes painted over
            // each other — show through themselves as bright accent blocks.
            layer.enabled: opacity < 1

            Behavior on opacity {
                NumberAnimation { duration: Appearance.t.fast }
            }

            Grid {
                width: parent.width
                columns: 2
                columnSpacing: Appearance.s.md
                rowSpacing: Appearance.s.md

                QsTile {
                    width: (main.width - Appearance.s.md) / 2
                    visible: Network.hasWifi
                    icon: Network.icon
                    title: qsTr("Wi-Fi")
                    status: Network.wifiEnabled ? Network.label : qsTr("Off")
                    active: Network.wifiEnabled
                    busy: Network.wifiConnecting
                    hasPage: true
                    toggleEnabled: Network.wifiHardwareEnabled
                    onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
                    onPageRequested: root.page = "wifi"
                }

                QsTile {
                    width: (main.width - Appearance.s.md) / 2
                    visible: !Network.hasWifi && Network.hasWired
                    icon: Network.icon
                    title: qsTr("Network")
                    status: Network.label
                    active: Network.wiredConnected
                    toggleEnabled: false
                }

                QsTile {
                    width: (main.width - Appearance.s.md) / 2
                    visible: Bt.available
                    icon: Bt.icon
                    title: qsTr("Bluetooth")
                    status: Bt.label
                    active: Bt.enabled
                    busy: Bt.busy
                    hasPage: true
                    toggleEnabled: !Bt.blocked
                    onToggled: Bt.setEnabled(!Bt.enabled)
                    onPageRequested: root.page = "bluetooth"
                }

                QsTile {
                    width: (main.width - Appearance.s.md) / 2
                    icon: "dnd"
                    title: qsTr("Do Not Disturb")
                    status: Settings.doNotDisturb ? qsTr("On") : qsTr("Off")
                    active: Settings.doNotDisturb
                    onToggled: Settings.setDoNotDisturb(!Settings.doNotDisturb)
                }

                QsTile {
                    width: (main.width - Appearance.s.md) / 2
                    icon: Settings.effectiveDark ? "night-light" : "brightness"
                    title: qsTr("Dark Style")
                    status: Settings.effectiveDark ? qsTr("On") : qsTr("Off")
                    active: Settings.effectiveDark
                    hasPage: true
                    onToggled: Settings.toggleTheme()
                    onPageRequested: root.page = "colors"
                }
            }

            Column {
                width: parent.width
                spacing: Appearance.s.sm

                QsSliderRow {
                    width: parent.width
                    visible: Audio.hasSink
                    icon: Audio.volumeIcon
                    value: Audio.volume
                    muted: Audio.muted
                    toggleEnabled: true
                    hasPage: Audio.sinks.length > 1
                    onMoved: v => {
                        if (Audio.muted && v > 0)
                            Audio.toggleMute();
                        Audio.setVolume(v);
                    }
                    onIconClicked: Audio.toggleMute()
                    onPageRequested: root.page = "output"
                }

                QsSliderRow {
                    width: parent.width
                    visible: Audio.hasSource
                    icon: Audio.micIcon
                    value: Audio.micVolume
                    muted: Audio.micMuted
                    toggleEnabled: true
                    hasPage: Audio.sources.length > 1
                    onMoved: v => Audio.setMicVolume(v)
                    onIconClicked: Audio.toggleMicMute()
                    onPageRequested: root.page = "input"
                }

                QsSliderRow {
                    width: parent.width
                    visible: Brightness.available
                    icon: Brightness.icon
                    value: Brightness.value
                    onMoved: v => Brightness.set(v)
                }
            }

            PowerProfileRow {
                width: parent.width
                visible: Power.hasProfiles
            }

            Divider { width: parent.width }

            Item {
                width: parent.width
                height: 34

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.s.sm
                    visible: Power.hasBattery

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Power.icon
                        size: Appearance.m.icon
                        color: Power.critical ? Appearance.c.danger : Appearance.c.text
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Power.timeLabel !== ""
                            ? qsTr("%1% · %2").arg(Math.round(Power.percentage)).arg(Power.timeLabel)
                            : qsTr("%1%").arg(Math.round(Power.percentage))
                        role: Label.Role.Small
                        muted: true
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.s.xs

                    IconButton {
                        icon: "lock"
                        onClicked: {
                            Overlay.close();
                            Session.lock();
                        }
                    }

                    IconButton {
                        icon: "shutdown"
                        onClicked: root.page = "power"
                    }
                }
            }
        }
    }
}
