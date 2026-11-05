pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    Screen temperature through Hyprland's CTM owner, hyprsunset. The shell
    owns its process; an empty config leaves scheduling and gamma alone.
    Its socket-ready event starts writes, never a timed readiness probe.
*/
Singleton {
    id: root

    readonly property int minimum: 2500
    readonly property int maximum: 6500
    readonly property int step: 100
    readonly property int temperature: root.clamp(Settings.nightLightTemperature)
    readonly property bool enabled: Settings.nightLightEnabled
    readonly property real warmth: (root.maximum - root.temperature) / (root.maximum - root.minimum)
    readonly property bool available: root.ready && root.failure === ""
    readonly property bool starting: daemon.running && !root.ready && root.failure === ""
    readonly property string target: root.enabled ? "temperature " + root.temperature : "identity"

    property bool ready: false
    property string failure: ""
    property string applied: ""
    property int generation: 0

    function clamp(kelvin: real): int {
        return Math.max(root.minimum, Math.min(root.maximum, Math.round(kelvin / root.step) * root.step));
    }

    function setEnabled(on: bool): void {
        if (root.available)
            Settings.setNightLightEnabled(on);
    }

    function setWarmth(value: real): void {
        if (root.available && root.enabled && Number.isFinite(value))
            Settings.setNightLightTemperature(root.clamp(root.maximum
                - Math.max(0, Math.min(1, value)) * (root.maximum - root.minimum)));
    }

    /*! Retry a missing or failed backend when the panel is next opened. */
    function refresh(): void {
        if (!daemon.running)
            root.failure = "";
    }

    function fail(message: string): void {
        root.generation++;
        root.ready = false;
        root.applied = "";
        root.failure = message;
        writer.running = false;
    }

    /*! One write in flight; a drag or toggle queues only its latest target. */
    function push(): void {
        if (!root.available || writer.running || root.target === root.applied)
            return;
        writer.sent = root.target;
        writer.generation = root.generation;
        writer.command = ["hyprctl", "hyprsunset"].concat(writer.sent.split(" "));
        writer.running = true;
    }

    onTargetChanged: root.push()

    Process {
        id: daemon
        // Missing dependencies are an unavailable control, not a shell warning.
        // Serialize process lifetimes across reload/restart. Parent death
        // must also release the CTM when qs exits without destroying QML.
        command: ["sh", "-c", "command -v hyprsunset >/dev/null 2>&1 || exit 127; "
            + "exec setpriv --pdeathsig KILL flock --no-fork \"$1\" "
            + "hyprsunset --identity --verbose 2>/dev/null", "sh",
            Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/"
                + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/.quickshell-night-light.lock"]
        // 0.4.0's --config parser is broken. Use its normal XDG lookup, scoped
        // to our empty config, so an existing user's schedule cannot take over.
        readonly property var configEnvironment: ({ XDG_CONFIG_HOME: Quickshell.shellPath("") })
        environment: daemon.configEnvironment
        running: Settings.ready && root.failure === ""
        stdout: SplitParser {
            onRead: line => {
                if (root.failure === "" && line.includes("hyprsunset socket started")) {
                    root.ready = true;
                    root.push();
                }
            }
        }
        onExited: code => { if (root.failure === "") root.fail(code === 127
            ? qsTr("Install hyprsunset to adjust screen temperature.")
            : qsTr("Screen temperature is unavailable. Another color manager may be running.")); }
    }

    Process {
        id: writer
        property string sent: ""
        property int generation: -1
        stdout: StdioCollector { id: reply }
        onStarted: responseBound.restart()
        onExited: code => {
            responseBound.stop();
            // An answer from a dead process cannot mark its replacement ready.
            if (!root.ready || writer.generation !== root.generation) {
                root.push();
                return;
            }
            if (code !== 0 || reply.text.trim() !== "ok") {
                root.fail(qsTr("Could not apply screen temperature."));
                return;
            }
            root.applied = writer.sent;
            root.push();
        }
    }

    Timer {
        // A bound on socket readiness, never a timed readiness probe.
        interval: 5000
        running: root.starting
        onTriggered: root.fail(qsTr("Screen temperature did not respond."))
    }

    Timer {
        id: responseBound
        interval: 5000
        onTriggered: root.fail(qsTr("Screen temperature did not respond."))
    }
}
