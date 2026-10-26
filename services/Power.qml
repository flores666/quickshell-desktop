pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

/*!
    Battery and power-profile state, and the battery's charge limit.

    All three are optional: a desktop has no laptop battery, many machines
    have no power-profiles-daemon, and not every battery can stop short of
    full.  Each is probed for real rather than assumed, and the UI omits
    whatever is not there.
*/
Singleton {
    id: root

    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool hasBattery: root.battery !== null
        && root.battery.ready && root.battery.isLaptopBattery && root.battery.isPresent

    // Quickshell reports 0-1; everything downstream thinks in 0-100.
    readonly property real percentage: root.hasBattery ? root.battery.percentage * 100 : 0
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
        // Only while it is actually filling or draining: a full battery on AC
        // still reports a time to empty, worked out from its trickle draw —
        // weeks of it — which is no answer to anything.
        const draining = root.state === UPowerDeviceState.Discharging;
        if (!root.hasBattery || !(root.charging || draining))
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

    // ---------------------------------------------------------- charge limit

    /*!
        Holding the battery short of full, which is UPower's to do: it writes
        the kernel's threshold, or turns on the firmware's conservation mode,
        which picks its own level; it lets the active session do so without a
        password, and puts the choice back at boot, so the shell keeps no
        setting of its own. Every battery that can is switched together.
    */
    property var limitable: []
    property bool chargeLimited: false
    /*! Where charging stops; 0 where the firmware picks it. */
    property int chargeLimit: 0
    readonly property bool hasChargeLimit: root.hasBattery && root.limitable.length > 0

    function setChargeLimited(on: bool): void {
        if (!root.hasChargeLimit || limiter.running)
            return;
        limiter.command = ["sh", "-c", "v=$1; shift; for d; do busctl --system call org.freedesktop.UPower "
            + "\"$d\" org.freedesktop.UPower.Device EnableChargeThreshold b \"$v\" || exit 1; done",
            "sh", String(on)].concat(root.limitable);
        limiter.running = true;
    }

    /*! One line per battery: its path, then busctl's typed values of the
        four properties asked for, e.g. `<path> b true b false u 2 u 80`. */
    function readLimits(text: string): void {
        const rows = text.trim().split("\n").map(l => l.split(" ")).filter(f => f[2] === "true");
        root.limitable = rows.map(f => f[0]);
        root.chargeLimited = rows.length > 0 && rows.every(f => f[4] === "true");
        // Bit 2 of the settings: the end threshold is the kernel's, and real.
        const end = rows.length > 0 && (parseInt(rows[0][6]) & 2) ? parseInt(rows[0][8]) : 0;
        root.chargeLimit = end > 0 && end <= 100 ? end : 0;
    }

    /*! UPower's signals, every one of them: `busctl monitor` needs root on
        the system bus, gdbus's match rule does not. Only a threshold, a
        device coming or going, or UPower (re)appearing — its first line — is
        worth a new reading. */
    Process {
        running: root.hasBattery
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.UPower"]
        stdout: SplitParser {
            onRead: line => {
                if (/ChargeThreshold|DeviceAdded|DeviceRemoved|is owned by/.test(line))
                    limits.run();
            }
        }
    }

    Probe {
        id: limits
        command: ["sh", "-c", "for d in $(upower -e | grep /battery_); do echo \"$d\" "
            + "$(busctl --system get-property org.freedesktop.UPower \"$d\" org.freedesktop.UPower.Device "
            + "ChargeThresholdSupported ChargeThresholdEnabled ChargeThresholdSettingsSupported "
            + "ChargeEndThreshold 2>/dev/null); done"]
        stdout: StdioCollector { onStreamFinished: root.readLimits(this.text) }
    }

    /*! A refusal changes nothing, so the switch, which shows the reading,
        stays where it was. */
    Process {
        id: limiter
        stderr: StdioCollector { onStreamFinished: if (this.text !== "") console.warn("Power:", this.text.trim()) }
    }
}
