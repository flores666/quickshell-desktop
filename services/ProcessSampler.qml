pragma ComponentBehavior: Bound

import Quickshell.Io

/*!
    The one run behind a Processes sample: `df` for the root filesystem, then
    one gawk over /proc and /sys, printing a line a reading, a field a tab,
    which `parse` reads back.

    Every path is a glob or a file that may be missing, unreadable (another
    user's /proc/<pid>/io) or gone by the time it is read (a process ended):
    such a file is skipped, never the run. A machine without a GPU, a disk or
    cpufreq prints no such line.

    What it reads: with `processes`, each process's stat, status, OOM score
    and io, and /etc/passwd's names; always uptime, the CPU lines of stat,
    meminfo, the CPUs' current
    frequency; each whole disk's size and model in /sys/block, and its
    counters in diskstats — not a loop, zram, ram or optical drive, nor a
    layer over other disks (dm, md), whose I/O would count twice; each
    interface with a device behind it, in net/dev, which leaves out lo and the
    tunnels; and the first card in /sys/class/drm that reports
    gpu_busy_percent, with its VRAM, its temperature and its PCI slot.

    The extras, each only when asked and only of the user's own processes
    (another's fd directory is unreadable): one `find` over the fd links
    hands gawk those to /dev/dri, whose fdinfo gives each DRM client's engine
    time (gfx and compute, amdgpu's names), a client counted once a process;
    and those to sockets, matched by inode against the inet sockets in
    /proc/net's tcp, tcp6 (not listening), udp and udp6.
*/
Probe {
    id: root

    /*! Whether a run reads each process too, and the users' names: taken
        as it starts. Without, it reads the machine's counters alone. */
    property bool processes: true
    /*! Whether it reads each own process's GPU time, and its open inet
        sockets: only with `processes`. */
    property bool gpu: false
    property bool net: false

    readonly property bool links: root.processes && (root.gpu || root.net)
    readonly property bool sockets: root.processes && root.net

    /*! What one run printed. */
    signal read(string text)

    command: ["sh", "-c", "cd /proc && { df -kP /; " + (root.links ? root.find : "") + "} | gawk \"$0\" - "
        + (root.sockets ? "net/tcp net/tcp6 net/udp net/udp6 " : "") + "uptime stat meminfo "
        + "/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq "
        + "/sys/block/*/size /sys/block/*/device/model diskstats /sys/class/net/*/device/uevent net/dev "
        + "/sys/class/drm/card[0-9]*/device/gpu_busy_percent /sys/class/drm/card[0-9]*/device/mem_info_vram_used "
        + "/sys/class/drm/card[0-9]*/device/mem_info_vram_total /sys/class/drm/card[0-9]*/device/uevent "
        + "/sys/class/drm/card[0-9]*/device/hwmon/hwmon*/temp1_input"
        + (root.processes ? " /etc/passwd [0-9]*/stat [0-9]*/status [0-9]*/oom_score [0-9]*/oom_score_adj [0-9]*/io" : ""),
        root.program]
    stdout: StdioCollector { onStreamFinished: root.read(this.text) }

    /*! The fd links asked for, a line each (`fd`, the pid's fd directory,
        the fd, the target), and with sockets each fd directory it can read
        (`fds`): one that holds none has none open, not none known. */
    readonly property string find: "find [0-9]*/fd -maxdepth 1 \\( "
        + (root.sockets ? "-name fd -readable -printf 'fds\\t%h\\n' -o " : "") + "\\( "
        + [root.gpu ? "-lname '/dev/dri/*'" : "", root.net ? "-lname 'socket:*'" : ""].filter(t => t !== "").join(" -o ")
        + " \\) -printf 'fd\\t%h\\t%f\\t%l\\n' \\) 2>/dev/null; "

    /*! A sample as it is printed, a field a tab: `{ uptime, cpus, uid,
        memory, users, list, cpuTicks: { busy, total }, cpuFreq, disks: [{
        name, model, size, read, written, ioTicks }], fs: { total, used },
        nets: [{ name, rx, tx }], gpu: { slot, busy, vramUsed, vramTotal, temp }
        }` — sizes in bytes, the frequency in MHz, io ticks in ms, the
        temperature in °C or -1. What the machine lacks is absent: no disks,
        `fs` or `gpu` null, `cpuFreq` 0. Each process's `gpuTime` (ns) is -1
        without a GPU client, its `connections` -1 unread. */
    function parse(text: string): var {
        const sample = { uptime: 0, cpus: 1, uid: -1, memory: null, users: {}, list: [],
                         cpuTicks: null, cpuFreq: 0, disks: [], fs: null, nets: [], gpu: null };
        const gpuTimes = {};
        const connections = {};
        for (const line of text.split("\n")) {
            const f = line.split("\t");
            const n = f.map(Number);
            switch (f[0]) {
            case "uptime": sample.uptime = n[1]; break;
            case "cpus": sample.cpus = Math.max(1, n[1]); break;
            case "uid": sample.uid = n[1]; break;
            case "user": sample.users[n[1]] = f[2]; break;
            case "mem":
                sample.memory = { total: n[1], available: n[2], anon: n[3], swapTotal: n[4], swapFree: n[5] };
                break;
            case "cpu": {
                // user nice system idle iowait irq softirq steal
                const total = n.slice(1, 9).reduce((sum, ticks) => sum + ticks, 0);
                sample.cpuTicks = { busy: total - n[4] - n[5], total };
                break;
            }
            case "freq": sample.cpuFreq = n[1]; break;
            case "fs": sample.fs = { total: n[1] * 1024, used: n[2] * 1024 }; break;
            case "disk":
                sample.disks.push({ name: f[1], model: f.slice(6).join("\t"), size: n[2] * 512,
                                    read: n[3] * 512, written: n[4] * 512, ioTicks: n[5] });
                break;
            case "net": sample.nets.push({ name: f[1], rx: n[2], tx: n[3] }); break;
            case "gpu":
                sample.gpu = { slot: f[1], busy: n[2], vramUsed: n[3], vramTotal: n[4],
                               temp: n[5] < 0 ? -1 : Math.round(n[5] / 100) / 10 };
                break;
            case "g": gpuTimes[n[1]] = n[2]; break;
            case "n": connections[n[1]] = n[2]; break;
            case "p": {
                const name = f.slice(10).join("\t");
                if (name !== "")
                    sample.list.push({ pid: n[1], uid: n[2], ppid: n[3], ticks: n[4], rss: n[5], oomScore: n[6],
                                       oomAdj: n[7], readBytes: n[8], writeBytes: n[9], gpuTime: -1,
                                       connections: -1, name });
                break;
            }
            }
        }
        for (const p of sample.list) {
            p.gpuTime = gpuTimes[p.pid] ?? -1;
            p.connections = connections[p.pid] ?? -1;
        }
        return sample;
    }

    // The path is taken apart once a file, a process's files, which are
    // nearly every record, meet their rule first, and status is left once
    // VmRSS is read (Uid comes before it). ENDFILE is there for what
    // it does by being there: with one, a read failing part way (a process
    // gone, a GPU asleep) ends that file, where without one gawk stops.
    // A DRM fd's fdinfo is left once its client is known to be counted.
    readonly property string program: `
        function client(pid, file,    line, f) {
            while ((getline line < file) > 0) {
                split(line, f)
                if (f[1] == "drm-client-id:") {
                    if ((pid, f[2]) in clients) break
                    clients[pid, f[2]] = 1
                    gputime[pid] += 0
                } else if (f[1] == "drm-engine-gfx:" || f[1] == "drm-engine-compute:") {
                    gputime[pid] += f[2]
                }
            }
            close(file)
        }
        BEGINFILE {
            if (ERRNO != "") nextfile
            split(FILENAME, path, "/")
            pid = path[1] ~ /^[0-9]/ ? path[1] : ""
        }
        ENDFILE {}
        pid != "" {
            if (path[2] == "stat") {
                from = index($0, "(")
                to = match($0, /\\)[^)]*$/)
                name[pid] = substr($0, from + 1, to - from - 1)
                split(substr($0, to + 2), f, " ")
                ppid[pid] = f[2]
                ticks[pid] = f[12] + f[13]
            } else if (path[2] == "status") {
                if ($1 == "Uid:") uid[pid] = $2
                else if ($1 == "VmRSS:") { rss[pid] = $2; nextfile }
            } else if (path[2] == "oom_score") {
                score[pid] = $1
            } else if (path[2] == "io") {
                if ($1 == "read_bytes:") rb[pid] = $2
                else if ($1 == "write_bytes:") wb[pid] = $2
            } else {
                adj[pid] = $1
            }
            next
        }
        FILENAME == "-" {
            if ($1 == "fd") {
                split($2, at, "/")
                if ($4 ~ /^socket:/) socket[at[1], substr($4, 9, length($4) - 9)] = 1
                else client(at[1], at[1] "/fdinfo/" $3)
            } else if ($1 == "fds") {
                fds[$2] = 1
            } else if (FNR == 2) {
                print "fs\\t" $2 "\\t" $3
            }
            next
        }
        path[1] == "net" && path[2] != "dev" {
            if (FNR > 1 && !(path[2] ~ /^tcp/ && $4 == "0A")) inet[$10] = 1
            next
        }
        FILENAME == "uptime" { print "uptime\\t" $1; next }
        FILENAME == "stat" {
            if ($1 == "cpu") print "cpu\\t" $2 "\\t" $3 "\\t" $4 "\\t" $5 "\\t" $6 "\\t" $7 "\\t" $8 "\\t" $9
            else if ($1 ~ /^cpu[0-9]/) cpus++
            next
        }
        FILENAME == "meminfo" { mem[$1] = $2; next }
        FILENAME == "/etc/passwd" { split($0, f, ":"); print "user\\t" f[3] "\\t" f[1]; next }
        FILENAME == "diskstats" {
            if ($3 in disk) print "disk\\t" $3 "\\t" disk[$3] "\\t" $6 "\\t" $10 "\\t" $13 "\\t" model[$3]
            next
        }
        FILENAME == "net/dev" { sub(/:/, " "); if ($1 in phys) print "net\\t" $1 "\\t" $2 "\\t" $10; next }
        path[2] == "sys" {
            if (path[3] == "block") {
                if (path[4] !~ /^(loop|zram|ram|sr|dm-|md)/) {
                    if (path[5] == "size") disk[path[4]] = $1
                    else { gsub(/^ +| +$/, ""); model[path[4]] = $0 }
                }
            } else if (path[3] == "devices") {
                freq += $1; freqs++
            } else if (path[4] == "net") {
                phys[path[5]] = 1
            } else if (path[5] ~ /^card[0-9]+$/) {
                card = path[5]
                if (path[7] == "uevent") { if (!sub(/^PCI_SLOT_NAME=/, "")) next; slot[card] = $0 }
                else if (path[7] == "gpu_busy_percent") { if (gpu == "") gpu = card; busy[card] = $1 }
                else if (path[7] == "hwmon") { if (!(card in temp)) temp[card] = $1 }
                else drm[card, path[7]] = $1
            }
            nextfile
        }
        END {
            print "cpus\\t" cpus
            print "uid\\t" PROCINFO["uid"]
            print "mem\\t" mem["MemTotal:"] "\\t" mem["MemAvailable:"] "\\t" mem["AnonPages:"] \\
                "\\t" mem["SwapTotal:"] "\\t" mem["SwapFree:"]
            if (freqs) print "freq\\t" int(freq / freqs / 1000 + 0.5)
            if (gpu != "")
                print "gpu\\t" slot[gpu] "\\t" busy[gpu] "\\t" drm[gpu, "mem_info_vram_used"] + 0 \\
                    "\\t" drm[gpu, "mem_info_vram_total"] + 0 "\\t" (gpu in temp ? temp[gpu] : -1)
            for (pid in gputime) print "g\\t" pid "\\t" gputime[pid]
            for (key in socket) { split(key, at, SUBSEP); if (at[2] in inet) conns[at[1]]++ }
            for (pid in fds) print "n\\t" pid "\\t" conns[pid] + 0
            for (pid in name)
                if (pid in uid)
                    print "p\\t" pid "\\t" uid[pid] "\\t" ppid[pid] "\\t" ticks[pid] "\\t" rss[pid] + 0 \\
                        "\\t" score[pid] + 0 "\\t" adj[pid] + 0 "\\t" (pid in rb ? rb[pid] : -1) \\
                        "\\t" (pid in wb ? wb[pid] : -1) "\\t" name[pid]
        }`
}
