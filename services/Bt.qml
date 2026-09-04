pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth

/*!
    Bluetooth state.

    `available` is false on machines with no adapter and while BlueZ is down; the
    UI hides every Bluetooth control in that case rather than showing something
    that cannot work.
*/
Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: root.adapter !== null
    readonly property bool enabled: root.available && root.adapter.enabled
    readonly property bool busy: root.available
        && (root.adapter.state === BluetoothAdapterState.Enabling
            || root.adapter.state === BluetoothAdapterState.Disabling)
    readonly property bool blocked: root.available
        && root.adapter.state === BluetoothAdapterState.Blocked
    readonly property bool discovering: root.available && root.adapter.discovering

    readonly property var devices: root.available ? root.adapter.devices.values.filter(d => d) : []
    readonly property var connected: root.devices.filter(d => d.connected)
    readonly property var paired: root.devices.filter(d => d.paired || d.bonded)
    /*! Paired devices first, then anything discovery has turned up with a name. */
    readonly property var listed: {
        const known = root.paired.slice().sort((a, b) => (b.connected - a.connected));
        const rest = root.devices.filter(d => !d.paired && !d.bonded && d.deviceName !== "");
        return known.concat(rest);
    }

    readonly property string icon: !root.enabled ? "bluetooth-off"
        : root.connected.length > 0 ? "bluetooth" : "bluetooth-disconnected"

    readonly property string label: !root.available ? qsTr("Unavailable")
        : root.blocked ? qsTr("Blocked")
        : !root.enabled ? qsTr("Off")
        : root.connected.length === 1 ? root.deviceName(root.connected[0])
        : root.connected.length > 1 ? qsTr("%1 devices").arg(root.connected.length)
        : qsTr("On")

    function deviceName(device: BluetoothDevice): string {
        if (!device)
            return "";
        return device.name !== "" ? device.name
            : device.deviceName !== "" ? device.deviceName : device.address;
    }

    function deviceIcon(device: BluetoothDevice): string {
        const hint = String(device?.icon ?? "").toLowerCase();
        if (hint.includes("headset"))
            return "headset";
        if (hint.includes("headphone") || hint.includes("audio-card"))
            return "headphones";
        if (hint.includes("speaker"))
            return "speakers";
        if (hint.includes("keyboard"))
            return "keyboard";
        if (hint.includes("mouse"))
            return "mouse";
        if (hint.includes("gaming"))
            return "gamepad";
        if (hint.includes("phone"))
            return "phone";
        if (hint.includes("computer"))
            return "computer";
        return "bluetooth";
    }

    function setEnabled(on: bool): void {
        if (root.available && !root.blocked)
            root.adapter.enabled = on;
    }

    function setDiscovering(on: bool): void {
        if (root.available && root.enabled)
            root.adapter.discovering = on;
    }

    function toggleConnection(device: BluetoothDevice): void {
        if (device)
            device.connected = !device.connected;
    }
}
