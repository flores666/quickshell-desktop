import QtQuick
import "root:/services"

/*!
    The machine's usage (Usage): rates worked out between two samples, read
    always — no watch — so the readings of the last minute are there for
    the charts whenever one opens, and the sizes and rates written as the
    task manager writes them.
*/
Item {
    id: root

    Check {
        id: check
    }

    Until {
        id: until
    }

    function same(name: string, actual: var, expected: var): void {
        check.equal(name, JSON.stringify(actual), JSON.stringify(expected));
    }

    function disk(name: string, read: real, written: real, ioTicks: real): var {
        return { name, model: "", size: 1e12, read, written, ioTicks };
    }

    readonly property var memory: ({ total: 16000000, available: 4000000, anon: 0, swapTotal: 0, swapFree: 0 })

    readonly property var previous: ({
        uptime: 100, cpuTicks: { busy: 1000, total: 10000 }, memory: root.memory,
        disks: [root.disk("nvme0n1", 0, 0, 1000), root.disk("sda", 0, 0, 500)],
        nets: [{ name: "wlan0", rx: 1000, tx: 500 }, { name: "eth0", rx: 0, tx: 0 }],
        gpu: { slot: "0000:04:00.0", busy: 30, vramUsed: 0, vramTotal: 0, temp: -1 }
    })

    readonly property var current: ({
        uptime: 102, cpuTicks: { busy: 1060, total: 10240 }, memory: root.memory,
        disks: [root.disk("nvme0n1", 2097152, 409600, 1500), root.disk("sda", 0, 8192, 1300),
                root.disk("sdb", 4096, 4096, 2000)],
        nets: [{ name: "wlan0", rx: 21000, tx: 2500 }, { name: "eth0", rx: 4000, tx: 0 }],
        gpu: { slot: "0000:04:00.0", busy: 42, vramUsed: 0, vramTotal: 0, temp: -1 }
    })

    Component.onCompleted: {
        check.attempt("rates", () => {
            root.same("rates: between two samples", Usage.rates(root.previous, root.current), {
                cpu: 25, gpu: 42, disk: 40, diskRead: 1048576, diskWrite: 208896, netDown: 12000, netUp: 1000, memory: 75
            });
            root.same("rates: none from one sample but memory", Usage.rates(null, root.current), {
                cpu: -1, gpu: -1, disk: -1, diskRead: -1, diskWrite: -1, netDown: -1, netUp: -1, memory: 75
            });
            const third = Object.assign({}, root.current, { uptime: 105, cpuTicks: { busy: 1061, total: 10243 } });
            check.equal("rates: CPU to a tenth", Usage.rates(root.current, third).cpu, 33.3);
            const bare = { uptime: 105, cpuTicks: root.current.cpuTicks, memory: null, disks: [], nets: [], gpu: null };
            root.same("rates: what a machine lacks is -1", Usage.rates(root.current, bare), {
                cpu: -1, gpu: -1, disk: -1, diskRead: -1, diskWrite: -1, netDown: -1, netUp: -1, memory: -1
            });
            const reset = Object.assign({}, root.current, { uptime: 104, nets: [{ name: "wlan0", rx: 0, tx: 0 }] });
            check.equal("rates: a counter that went back counts nothing", Usage.rates(root.current, reset).netDown, 0);
        });

        check.attempt("trim", () => {
            const points = [{ t: 10, v: 1 }, { t: 39, v: 2 }, { t: 40, v: 3 }, { t: 100, v: 4 }];
            root.same("trim: only the span before the newest", Usage.trim(points, 100, 60),
                [{ t: 40, v: 3 }, { t: 100, v: 4 }]);
        });

        check.attempt("format", () => {
            root.same("formatBytes", [0, 512, 2048, 5 * 1048576, 1.5 * 1073741824, 2 * 1099511627776].map(Usage.formatBytes),
                ["0 B", "512 B", "2 KiB", "5 MiB", "1.5 GiB", "2.0 TiB"]);
            root.same("formatRate", [0, 512, 512 * 1024, 12.3 * 1048576, -1].map(Usage.formatRate),
                ["0 B/s", "512 B/s", "512 KiB/s", "12.3 MiB/s", "–"]);
            check.equal("the GPU's name: lspci's device field", Usage.deviceName(
                '04:00.0 "VGA compatible controller" "Advanced Micro Devices, Inc. [AMD/ATI]" "Barcelo" -rc2 -p00 "Lenovo" "Device 3802"\n'),
                "Barcelo");
        });

        check.attempt("cpuinfo", () => {
            const cpu = n => ["processor\t: " + n, "model name\t: AMD Ryzen 5 5625U with Radeon Graphics",
                              "physical id\t: 0", "core id\t\t: " + (n >> 1), "cpu cores\t: 2", ""].join("\n");
            root.same("cpuinfo: model, cores by core id, threads", Usage.cpuInfo([0, 1, 2, 3].map(cpu).join("\n")),
                { model: "AMD Ryzen 5 5625U with Radeon Graphics", cores: 2, threads: 4 });
            const socket = n => ["processor\t: " + n, "model name\t: Xeon", "physical id\t: " + (n >> 2),
                                 "cpu cores\t: 4", ""].join("\n");
            root.same("cpuinfo: without core ids, cores a socket times sockets",
                Usage.cpuInfo([0, 1, 2, 3, 4, 5, 6, 7].map(socket).join("\n")), { model: "Xeon", cores: 8, threads: 8 });
            root.same("cpuinfo: what it does not say is empty",
                Usage.cpuInfo("processor\t: 0\nBogoMIPS\t: 48.00\n\nprocessor\t: 1\n"), { model: "", cores: 0, threads: 2 });
        });

        let live = false;
        check.attempt("live", () => {
            check.equal("before two samples: no reading", Usage.cpu, -1);
            check.equal("before a sample: no history", Usage.history.cpu.length, 0);
            until.bound = 3000;
            until.until(Usage.cpuChanged, () => Usage.cpu >= 0, read => root.read(read));
            live = true;
        });
        if (!live)
            check.done();
    }

    function read(read: bool): void {
        check.report("live: CPU after two samples, with nothing watching", read && Usage.cpu <= 100
            && !Processes.watched, Usage.cpu + (Processes.watched ? ", watched" : ""));
        check.report("live: memory", Usage.memory > 0 && Usage.memory < 100, String(Usage.memory));
        check.report("live: the CPU's model, cores and threads, read once",
            Usage.cpuModel !== "" && Usage.cpuThreads > 0 && Usage.cpuCores > 0 && Usage.cpuCores <= Usage.cpuThreads,
            JSON.stringify([Usage.cpuModel, Usage.cpuCores, Usage.cpuThreads]));
        check.report("live: memory's facts", Usage.memoryUsed > 0 && Usage.memoryUsed < Usage.memoryTotal,
            Usage.memoryUsed + " of " + Usage.memoryTotal);
        check.report("live: the root filesystem", Usage.fsUsed > 0 && Usage.fsUsed < Usage.fsTotal,
            Usage.fsUsed + " of " + Usage.fsTotal);
        const cpu = Usage.history.cpu;
        check.equal("live: a CPU point, at the newest sample", cpu[cpu.length - 1]?.t, Usage.now);
        check.equal("live: memory from the first sample on", Usage.history.memory.length, 2);
        check.equal("live: a GPU exactly when one reports busy", Usage.hasGpu, (Processes.last?.gpu ?? null) !== null);
        if (!Usage.hasGpu) {
            check.report("live: no GPU here, so no name asked", Usage.gpuName === "", Usage.gpuName);
            root.kept();
            return;
        }
        until.until(Usage.gpuNameChanged, () => Usage.gpuName !== "", named => {
            check.report("live: the GPU's name", named, "lspci said nothing");
            root.kept();
        });
    }

    /*! A watch begun and ended changes nothing of it: the history goes on
        from where it was. */
    function kept(): void {
        const points = Usage.history.cpu.length;
        Processes.watch("usage", true);
        Processes.watch("usage", false);
        // The watch's sample at once is a moment after the last: no rate is
        // said over so short a time; the next is a whole interval on.
        until.bound = Processes.sampleInterval * 2;
        until.until(Usage.historyChanged, () => Usage.history.cpu.length > points, more => {
            check.equal("a watch ended: the history goes on", more, true);
            check.equal("a watch ended: a reading still", Usage.cpu >= 0 && Usage.memory > 0, true);
            check.equal("no two points closer than the least span", Usage.history.cpu.every(
                (p, i, all) => i === 0 || p.t - all[i - 1].t >= Usage.least), true);
            check.done();
        });
    }
}
