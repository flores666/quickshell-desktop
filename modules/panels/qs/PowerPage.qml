pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*! Session and power actions. */
Column {
    id: root


    signal actionTaken

    spacing: 1

    MenuRow {
        width: root.width
        icon: "lock"
        title: qsTr("Lock")
        onClicked: {
            root.actionTaken();
            Session.lock();
        }
    }

    MenuRow {
        width: root.width
        icon: "suspend"
        title: qsTr("Suspend")
        onClicked: {
            root.actionTaken();
            Session.suspend();
        }
    }

    MenuRow {
        width: root.width
        icon: "logout"
        title: qsTr("Log Out")
        onClicked: {
            root.actionTaken();
            Session.logout();
        }
    }

    MenuRow {
        width: root.width
        icon: "reboot"
        title: qsTr("Restart")
        onClicked: {
            root.actionTaken();
            Session.reboot();
        }
    }

    MenuRow {
        width: root.width
        icon: "shutdown"
        title: qsTr("Power Off")
        iconColor: Appearance.c.danger
        onClicked: {
            root.actionTaken();
            Session.shutdown();
        }
    }
}
