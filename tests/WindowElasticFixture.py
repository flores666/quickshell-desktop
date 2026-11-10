"""Real pointer/renderer checks in the runner's private ELASTIC-1 compositor.

Wait for map events; timed waits below are bounded animation settles or finite
input/frame samples, never state polling. No input reaches the parent session.
"""
import json
import os
from pathlib import Path
import select
import re
import shlex
import socket
import subprocess
import sys
import time

results = []
directory = Path(os.environ["TEST_BIN"])
source = Path(__file__).resolve().parent
mode = sys.argv[1]
address = ""
pointer = None
keyboard = None
color = bytes((224, 20, 207))
color_pattern = re.compile(b"[\xdf\xe0][\x13\x14][\xce\xcf]")


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=5).strip()


def ctl(code):
    return run("hyprctl", "eval", code)


def report(name, ok, detail=""):
    results.append(dict(name=name, ok=bool(ok), detail=str(detail)))


def client():
    return next((c for c in json.loads(run("hyprctl", "-j", "clients")) if c["address"] == address), None)


def move(x, y, button=-1):
    pointer.stdin.write(f"{round(x)} {round(y)} 1280 800 {button}\n")
    pointer.stdin.flush()
    if pointer.stdout.readline().strip() != "ok":
        raise RuntimeError("virtual pointer disconnected")


def capture(name, delay=0):
    if delay:
        time.sleep(delay)
    path = directory / (name + ".png")
    subprocess.run(["grim", "-o", "ELASTIC-1", str(path)], check=True, timeout=3, stderr=subprocess.PIPE)
    data = subprocess.check_output(["magick", str(path), "-depth", "8", "rgb:-"], timeout=3)
    # The native and offscreen color pipelines can differ by one output LSB.
    data = color_pattern.sub(color, data)
    rows = []
    for y in range(800):
        row = data[y * 1280 * 3:(y + 1) * 1280 * 3]
        left, right = row.find(color), row.rfind(color)
        if left >= 0:
            rows.append((y, left // 3, right // 3 + 1))
    box = (min(r[1] for r in rows), rows[0][0], max(r[2] for r in rows), rows[-1][0] + 1) if rows else (0, 0, 0, 0)
    # Top-edge slope through the central half, clear of rounded corners.
    top = []
    for x in (round(box[0] + (box[2] - box[0]) * .3), round(box[0] + (box[2] - box[0]) * .7)):
        top.append(next((y for y in range(800) if data[(y * 1280 + x) * 3:(y * 1280 + x + 1) * 3] == color), 0))
    cyan = re.compile(b"[\x13\x14][\xb3\xb4][\xdf\xe0]")
    cyan_points = [m.start() // 3 for m in cyan.finditer(data)]
    return dict(count=data.count(color), box=box, width=box[2] - box[0], tilt=top[1] - top[0],
                background=len(cyan_points), background_x=min((p % 1280 for p in cyan_points), default=1280))


def drag_path(x, y, delta):
    for i in range(1, 13):
        move(x + delta * i / 12, y)
        time.sleep(.008)


try:
    monitors = json.loads(run("hyprctl", "-j", "monitors"))
    if not directory.is_dir() or not any(m["name"] == "ELASTIC-1" and m["width"] == 1280 and m["height"] == 800 for m in monitors):
        raise RuntimeError("requires tools/test.sh isolation and a nested 1280x800 ELASTIC-1 output")
    flags = shlex.split(run("pkg-config", "--cflags", "--libs", "wayland-client"))
    subprocess.run(["cc", str(source / "WindowPointer.c"), "-o", str(directory / "window-pointer"), *flags], check=True, stderr=subprocess.PIPE)
    app_class = "qs-elastic-" + mode
    ctl('hl.config({animations={enabled=true},binds={drag_threshold=0}}); hl.window_rule({match={class="^' + app_class + '$"},float=true})')
    ctl('hl.dispatch(hl.dsp.focus({workspace=1}))')
    events = socket.socket(socket.AF_UNIX)
    events.connect(str(Path(os.environ["XDG_RUNTIME_DIR"], "hypr", os.environ["HYPRLAND_INSTANCE_SIGNATURE"], ".socket2.sock")))
    argv = ["env", "KITTY_CACHE_DIRECTORY=" + str(directory / "kitty"), "kitty", "--config", "NONE", "--class", app_class,
            "--override", "background=#e014cf", "--override", "initial_window_width=640", "--override", "initial_window_height=400",
            "--override", "remember_window_size=no", "--override", "cursor_blink_interval=0", "--override", "confirm_os_window_close=0", "cat"]
    if mode == "edges":
        ctl('hl.window_rule({match={class="^qs-elastic-bg.*$"},float=true})')
        for workspace, background in [(1, "#14b4e0"), (2, "#e0a414")]:
            args = [v.replace(app_class, "qs-elastic-bg" + str(workspace)).replace("#e014cf", background) for v in argv]
            ctl("hl.dispatch(hl.dsp.exec_cmd(" + json.dumps(f"[workspace {workspace} silent] " + shlex.join(args)) + "))")
    ctl("hl.dispatch(hl.dsp.exec_cmd(" + json.dumps(shlex.join(argv)) + "))")
    pending, deadline = "", time.monotonic() + 4
    while not address:
        if not select.select([events], [], [], max(0, deadline - time.monotonic()))[0]:
            raise RuntimeError("test window did not map")
        pending += events.recv(65536).decode()
        lines = pending.split("\n")
        pending = lines.pop()
        for line in lines:
            if line.startswith("openwindow>>") and "," + app_class + "," in line:
                address = "0x" + line.split(">>")[1].split(",")[0]
    events.close()
    before = capture("before", .95)
    report("fixture is visibly mapped", before["count"] > 200000, before)
    if mode == "native":
        flags = shlex.split(run("pkg-config", "--cflags", "--libs", "wayland-client", "xkbcommon"))
        subprocess.run(["cc", str(source / "WindowKeyboard.c"), "-o", str(directory / "window-keyboard"), *flags], check=True, stderr=subprocess.PIPE)
        ctl('hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), {mouse=true})')
        keyboard = subprocess.Popen([str(directory / "window-keyboard")], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        keyboard.stdin.write("1\n")
        keyboard.stdin.flush()
        if keyboard.stdout.readline().strip() != "ok": raise RuntimeError("virtual keyboard disconnected")
    pointer = subprocess.Popen([str(directory / "window-pointer"), "--stream"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)

    if mode == "overview":
        ctl('hl.plugin.hyprexpo.expo("toggle")')
        preview = capture("preview", .55)
        b = preview["box"]
        x, y = b[0] + preview["width"] * .65, b[1] + (b[3] - b[1]) * .4
        move(x, y, 1)
        move(x + 15, y)
        held = capture("held", .22)
        report("overview uses the same 93 percent lift", abs(held["width"] / preview["width"] - .93) < .025, held)
        drag_path(x + 15, y, 300)
        moving = capture("moving")
        report("overview carries live window contents above tiles", moving["count"] > preview["count"] * .75, moving)
        stopped = capture("stopped", .21)
        report("overview straightens while still held", abs(stopped["tilt"]) <= 1, stopped)
        report("source preview has no duplicate carried window", stopped["count"] < preview["count"] * 1.08, stopped)
        move(x + 315, y, 0)
        landing = capture("landing", .07)
        landed = capture("landed", .4)
        report("overview release uses elastic landing", landing["width"] > held["width"], landing)
        report("overview transfers the actual subject", client()["workspace"]["id"] != 1, client())
        report("overview hand-back leaves one visible image", landed["count"] > preview["count"] * .65, landed)
        workspace = client()["workspace"]["id"]
        b = landed["box"]
        move((b[0] + b[2]) / 2, (b[1] + b[3]) / 2, 1)
        move((b[0] + b[2]) / 2 + 20, (b[1] + b[3]) / 2)
        move(440, 300)
        move(440, 300, 0)
        cancelled = capture("cancelled", .4)
        report("invalid drop cancels into the source workspace", client()["workspace"]["id"] == workspace)
        report("cancelled drag restores one valid window image", cancelled["count"] > preview["count"] * .65, cancelled)
        ctl('hl.plugin.hyprexpo.expo("off")')
    elif mode == "tiled":
        ctl('hl.dispatch(hl.dsp.window.float({action="disable",window="address:' + address + '"}))')
        before = capture("tile-before", .5)
        c = client()
        bar = json.loads(run("hyprctl", "-j", "getoption", "plugin:windows:height"))["int"]
        x, y = c["at"][0] + c["size"][0] * .4, c["at"][1] + bar / 2
        move(x, c["at"][1] + 1)
        capture("tile-revealed", .5)
        move(x, y, 1)
        move(x + 20, y + 24)
        held = capture("tile-held", .22)
        report("native layout picks up a tile", client()["floating"])
        report("tile pickup uses 93 percent of the original size", abs(held["width"] / before["width"] - .93) < .01, held)
        expected_left = round(x + 20 - (x - c["at"][0]) * .93)
        report("tile pickup preserves the original grab point", abs(held["box"][0] - expected_left) <= 2, held)
        report("tile pickup stays in its workspace", client()["workspace"]["id"] == c["workspace"]["id"])
        move(x + 20, y + 24, 0)
        landed = capture("tile-landed", .4)
        report("tile uses the shared landing into its final box", abs(landed["width"] - before["width"]) <= 1, landed)
        report("layout restores the tile mode and dimensions", not client()["floating"] and client()["size"] == c["size"], client())
    else:
        c = client()
        bar = json.loads(run("hyprctl", "-j", "getoption", "plugin:windows:height"))["int"]
        x, y = c["at"][0] + c["size"][0] * .92, c["at"][1] - bar / 2
        if mode == "native":
            x, y = c["at"][0] + c["size"][0] * .6, c["at"][1] + c["size"][1] / 2
        move(x, y, 1)
        move(x + 64, y + 24)
        held = capture("held", .22)
        report("ordinary move lifts to 93 percent", abs(held["width"] / before["width"] - .93) < .01, held)
        expected_left = round(x + 64 - (x - c["at"][0]) * .93)
        report("off-center grab stays pinned to cursor", abs(held["box"][0] - expected_left) <= 2, held)
        report("large first motion preserves the original grab point", client()["at"] == [c["at"][0] + 64, c["at"][1] + 24], client())
        x, y = x + 63, y + 23

        if mode == "edges":
            move(1265, y + 1)
            edge = capture("edge-dwell", .12)
            report("edge dwell does not switch immediately", client()["workspace"]["id"] == 1)
            samples = []
            for i in range(5):
                samples.append(capture("transition-" + str(i), .13))
            report("window remains visible throughout workspace slide", all(s["count"] > 80000 for s in samples), samples)
            report("workspace slides leave carried frame fixed", max(s["box"][0] for s in samples) - min(s["box"][0] for s in samples) <= 2, samples)
            report("workspace contents slide underneath the fixed window", edge["background"] > 10000 and
                   any(s["background"] > 500 and s["background_x"] < edge["background_x"] - 20 for s in samples), [edge, samples])
            report("edge dwell transfers actual window", client()["workspace"]["id"] >= 2)
            capture("consecutive", .75)
            report("consecutive transfers need no release or cursor motion", client()["workspace"]["id"] >= 3, client())
            move(850, y + 50)
            responsive = capture("responsive", .03)
            report("cursor remains responsive across transitions", responsive["box"][0] < samples[-1]["box"][0] - 300, responsive)
            x, y = 850, y + 50
        else:
            drag_path(x + 1, y + 1, 160)
            right = capture("right")
            drag_path(x + 161, y + 1, -160)
            left = capture("left")
            report("deformation responds to movement direction", right["tilt"] > 1 and left["tilt"] < -1, [right, left])
            report("rotation stays within two degrees", max(abs(right["tilt"]), abs(left["tilt"])) <= held["width"] * .4 * .035 + 2)
            stopped = capture("stopped", .22)
            report("stopping straightens without releasing", abs(stopped["tilt"]) <= 1 and abs(stopped["width"] - held["width"]) <= 1, stopped)
            x, y = x + 1, y + 1

        move(x, y, 0)
        landing = capture("landing", .07)
        landed = capture("landed", .35)
        report("release grows smoothly toward full size", held["width"] < landing["width"] <= before["width"] * 1.02, landing)
        report("landing restores full undistorted window", abs(landed["width"] - before["width"]) <= 1 and abs(landed["tilt"]) <= 1, landed)
        report("drag preserves actual window dimensions", client()["size"] == c["size"])
        if mode == "ordinary":
            ctl('hl.config({animations={enabled=false}})')
            c = client()
            move(c["at"][0] + 450, c["at"][1] - bar / 2, 1)
            move(c["at"][0] + 460, c["at"][1] - bar / 2)
            disabled = capture("disabled", .15)
            report("reduced motion keeps ordinary full-size dragging", abs(disabled["width"] - before["width"]) <= 1, disabled)
            move(c["at"][0] + 460, c["at"][1] - bar / 2, 0)
            ctl('hl.config({animations={enabled=true}})')
            c = client()
            move(c["at"][0] + 450, c["at"][1] - bar / 2, 1)
            move(c["at"][0] + 460, c["at"][1] - bar / 2)
            ctl('hl.dispatch(hl.dsp.window.close({window="address:' + address + '"}))')
            closed = capture("closed-during-drag", .4)
            report("closing while held releases the live transform", client() is None and closed["count"] == 0, closed)
            move(800, 200, 0)
    layers = json.loads(run("hyprctl", "-j", "layers"))
    report("drag creates no input-taking surfaces", not any(layer for m in layers.values() for group in m.get("levels", {}).values() for layer in group), layers)
except Exception as error:
    report("rendered drag fixture completed", False, repr(error))
finally:
    if pointer:
        pointer.stdin.close()
        pointer.wait(timeout=3)
    if keyboard:
        keyboard.stdin.close()
        keyboard.wait(timeout=3)
    if address:
        try:
            ctl('hl.dispatch(hl.dsp.window.close({window="address:' + address + '"}))')
        except Exception:
            pass
    if mode == "edges":
        try:
            ctl('hl.dispatch(hl.dsp.window.close({window="class:qs-elastic-bg1"})); hl.dispatch(hl.dsp.window.close({window="class:qs-elastic-bg2"}))')
        except Exception:
            pass
    print(json.dumps(results))
