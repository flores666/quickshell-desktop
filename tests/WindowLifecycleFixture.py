"""Native lifecycle checks on the runner's private headless compositor.

Wait on window events, then take deliberately timed animation frames. Targets
replace only the shell publication boundary; real map/unmap/render paths run.
"""
import json
import os
from pathlib import Path
import select
import shlex
import socket
import subprocess
import time

directory = Path(os.environ["TEST_BIN"])
results = []
addresses = []
events = None
pending = ""
color = bytes((224, 20, 207))


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=4).strip()


def ctl(code):
    return run("hyprctl", "eval", code)


def report(name, ok, detail=""):
    results.append(dict(name=name, ok=bool(ok), detail=str(detail)))


def clients():
    return json.loads(run("hyprctl", "-j", "clients"))


def target(app_id="", address="", screen="ANIM-1"):
    row = '{x=1040,y=730,width=43,height=43'
    if app_id:
        row += ',appId=' + json.dumps(app_id)
    if address:
        row += ',address=' + json.dumps(address)
    ctl('hl.plugin.windows.dock_targets({[' + json.dumps(screen) + ']={' + row + '}}})')


def open_window(app_id):
    global pending
    argv = ["env", "KITTY_CACHE_DIRECTORY=" + str(directory / app_id),
            "kitty", "--config", "NONE", "--class", app_id,
            "--override", "background=#e014cf", "--override", "initial_window_width=640",
            "--override", "initial_window_height=400", "--override", "remember_window_size=no",
            "--override", "cursor_blink_interval=0", "--override", "confirm_os_window_close=0", "cat"]
    ctl("hl.dispatch(hl.dsp.exec_cmd(" + json.dumps(shlex.join(argv)) + "))")
    deadline = time.monotonic() + 4
    while True:
        lines = pending.split("\n")
        pending = lines.pop()
        for line in lines:
            if line.startswith("openwindow>>") and ',' + app_id + ',' in line:
                address = "0x" + line.split(">>")[1].split(",")[0]
                addresses.append(address)
                return next(c for c in clients() if c["address"] == address)
        if not select.select([events], [], [], max(0, deadline - time.monotonic()))[0]:
            raise RuntimeError("window did not open: " + app_id)
        pending += events.recv(65536).decode()


def action(window, name, extra=""):
    ctl('hl.dispatch(hl.dsp.window.' + name + '({window="address:' + window["address"] + '"' + extra + '}))')


def capture(name, delay, window):
    time.sleep(delay)  # One finite animation settle, never a state poll.
    path = directory / (name + ".png")
    subprocess.run(["grim", "-o", "ANIM-1", str(path)], check=True, timeout=3, stderr=subprocess.PIPE)
    data = subprocess.check_output(["magick", str(path), "-depth", "8", "rgb:-"], timeout=3)
    rows = []
    for y in range(800):
        row = data[y * 1280 * 3:(y + 1) * 1280 * 3]
        left, right = row.find(color), row.rfind(color)
        if left >= 0:
            rows.append((y, left // 3, right // 3 + 1))
    cy = window["at"][1] + window["size"][1] // 2
    # The pointer starts at the window center; grim includes its white cursor.
    cx = window["at"][0] + window["size"][0] // 3
    row = data[cy * 1280 * 3:(cy + 1) * 1280 * 3]
    tinted = [x for x in range(1280) if row[3*x] - row[3*x+1] > 15 and row[3*x+2] - row[3*x+1] > 15]
    return dict(count=data.count(color), rows=rows, span=(tinted[-1] - tinted[0] + 1) if tinted else 0,
                center=tuple(row[cx * 3:cx * 3 + 3]))


def tapered(frame):
    rows = frame["rows"]
    if len(rows) < 40:
        return False
    top, bottom = rows[len(rows) // 4], rows[3 * len(rows) // 4]
    return top[2] - top[1] > 1.25 * (bottom[2] - bottom[1])


try:
    monitors = json.loads(run("hyprctl", "-j", "monitors"))
    if not directory.is_dir() or not any(m["name"] == "ANIM-1" and m["width"] == 1280 and m["height"] == 800 for m in monitors):
        raise RuntimeError("requires runner isolation and nested ANIM-1; refusing the user's compositor")
    ctl('hl.config({animations={enabled=true}}); hl.dispatch(hl.dsp.focus({workspace=1})); '
        'hl.config({["plugin.windows.minimize_duration"]=900,["plugin.windows.minimize_exposure"]=0,'
        '["plugin.windows.fade_duration"]=900,["plugin.windows.close_duration"]=900}); hl.plugin.windows.restyle()')
    events = socket.socket(socket.AF_UNIX)
    events.connect(str(Path(os.environ["XDG_RUNTIME_DIR"], "hypr", os.environ["HYPRLAND_INSTANCE_SIGNATURE"], ".socket2.sock")))

    # A pin has no address until map. Application identity must be enough.
    # Placement belongs to the compositor and survives individual test shells.
    # Fresh identities keep a previous run's resize out of this fixture.
    app_id = "qs-lifecycle-docked-" + str(os.getpid())
    target(app_id)
    window = open_window(app_id)
    opening = capture("dock-open-middle", 0.30, window)
    report("launch from a preexisting icon has an intermediate image", 1000 < opening["count"] < 240000, opening["count"])
    report("launch reverses the dock Genie", tapered(opening), opening["rows"][::100])
    full = capture("dock-open-done", 0.65, window)
    report("launch ends with one sharp full-size window", full["count"] > 245000, full["count"])
    current = next(c for c in clients() if c["address"] == window["address"])
    report("launch keeps the real window geometry", current["at"] == window["at"] and current["size"] == window["size"])
    target(address=window["address"])
    action(window, "close")
    closing = capture("dock-close-middle", 0.30, window)
    report("close removes the real client immediately", not any(c["address"] == window["address"] for c in clients()))
    report("close retains its image after the client is gone", 1000 < closing["count"] < full["count"] * 0.98, closing["count"])
    report("close uses the dock Genie", tapered(closing), closing["rows"][::100])
    done = capture("dock-close-done", 0.65, window)
    report("close releases its detached image", done["count"] == 0, done["count"])

    # A target on another output cannot animate this window into that dock.
    app_id = "qs-lifecycle-fade-" + str(os.getpid())
    target(app_id, screen="ANIM-2")
    window = open_window(app_id)
    opening = capture("fade-open-middle", 0.30, window)
    report("without a local icon launch fades at full width", abs(opening["span"] - window["size"][0]) <= 2, opening["span"])
    full = capture("fade-open-done", 0.65, window)
    report("fallback launch becomes fully visible", full["count"] > 245000, full["count"])
    action(window, "resize", ',x=800,y=400')
    resizing = capture("fade-following-resize", 0.25, window)
    report("a fade hands later resizing back to the movement timing", resizing["span"] > (window["size"][0] + 800) / 2, resizing["span"])
    time.sleep(0.35)  # Finish this one resize before checking close geometry.
    window = next(c for c in clients() if c["address"] == window["address"])
    action(window, "close")
    closing = capture("fade-close-middle", 0.30, window)
    report("without a local icon close fades at full width", abs(closing["span"] - window["size"][0]) <= 2, closing["span"])
    done = capture("fade-close-done", 0.65, window)
    def opacity(frame):
        delta = [f - b for f, b in zip(full["center"], done["center"])]
        return sum(d * (p - b) for d, p, b in zip(delta, frame["center"], done["center"])) / max(1, sum(d*d for d in delta))
    report("launch fade has intermediate opacity", 0.1 < opacity(opening) < 0.9, opening["center"])
    report("close fade has intermediate opacity", 0.1 < opacity(closing) < 0.9, closing["center"])
    report("fallback close leaves no image", done["count"] == 0, done["count"])

    app_id = "qs-lifecycle-reverse-" + str(os.getpid())
    target(app_id)
    window = open_window(app_id)
    capture("reverse-open", 0.30, window)
    action(window, "close")
    done = capture("reverse-done", 1.0, window)
    report("closing during launch releases the image", done["count"] == 0, done["count"])
    report("closing during launch still closes the client", not any(c["address"] == window["address"] for c in clients()))

    app_id = "qs-lifecycle-disabled-" + str(os.getpid())
    target(app_id)
    ctl('hl.config({animations={enabled=false}})')
    window = open_window(app_id)
    full = capture("disabled-open", 0.04, window)
    report("disabled animations open without a retained image", full["count"] > 245000, full["count"])
    action(window, "close")
    done = capture("disabled-close", 0.04, window)
    report("disabled animations close without a retained image", done["count"] == 0, done["count"])
except Exception as error:
    report("lifecycle fixture completed", False, repr(error))
finally:
    if events:
        events.close()
    for address in addresses:
        try:
            ctl('hl.dispatch(hl.dsp.window.close({window="address:' + address + '"}))')
        except Exception:
            pass
    try:
        ctl('hl.plugin.windows.dock_targets({}); hl.config({animations={enabled=true}})')
    except Exception:
        pass
    print(json.dumps(results))
