"""Private command/backend fixtures for the QML regression suites.

The runner gives each suite its own TEST_BIN. Service copies change only the
backend boundary and expose a process for event-based waits; their logic is
read from the branch under test, never reimplemented here.
"""
import os
from pathlib import Path
import sys

directory = Path(os.environ["TEST_BIN"])
source = Path(__file__).resolve().parent.parent


def command(name, body):
    path = directory / name
    path.write_text(body)
    path.chmod(0o755)


def service(name, replacement=""):
    text = (source / "services" / f"{name}.qml").read_text()
    text = text.replace("pragma Singleton\n", "")
    text = text.replace("Singleton {", "Scope {", 1)
    if name == "Bt":
        text = text.replace(
            "readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter",
            "property QtObject adapter: null",
        )
    else:
        text = text.replace("import QtQuick", 'import "root:/services"\nimport QtQuick')
        text = text.replace("id: root", "id: root\n" + replacement, 1)
    path = directory / f"{name}Fixture.qml"
    path.write_text(text)
    print(path.as_uri())


if sys.argv[1] == "lock":
    # Only a dedicated nested session may exercise the real session-lock
    # protocol. Authentication uses a private PAM stack, never the user's.
    if os.environ.get("TEST_LOCK_SESSION") != "1":
        raise RuntimeError("Set TEST_LOCK_SESSION=1 only in an isolated compositor")
    pam = directory / "pam"
    pam.mkdir()
    (pam / "permit").write_text("auth required pam_permit.so\n")
    (pam / "deny").write_text("auth required pam_deny.so\n")
    os.mkfifo(directory / "background-control")
    command("lock-background", '''#!/usr/bin/env python3
import hashlib, os, pathlib
with (pathlib.Path(os.environ["TEST_BIN"]) / "background-control").open() as control:
    control.read()
hashlib.pbkdf2_hmac("sha256", b"background work", b"fixture", 10000)
print("completed", flush=True)
''')
    text = (source / "modules/lock/Lock.qml").read_text()
    text = text.replace('import QtQuick', 'import "root:/modules/lock"\nimport QtQuick', 1)
    text = text.replace("id: root", "id: root\n    property alias sessionLock: lock\n"
                        "    property alias authentication: pam\n    property alias lockIntent: state\n"
                        "    property var surfaces: []", 1)
    text = text.replace('config: "login"', 'config: "permit"\n        configDirectory: '
                        + repr(str(pam)).replace("'", '"'))
    text = text.replace("id: surface", "id: surface\n            property alias content: lockContent\n"
                        "            Component.onCompleted: root.surfaces = root.surfaces.concat([surface])", 1)
    text = text.replace("LockContent {", "LockContent {\n                id: lockContent", 1)
    path = directory / "LockFixture.qml"
    path.write_text(text)
    print(path.as_uri())
elif sys.argv[1] == "bluetooth":
    service("Bt")
elif sys.argv[1] == "v2rayn":
    service("V2rayn", "property alias modeProbe: modeReader")
    for i in range(1, 6):
        os.mkfifo(directory / f"response-{i}")
    command("curl", '''#!/usr/bin/env python3
import os, pathlib, sys
p = pathlib.Path(os.environ["TEST_BIN"])
if not sys.argv[-1].endswith("/configs"):
    print("7 000 0")
    sys.exit(0)
counter = p / "sequence"
n = int(counter.read_text()) + 1 if counter.exists() else 1
counter.write_text(str(n))
(p / ("requested-" + str(n))).write_text(sys.argv[-1])
with (p / ("response-" + str(n))).open() as response:
    print(response.read(), flush=True)
''')
elif sys.argv[1] == "nightlight":
    os.mkfifo(directory / "backend-control")
    for i in range(1, 13):
        os.mkfifo(directory / f"reply-{i}")
    command("hyprsunset", '''#!/usr/bin/env python3
import os, pathlib, sys
p = pathlib.Path(os.environ["TEST_BIN"])
counter = p / "daemon-sequence"
n = int(counter.read_text()) + 1 if counter.exists() else 1
counter.write_text(str(n))
(p / ("daemon-pid-" + str(n))).write_text(str(os.getpid()) + chr(10))
(p / ("started-" + str(n))).write_text(" ".join(sys.argv[1:]) + chr(10) + os.environ["XDG_CONFIG_HOME"])
with os.fdopen(os.open(p / "backend-control", os.O_RDWR)) as control:
    for line in control:
        if line.strip() == "exit":
            sys.exit(1)
        if line.strip() == "ready":
            print("[LOG] hyprsunset socket started at private fixture", flush=True)
''')
    command("hyprctl", '''#!/usr/bin/env python3
import os, pathlib, signal, sys
if len(sys.argv) < 2 or sys.argv[1] != "hyprsunset":
    os.execv("/usr/bin/hyprctl", sys.argv)
# Simulate a callback arriving after cancellation and a backend replacement.
signal.signal(signal.SIGTERM, lambda *_: None)
p = pathlib.Path(os.environ["TEST_BIN"])
counter = p / "write-sequence"
n = int(counter.read_text()) + 1 if counter.exists() else 1
counter.write_text(str(n))
(p / ("request-" + str(n))).write_text(" ".join(sys.argv[2:]))
with (p / ("reply-" + str(n))).open() as reply:
    print(reply.read(), flush=True)
''')
    command("hyprsunset-unavailable", "#!/bin/sh\nexit 127\n")
elif sys.argv[1] == "screenshot":
    command("xdg-user-dir", '#!/bin/sh\nprintf "%s\\n" "$TEST_BIN/pictures"\n')
    command("date", '#!/bin/sh\nprintf "2026-01-01_12-00-00\\n"\n')
    command("grim", '''#!/bin/sh
for f do :; done
printf 'completed image\n' > "$f"
''')
    command("wl-copy", '#!/bin/sh\ncat > /dev/null\n')
    command("notify-send", '#!/bin/sh\nprintf "%s\\n" "$6" >> "$TEST_BIN/saved"\n')
elif sys.argv[1] == "backdrop":
    import struct
    import zlib

    def chunk(name, data):
        return struct.pack(">I", len(data)) + name + data + struct.pack(">I", zlib.crc32(name + data))

    width, height = 1024, 512
    rows = b"".join(b"\0" + bytes((x + y) % 256 for x in range(width * 3)) for y in range(height))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")
    path = directory / "wallpaper.png"
    path.write_bytes(png)
    print(path)
elif sys.argv[1] == "power-profile":
    # Preserve production service/actions, replacing only its external profile
    # registry. This fixture never probes or writes the machine's system bus.
    os.mkfifo(directory / "power-events")
    command("gdbus", '''#!/bin/sh
exec 3<> "$TEST_BIN/power-events"
while IFS= read -r line <&3; do
    [ "$line" = exit ] && exit 0
    printf '%s\\n' "$line"
done
''')
    text = (source / "services/Power.qml").read_text()
    text = text[:text.index("    readonly property UPowerDevice")] + text[
        text.index("    /*! The bus owner"):text.index("    // ---------------------------------------------------------- charge limit")]
    text = text.replace("pragma Singleton\n", "")
    text = text.replace("Singleton {", "Scope {", 1)
    text = text.replace("id: root", "id: root\n    property QtObject backend", 1)
    text = text.replace("PowerProfiles.", "root.backend.") + "}\n"
    path = directory / "PowerFixture.qml"
    path.write_text(text)
    print(path.as_uri())
    text = (source / "modules/panels/qs/PowerProfilePage.qml").read_text()
    text = text.replace("id: root", "id: root\n    required property QtObject power", 1)
    text = text.replace("Power.", "root.power.").replace("target: Power", "target: root.power")
    path = directory / "PowerProfileFixture.qml"
    path.write_text(text)
    print(path.as_uri())
else:
    raise ValueError(sys.argv[1])
