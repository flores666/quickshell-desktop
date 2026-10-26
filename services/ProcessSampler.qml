pragma ComponentBehavior: Bound

import Quickshell.Io

/*!
    The one run behind a Processes sample: `df` for the root filesystem, then
    one gawk over /proc and /sys, printing a line a reading, a field a tab,
    for `Processes.parse`.

    Every path is a glob or a file that may be missing, unreadable (another
    user's /proc/<pid>/io) or gone by the time it is read (a process ended):
    such a file is skipped, never the run. A machine without a GPU, a disk or
    cpufreq prints no such line.

    What it reads: each process's stat, status, OOM score and io; uptime, the
    CPU lines of stat, meminfo and /etc/passwd's names; the CPUs' current
    frequency; each whole disk's size and model in /sys/block, and its
    counters in diskstats — not a loop, zram, ram or optical drive, nor a
    layer over other disks (dm, md), whose I/O would count twice; each
    interface with a device behind it, in net/dev, which leaves out lo and the
    tunnels; and the first card in /sys/class/drm that reports
    gpu_busy_percent, with its VRAM, its temperature and its PCI slot.
*/
Probe {
    id: root

    /*! What one run printed. */
    signal read(string text)

    command: ["sh", "-c", "cd /proc && df -kP / | gawk \"$0\" - uptime stat meminfo /etc/passwd "
        + "/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq "
        + "/sys/block/*/size /sys/block/*/device/model diskstats /sys/class/net/*/device/uevent net/dev "
        + "/sys/class/drm/card[0-9]*/device/gpu_busy_percent /sys/class/drm/card[0-9]*/device/mem_info_vram_used "
        + "/sys/class/drm/card[0-9]*/device/mem_info_vram_total /sys/class/drm/card[0-9]*/device/uevent "
        + "/sys/class/drm/card[0-9]*/device/hwmon/hwmon*/temp1_input "
        + "[0-9]*/stat [0-9]*/status [0-9]*/oom_score [0-9]*/oom_score_adj [0-9]*/io", root.program]
    stdout: StdioCollector { onStreamFinished: root.read(this.text) }

    // The path is taken apart once a file, a process's files, which are
    // nearly every record, meet their rule first, and status is left once
    // VmRSS is read (Uid comes before it). ENDFILE is there for what
    // it does by being there: with one, a read failing part way (a process
    // gone, a GPU asleep) ends that file, where without one gawk stops.
    readonly property string program: `
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
        FILENAME == "-" { if (FNR == 2) print "fs\\t" $2 "\\t" $3; next }
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
            for (pid in name)
                if (pid in uid)
                    print "p\\t" pid "\\t" uid[pid] "\\t" ppid[pid] "\\t" ticks[pid] "\\t" rss[pid] + 0 \\
                        "\\t" score[pid] + 0 "\\t" adj[pid] + 0 "\\t" (pid in rb ? rb[pid] : -1) \\
                        "\\t" (pid in wb ? wb[pid] : -1) "\\t" name[pid]
        }`
}
