pragma ComponentBehavior: Bound

import QtQuick
import "root:/services"

/* The real sampler program with NVIDIA's command supplied by a fixture:
   units, PCI domains, unsupported fields and a missing or failing driver.
   A sysfs GPU keeps priority. No fixture reaches the machine's driver. */
Item {
    id: root

    Check { id: check }

    property int index: 0
    readonly property var fixtures: [
        { name: "NVIDIA: the first GPU, even idle", text: "00000000:01:00.0, 0, 623, 8188, 50\n"
              + "00000000:02:00.0, 90, 1024, 16384, 70", expected:
              { slot: "0000:01:00.0", busy: 0, vramUsed: 623 * 1048576, vramTotal: 8188 * 1048576, temp: 50 } },
        { name: "NVIDIA: a four-digit domain and optional readings", text: "0000:0A:00.0, 37, [N/A], [N/A], [N/A]",
          expected: { slot: "0000:0a:00.0", busy: 37, vramUsed: 0, vramTotal: 0, temp: -1 } },
        { name: "NVIDIA: unavailable VRAM usage hides the capacity", text: "00000000:01:00.0, 10, [N/A], 8188, 50",
          expected: { slot: "0000:01:00.0", busy: 10, vramUsed: 0, vramTotal: 0, temp: 50 } },
        { name: "NVIDIA: unsupported utilization is absent", text: "00000000:01:00.0, [N/A], 623, 8188, 50",
          expected: null },
        { name: "NVIDIA: invalid utilization is absent", text: "00000000:01:00.0, 101, 623, 8188, 50",
          expected: null },
        { name: "NVIDIA: an error is absent", text: "Failed to initialize NVML: Driver/library version mismatch",
          expected: null },
        { name: "NVIDIA: a failed driver is absent", text: "", status: 1, expected: null },
        { name: "NVIDIA: a missing command is absent", text: "", missing: true, expected: null },
        { name: "sysfs keeps priority", text: "00000000:01:00.0, 30, 623, 8188, 50",
          setup: 'gpu = "card0"; slot[gpu] = "0000:04:00.0"; busy[gpu] = 12; '
              + 'drm[gpu, "mem_info_vram_used"] = 1024; drm[gpu, "mem_info_vram_total"] = 2048; temp[gpu] = 56000',
          expected: { slot: "0000:04:00.0", busy: 12, vramUsed: 1024, vramTotal: 2048, temp: 56 } }
    ]

    // Positional arguments keep the fixture and the real program out of
    // shell syntax. PATH holds only the fixture, so no NVIDIA tool escapes it.
    readonly property string script: `
        work=$(mktemp -d) || exit 1
        trap 'rm -rf "$work"' EXIT
        sampler_awk=$(command -v gawk) || exit 1
        if [ "$4" != missing ]; then
            printf '%s\n' '#!/bin/sh' '[ "$TEST_GPU_STATUS" = 0 ] || exit "$TEST_GPU_STATUS"' \
                'printf "%s\\n" "$TEST_GPU"' > "$work/nvidia-smi"
            chmod +x "$work/nvidia-smi"
        fi
        PATH="$work" TEST_GPU="$1" TEST_GPU_STATUS="$2" "$sampler_awk" "$3" <<'SAMPLE'
Filesystem 1024-blocks Used Available Capacity Mounted
/dev/test 100 25 75 25% /
SAMPLE
    `

    ProcessSampler {
        id: sampler

        command: []
        onRead: text => {
            const fixture = root.fixtures[root.index];
            const sample = sampler.parse(text);
            check.equal(fixture.name, JSON.stringify(sample.gpu), JSON.stringify(fixture.expected));
            check.equal(fixture.name + ": the rest of the sample survives", sample.fs?.used, 25 * 1024);
            root.index++;
            Qt.callLater(root.next);
        }
    }

    function next(): void {
        if (root.index === root.fixtures.length) {
            check.done();
            return;
        }
        const fixture = root.fixtures[root.index];
        sampler.command = ["sh", "-c", root.script, "gpu-sampler-test", fixture.text,
                           String(fixture.status ?? 0), sampler.program + "\nBEGIN { " + (fixture.setup ?? "") + " }",
                           fixture.missing ? "missing" : "present"];
        sampler.run();
    }

    Component.onCompleted: root.next()
}
