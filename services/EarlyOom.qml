pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    earlyoom, the daemon that stops the process using the most memory before
    the machine runs out (packages.txt; install.sh installs its options from
    the project's earlyoom/earlyoom and enables it).

    Whether it is installed is whether its unit file is there, and its
    options are /etc/default/earlyoom, both watched. What it did is in its
    journal, followed (wheel, adm and systemd-journal may read it): every
    process it stopped, newest first, and each one stopped while the shell
    watches posted as a notification — the shell is the notification daemon,
    so nothing like systembus-notify is needed. Whether it runs is asked as
    the follow starts and whenever its journal says something else, which is
    where systemd says it started or stopped.

    Its options are root's: `apply` writes the file and restarts it in one
    pkexec call, so the polkit agent asks for the password once per change.
*/
Singleton {
    id: root

    readonly property string unitFile: "/usr/lib/systemd/system/earlyoom.service"
    readonly property string configFile: "/etc/default/earlyoom"
    /*! The line that marks the file as the desktop's: install.sh leaves a
        file that has it alone. */
    readonly property string marker: "# quickshell-desktop"

    property bool available: false
    property bool running: false
    /*! Whether its journal can be read: without it, no kills are known. */
    property bool logReadable: true
    /*! EARLYOOM_ARGS as the file has them. */
    property string args: ""
    readonly property var config: EarlyOomArgs.parse(root.args)
    /*! What it stopped, newest first: `{ time, pid, uid, name, signal, rss }`,
        time in ms, rss in MiB. */
    property var kills: []
    readonly property int maxKills: 50

    /*! An apply under way, and why the last one did not take. */
    property bool pending: false
    property string failure: ""

    /*! systemd logs a start or stop as several lines. */
    readonly property int settleTime: 250

    /*! Memory and swap left, in percent, as earlyoom reckons them. */
    readonly property var usage: root.memory(Processes.memory)
    /*! The process it would stop now, while it runs; -1 for none. */
    readonly property int next: root.running ? root.victim(Processes.list, root.config) : -1

    /*! As earlyoom works them out: available memory over what user space
        could have (available and anonymous), swap free over swap, and no
        swap as none free, which leaves the decision to memory alone. */
    function memory(m: var): var {
        const user = m.available + m.anon;
        return {
            memPercent: user > 0 ? m.available * 100 / user : 100,
            swapPercent: m.swapTotal > 0 ? m.swapFree * 100 / m.swapTotal : 0
        };
    }

    /*! The pid earlyoom would pick from `list` now, as it picks: the highest
        oom_score, 300 more for a preferred name and 300 less for an avoided
        one, ties to the larger; never init, kthreadd or its threads, a
        process the kernel spares (oom_score_adj -1000), nor itself. */
    function victim(list: var, config: var): int {
        const avoid = EarlyOomArgs.matcher(EarlyOomArgs.regex(config, "avoid"));
        const prefer = EarlyOomArgs.matcher(EarlyOomArgs.regex(config, "prefer"));
        let best = null;
        for (const p of list) {
            if (p.pid <= 2 || p.ppid === 2 || p.oomAdj === -1000 || p.name === "earlyoom")
                continue;
            const score = p.oomScore + (prefer(p.name) ? 300 : 0) - (avoid(p.name) ? 300 : 0);
            if (best === null || score > best.score || (score === best.score && p.rss > best.rss))
                best = { pid: p.pid, score, rss: p.rss };
        }
        return best?.pid ?? -1;
    }

    /*! Which list holds a name: "avoid", "prefer" or "". */
    function preferenceIn(config: var, name: string): string {
        if (EarlyOomArgs.matches(EarlyOomArgs.regex(config, "avoid"), name))
            return "avoid";
        return EarlyOomArgs.matches(EarlyOomArgs.regex(config, "prefer"), name) ? "prefer" : "";
    }

    function preference(name: string): string {
        return root.preferenceIn(root.config, name);
    }

    /*! The config with a name moved into one list, or out of both. */
    function withPreference(config: var, name: string, list: string): var {
        const next = Object.assign({}, config, {
            avoid: config.avoid.filter(n => n !== name),
            prefer: config.prefer.filter(n => n !== name)
        });
        if (list !== "")
            next[list] = next[list].concat([name]);
        return next;
    }

    function protect(name: string): void { root.apply(root.withPreference(root.config, name, "avoid")); }
    function preferKill(name: string): void { root.apply(root.withPreference(root.config, name, "prefer")); }
    function clear(name: string): void { root.apply(root.withPreference(root.config, name, "")); }

    /*! /etc/default/earlyoom as the desktop writes it. */
    function fileText(config: var): string {
        return [root.marker,
                "# earlyoom's options (man earlyoom), kept by the desktop's task manager:",
                "# its RAM tab rewrites this file, and install.sh leaves it alone.",
                `EARLYOOM_ARGS="${EarlyOomArgs.format(config)}"`, ""].join("\n");
    }

    /*! EARLYOOM_ARGS out of the file: the last assignment, unquoted. */
    function readArgs(text: string): string {
        let args = "";
        for (const line of text.split("\n")) {
            const m = /^\s*EARLYOOM_ARGS=(.*)$/.exec(line);
            if (m)
                args = m[1].trim().replace(/^"(.*)"$/, "$1").replace(/^'(.*)'$/, "$1").replace(/\\(["\\])/g, "$1");
        }
        return args;
    }

    /*! Writes the config and restarts earlyoom, as root, in one go. */
    function apply(config: var): void {
        if (applier.running)
            return;
        root.failure = "";
        root.pending = true;
        applier.command = ["pkexec", "sh", "-c",
            `printf '%s' "$1" > ${root.configFile}.new && mv -f ${root.configFile}.new ${root.configFile}`
            + " && systemctl enable --now earlyoom.service && systemctl restart earlyoom.service",
            "sh", root.fileText(config)];
        applier.running = true;
    }

    /*! One journal entry (`journalctl -o json`): a kill, its escalation, or
        anything else, which may be systemd starting or stopping it. A kill
        logged at or after `since` happened while the shell watched. */
    function readEntry(json: string, since: real): void {
        let entry;
        try {
            entry = JSON.parse(json);
        } catch (e) {
            return;
        }
        const message = typeof entry.MESSAGE === "string" ? entry.MESSAGE : "";
        const time = Math.floor(Number(entry.__REALTIME_TIMESTAMP) / 1000);
        const sent = /^sending (SIGTERM|SIGKILL) to process (\d+) uid (\d+) "(.*)": .*VmRSS (\d+) MiB/.exec(message);
        if (sent) {
            const kill = { time, pid: Number(sent[2]), uid: Number(sent[3]), name: sent[4],
                           signal: sent[1], rss: Number(sent[5]) };
            root.kills = [kill].concat(root.kills).slice(0, root.maxKills);
            if (time >= since)
                root.notify(kill);
        } else if (message.startsWith("escalating to SIGKILL") && root.kills.length > 0) {
            root.kills = [Object.assign({}, root.kills[0], { signal: "SIGKILL" })].concat(root.kills.slice(1));
        } else {
            settle.restart();
        }
    }

    function notify(kill: var): void {
        Quickshell.execDetached(["notify-send", "-a", "earlyoom", "-u", "critical", "-i", "dialog-warning",
            qsTr("Memory was running out"),
            qsTr("%1 was stopped to keep the system responsive (%2 MiB).").arg(kill.name).arg(kill.rss)]);
    }

    FileView {
        path: root.unitFile
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onLoaded: root.available = true
        onLoadFailed: root.available = false
    }

    FileView {
        path: root.configFile
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onLoaded: root.args = root.readArgs(this.text())
        onLoadFailed: root.args = ""
    }

    Process {
        id: follower

        property real since: 0

        running: root.available
        command: ["journalctl", "-u", "earlyoom.service", "-f", "-n", "200", "-o", "json",
                  "--output-fields=MESSAGE"]
        stdout: SplitParser { onRead: line => root.readEntry(line, follower.since) }
        stderr: SplitParser {
            onRead: line => {
                if (line.includes("insufficient permissions") || line.includes("not seeing messages"))
                    root.logReadable = false;
            }
        }
        onRunningChanged: if (follower.running) {
            follower.since = Date.now();
            root.kills = [];
            root.logReadable = true;
            status.run();
        }
    }

    Timer {
        id: settle
        interval: root.settleTime
        onTriggered: status.run()
    }

    Probe {
        id: status
        command: ["systemctl", "is-active", "earlyoom.service"]
        stdout: StdioCollector { onStreamFinished: root.running = this.text.trim() === "active" }
    }

    Process {
        id: applier
        onExited: code => {
            root.pending = false;
            // pkexec: 126 for a prompt dismissed, 127 for no authorization.
            if (code === 126 || code === 127)
                root.failure = qsTr("Not applied: no authorization");
            else if (code !== 0)
                root.failure = qsTr("Could not apply");
            status.run();
        }
    }
}
