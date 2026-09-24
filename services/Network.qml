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

    /*! Quickshell reports signal strength as 0-1, not NetworkManager's 0-100. */
    function signalIcon(strength: real): string {
        if (strength >= 0.80) return "wifi-excellent";
        if (strength >= 0.55) return "wifi-good";
        if (strength >= 0.30) return "wifi-ok";
        if (strength >= 0.05) return "wifi-weak";
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
        root.failure = "";
        root.attempt = network;
        if (network.known || network.security === WifiSecurityType.Open)
            network.connect();
        else
            root.passwordRequested(network, "");
    }

    function connectWithPassword(network: WifiNetwork, psk: string): void {
        if (!network)
            return;
        root.failure = "";
        root.attempt = network;
        network.connectWithPsk(psk);
    }

    /*!
        Replace a saved network's password.

        Quickshell cannot edit a saved profile in place, so the profile is
        forgotten and the network joined afresh with the new password — which
        goes over D-Bus, never onto a command line. The join waits for the
        forget to land (`known` turning false); joining first would just reuse
        the old profile.
    */
    function changePassword(network: WifiNetwork, psk: string): void {
        if (!network)
            return;
        if (!network.known) {
            root.connectWithPassword(network, psk);
            return;
        }
        root.repassing = network;
        root.repassPsk = psk;
        network.forget();
    }

    function disconnect(network: Network): void {
        if (network)
            network.disconnect();
    }

    function forget(network: Network): void {
        if (network)
            network.forget();
    }

    /*! Why the last join failed, for the Wi-Fi page; empty when it did not. */
    property string failure: ""

    /*! The network most recently asked to join, watched for failure. */
    property WifiNetwork attempt: null
    property WifiNetwork repassing: null
    property string repassPsk: ""

    Connections {
        target: root.repassing
        function onKnownChanged(): void {
            const network = root.repassing;
            if (!network || network.known)
                return;
            const psk = root.repassPsk;
            root.repassing = null;
            root.repassPsk = "";
            root.connectWithPassword(network, psk);
        }
    }

    Connections {
        target: root.attempt
        function onConnectionFailed(reason: int): void {
            const network = root.attempt;
            if (!network)
                return;
            // A secured network that turned us away for want of the right
            // secret is asked about again rather than left failing silently:
            // the saved password may be stale, or the one typed mistyped.
            const secretProblem = reason === ConnectionFailReason.NoSecrets
                || reason === ConnectionFailReason.WifiClientFailed
                || reason === ConnectionFailReason.WifiAuthTimeout;
            if (secretProblem && network.security !== WifiSecurityType.Open) {
                root.passwordRequested(network, qsTr("That password did not work."));
                return;
            }
            root.failure = qsTr("Could not connect to “%1”.").arg(network.name);
        }
    }

    /*! `reason` is empty for a first ask, or says why the last try failed. */
    signal passwordRequested(WifiNetwork network, string reason)
}
