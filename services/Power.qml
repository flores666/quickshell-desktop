pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

/*!
    Battery and power-profile state.

    Both halves are optional: a desktop has no laptop battery, and many machines
    have no power-profiles-daemon.  Each is probed for real rather than assumed,
    and the UI omits whatever is not there.
*/
Singleton {
    id: root

    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool hasBattery: root.battery !== null
        && root.battery.ready && root.battery.isLaptopBattery && root.battery.isPresent

    readonly property real percentage: root.hasBattery ? root.battery.percentage : 0
    readonly property int state: root.hasBattery ? root.battery.state : UPowerDeviceState.Unknown
    readonly property bool charging: root.state === UPowerDeviceState.Charging
        || root.state === UPowerDeviceState.PendingCharge
    readonly property bool full: root.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery
    readonly property bool low: root.hasBattery && !root.charging && root.percentage <= 20
    readonly property bool critical: root.hasBattery && !root.charging && root.percentage <= 10

    readonly property string icon: {
        if (!root.hasBattery)
            return "ac-adapter";
        const level = Math.max(0, Math.min(100, Math.round(root.percentage / 10) * 10));
        return "battery-" + level + ((root.charging || root.full) ? "-charging" : "");
    }

    readonly property string timeLabel: {
        if (!root.hasBattery)
            return "";
        const secs = root.charging ? root.battery.timeToFull : root.battery.timeToEmpty;
        if (secs <= 0)
            return "";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const time = h > 0 ? qsTr("%1 hr %2 min").arg(h).arg(m) : qsTr("%1 min").arg(m);
        return root.charging ? qsTr("%1 until full").arg(time) : qsTr("%1 remaining").arg(time);
    }

    // ------------------------------------------------------------- profiles

    /*! Set once at startup by probing the system bus for power-profiles-daemon. */
    property bool hasProfiles: false

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    function setProfile(p: int): void {
        if (root.hasProfiles)
            PowerProfiles.profile = p;
    }

    function profileIcon(p: int): string {
        switch (p) {
        case PowerProfile.PowerSaver: return "power-saver";
        case PowerProfile.Performance: return "power-performance";
        default: return "power-balanced";
        }
    }

    function profileLabel(p: int): string {
        switch (p) {
        case PowerProfile.PowerSaver: return qsTr("Power Saver");
        case PowerProfile.Performance: return qsTr("Performance");
        default: return qsTr("Balanced");
        }
    }

    Process {
        running: true
        command: ["busctl", "--system", "--timeout=3", "status", "net.hadess.PowerProfiles"]
        onExited: exitCode => root.hasProfiles = exitCode === 0
    }
}
