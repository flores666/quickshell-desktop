pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Networking

/*!
    Network state.

    NetworkManager is the only backend Quickshell speaks; when it is absent or
    restarting `backend` reports None and every derived value collapses to the
    offline state, which the UI renders as a plain "offline" indicator rather
    than a broken control.
*/
Singleton {
    id: root

    readonly property bool available: Networking.backend !== NetworkBackendType.None

    readonly property var devices: root.available ? Networking.devices.values : []
    readonly property var wifiDevices: root.devices.filter(d => d && d.type === DeviceType.Wifi)
    readonly property var wiredDevices: root.devices.filter(d => d && d.type === DeviceType.Wired)

    readonly property WifiDevice wifi: root.wifiDevices.length > 0 ? root.wifiDevices[0] : null
    readonly property bool hasWifi: root.wifi !== null
    readonly property bool wifiEnabled: root.available && Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: !root.available || Networking.wifiHardwareEnabled

    readonly property WiredDevice wired: {
        for (const d of root.wiredDevices)
            if (d.connected)
                return d;
        return root.wiredDevices.length > 0 ? root.wiredDevices[0] : null;
    }
    readonly property bool hasWired: root.wired !== null && root.wired.hasLink
    readonly property bool wiredConnected: root.wired !== null && root.wired.connected

    /*! The Wi-Fi network currently connected on the primary adapter, if any. */
    readonly property WifiNetwork activeWifi: {
        if (!root.wifi)
            return null;
        for (const n of root.wifi.networks.values)
            if (n && n.connected)
                return n;
        return null;
    }

    readonly property bool wifiConnecting: root.wifi !== null
        && root.wifi.state === ConnectionState.Connecting

    /*! Networks to offer, strongest first, one entry per SSID. */
    readonly property var wifiNetworks: {
        if (!root.wifi)
            return [];
        const seen = ({});
        const out = [];
        for (const n of root.wifi.networks.values) {
            if (!n || n.name === "")
                continue;
            const prev = seen[n.name];
            if (prev === undefined) {
                seen[n.name] = out.length;
                out.push(n);
            } else if (n.signalStrength > out[prev].signalStrength || n.connected) {
                out[prev] = n;
            }
        }
        out.sort((a, b) => (b.connected - a.connected)
            || (b.known - a.known)
            || (b.signalStrength - a.signalStrength));
        return out;
    }

    /*!
        A VPN or tunnel device that NetworkManager reports as up.  These arrive
        as devices Quickshell does not classify as wired or Wi-Fi, so they are
        matched by kernel interface name.
    */
    readonly property bool vpnActive: root.devices.some(d => d
        && d.type === DeviceType.None
        && d.connected
        && /^(tun|tap|wg|ppp|ipsec|proton|nordlynx)/.test(d.name))

    readonly property bool limited: root.available && Networking.canCheckConnectivity
        && Networking.connectivityCheckEnabled
        && (Networking.connectivity === NetworkConnectivity.Portal
            || Networking.connectivity === NetworkConnectivity.Limited)

    function signalIcon(strength: real): string {
        if (strength >= 80) return "wifi-excellent";
        if (strength >= 55) return "wifi-good";
        if (strength >= 30) return "wifi-ok";
        if (strength >= 5) return "wifi-weak";
        return "wifi-none";
    }

    readonly property string icon: {
        if (root.wiredConnected)
            return "ethernet";
        if (!root.hasWifi)
            return root.hasWired ? "ethernet-off" : "network-offline";
        if (!root.wifiHardwareEnabled)
            return "wifi-off";
        if (!root.wifiEnabled)
            return "wifi-off";
        if (root.wifiConnecting)
            return "wifi-acquiring";
        if (!root.activeWifi)
            return "wifi-none";
        return root.signalIcon(root.activeWifi.signalStrength);
    }

    readonly property string label: {
        if (root.wiredConnected)
            return qsTr("Wired");
        if (root.activeWifi)
            return root.activeWifi.name;
        if (root.hasWifi && !root.wifiEnabled)
            return qsTr("Wi-Fi Off");
        return qsTr("Offline");
    }

    function setWifiEnabled(on: bool): void {
        if (root.available)
            Networking.wifiEnabled = on;
    }

    /*! Scanning costs power and airtime, so only the Wi-Fi list turns it on. */
    function setScanning(on: bool): void {
        if (root.wifi)
            root.wifi.scannerEnabled = on;
    }

    function connect(network: WifiNetwork): void {
        if (!network)
            return;
        if (network.known || network.security === WifiSecurityType.Open)
            network.connect();
        else
            root.passwordRequested(network);
    }

    function connectWithPassword(network: WifiNetwork, psk: string): void {
        if (network)
            network.connectWithPsk(psk);
    }

    function disconnect(network: Network): void {
        if (network)
            network.disconnect();
    }

    function forget(network: Network): void {
        if (network)
            network.forget();
    }

    signal passwordRequested(WifiNetwork network)
}
