"""Rendered native acceptance checks, only in tools/test.sh's nested session.

No state polling: wait for the window-open socket event; subsequent waits
are single animation settles or finite, deliberately timed frame samples.
"""
import json
import os
from pathlib import Path
import select
import shlex
import socket
import subprocess
import time

results = []
directory = Path(os.environ["TEST_BIN"])
source = Path(__file__).resolve().parent
address = ""
shadows = {}


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=5).strip()


def ctl(code):
    return run("hyprctl", "eval", code)


def report(name, ok, detail=""):
    results.append(dict(name=name, ok=bool(ok), detail=str(detail)))


def clients():
    return json.loads(run("hyprctl", "-j", "clients"))


def client():
    return next((c for c in clients() if c["address"] == address), None)


def action(name):
    return ctl('hl.dispatch(hl.dsp.window.' + name + '({window="address:' + address + '"}))')


def restore():
    run("qs", "-p", str(source.parent / "shell.qml"), "ipc", "call", "windowAnimation", "restore", address[2:])


def capture(name, delay=0):
    if delay:
        time.sleep(delay)
    path = directory / (name + ".png")
    subprocess.run(["grim", "-o", "ANIM-1", str(path)], check=True, timeout=3, stderr=subprocess.PIPE)
    data = subprocess.check_output(["magick", str(path), "-depth", "8", "rgb:-"], timeout=3)
    shadows[name] = sum(g > r + 20 and g > b + 20 for r, g, b in zip(data[::3], data[1::3], data[2::3]))
    color = bytes((224, 20, 207))
    rows = []
    for y in range(800):
        row = data[y * 1280 * 3:(y + 1) * 1280 * 3]
        left, right = row.find(color), row.rfind(color)
        if left >= 0:
            rows.append((y, left // 3, right // 3 + 1))
    return data.count(color), rows


def tapered(rows):
    if len(rows) < 40:
        return False
    # Ignore rounded corners and the final antialiased edge.
    top = rows[len(rows) // 4]
    bottom = rows[3 * len(rows) // 4]
    return top[2] - top[1] > 1.25 * (bottom[2] - bottom[1])


def click(button, window, width, height):
    bar = json.loads(run("hyprctl", "-j", "getoption", "plugin:windows:height"))["int"]
    inset = json.loads(run("hyprctl", "-j", "getoption", "plugin:windows:button_inset"))["int"]
    size = json.loads(run("hyprctl", "-j", "getoption", "plugin:windows:button_size"))["int"]
    gap = json.loads(run("hyprctl", "-j", "getoption", "plugin:windows:button_gap"))["int"]
    x = window["at"][0] + inset + button * (size + gap) + size / 2
    y = window["at"][1] - bar / 2
    run(str(directory / "window-pointer"), str(round(x)), str(round(y)), str(width), str(height), "1")


try:
    monitors = json.loads(run("hyprctl", "-j", "monitors"))
    if not directory.is_dir() or not any(m["name"] == "ANIM-1" for m in monitors):
        raise RuntimeError("requires runner isolation and nested ANIM-1 output; refusing to affect the user's compositor")
    width = max(m["x"] + m["width"] for m in monitors)
    height = max(m["y"] + m["height"] for m in monitors)
    flags = shlex.split(run("pkg-config", "--cflags", "--libs", "wayland-client"))
    subprocess.run(["cc", str(source / "WindowPointer.c"), "-o", str(directory / "window-pointer"), *flags], check=True, stderr=subprocess.PIPE)
    ctl('hl.config({animations={enabled=true}}); hl.dispatch(hl.dsp.focus({workspace=1}))')
    ctl('if hl.get_config("plugin.windows.minimize_duration") then hl.config({["plugin.windows.minimize_duration"]=900}) end')
    ctl('hl.config({decoration={shadow={color="rgba(00ff00cc)"}}})')
    event_socket = socket.socket(socket.AF_UNIX)
    event_socket.connect(str(Path(os.environ["XDG_RUNTIME_DIR"], "hypr", os.environ["HYPRLAND_INSTANCE_SIGNATURE"], ".socket2.sock")))
    argv = ["env", "KITTY_CACHE_DIRECTORY=" + str(directory / "kitty"), "kitty", "--config", "NONE",
            "--class", "qs-genie-acceptance", "--title", "Genie acceptance",
            "--override", "background=#e014cf", "--override", "initial_window_width=640",
            "--override", "initial_window_height=400", "--override", "remember_window_size=no",
            "--override", "cursor_blink_interval=0", "--override", "confirm_os_window_close=0", "cat"]
    ctl("hl.dispatch(hl.dsp.exec_cmd(" + json.dumps(shlex.join(argv)) + "))")
    pending = ""
    deadline = time.monotonic() + 4
    while not address:
        if not select.select([event_socket], [], [], max(0, deadline - time.monotonic()))[0]:
            raise RuntimeError("test kitty did not map")
        pending += event_socket.recv(65536).decode()
        lines = pending.split("\n")
        pending = lines.pop()
        for line in lines:
            if line.startswith("openwindow>>") and ",qs-genie-acceptance," in line:
                address = "0x" + line.split(">>")[1].split(",")[0]
    event_socket.close()
    before, _ = capture("before", 0.7)
    original = client()
    report("fixture window is drawn before input", before > 50000, before)
    if before <= 50000:
        raise RuntimeError("invalid visual fixture")

    click(1, original, width, height)
    report("real minimize button keeps the hidden-workspace action", client()["workspace"]["name"] == "special:minimized")
    middle, rows = capture("minimize-middle", 0.30)
    report("minimize retains a visible intermediate window image", 1000 < middle < before * 0.98, middle)
    report("minimize tapers toward the dock instead of uniformly scaling", tapered(rows), rows[::100])
    report("minimize carries the window shadow", shadows["minimize-middle"] > 200, shadows["minimize-middle"])
    gone, _ = capture("minimize-done", 0.65)
    report("finished minimize leaves no window image", gone == 0, gone)

    restore()
    middle, rows = capture("restore-middle", 0.30)
    report("dock restore has a visible intermediate image", 1000 < middle < before * 0.98, middle)
    report("dock restore reverses the Genie taper", tapered(rows), rows[::100])
    report("restore carries the window shadow", shadows["restore-middle"] > 200, shadows["restore-middle"])
    restored, _ = capture("restore-done", 0.65)
    current = client()
    report("restore returns to the saved floating box", current["at"] == original["at"] and current["size"] == original["size"])
    report("restore leaves exactly one complete image", abs(restored - before) < before * 0.02, restored)

    click(1, current, width, height)
    time.sleep(0.16)
    restore()
    reversed_count, _ = capture("reversed", 0.95)
    report("restoring during minimize leaves a live visible window", abs(reversed_count - before) < before * 0.02, reversed_count)
    report("reversal keeps the window's original mode", client()["floating"] and client()["fullscreen"] == 0)

    ctl('hl.config({animations={enabled=false}})')
    click(1, client(), width, height)
    disabled, _ = capture("disabled-minimize", 0.04)
    report("disabled animations retain no Genie image", disabled == 0, disabled)
    restore()
    disabled_restore, _ = capture("disabled-restore", 0.04)
    report("disabled restore immediately draws the full window", abs(disabled_restore - before) < before * 0.02, disabled_restore)
    ctl('hl.config({animations={enabled=true}})')

    click(1, client(), width, height)
    time.sleep(0.12)
    run("qs", "-p", str(source.parent / "shell.qml"), "ipc", "call", "windowAnimation", "close", address[2:])
    closed, _ = capture("closed-mid-genie", 1.0)
    report("close during Genie still closes the actual client", client() is None)
    report("close during Genie releases its retained image", closed == 0, closed)
    layers = json.loads(run("hyprctl", "-j", "layers"))
    namespaces = [layer["namespace"] for monitor in layers.values()
                  for group in monitor.get("levels", {}).values() for layer in group]
    report("motion adds no input-taking animation surface", all(n.startswith("shell-dock") for n in namespaces), namespaces)
except Exception as error:
    report("rendered fixture completed", False, repr(error))
finally:
    if address:
        try:
            action("close")
        except Exception:
            pass
    print(json.dumps(results))
