"""Event-driven MPRIS players, confined to the test runner's private bus."""
import json
import os
from pathlib import Path
import struct
import sys
import time
import zlib

from gi.repository import Gio, GLib

if os.environ.get("TEST_MPRIS_BUS") != "private" or not os.environ.get("TEST_BIN"):
    raise RuntimeError("MprisFixture requires tools/test.sh's private bus")

XML = """<node>
<interface name="org.mpris.MediaPlayer2">
 <property name="Identity" type="s" access="read"/>
 <property name="DesktopEntry" type="s" access="read"/>
 <property name="CanQuit" type="b" access="read"/>
 <property name="CanRaise" type="b" access="read"/>
 <property name="HasTrackList" type="b" access="read"/>
 <property name="SupportedUriSchemes" type="as" access="read"/>
 <property name="SupportedMimeTypes" type="as" access="read"/>
</interface>
<interface name="org.mpris.MediaPlayer2.Player">
 <method name="Next"/><method name="Previous"/><method name="PlayPause"/>
 <method name="Play"/><method name="Pause"/><method name="Stop"/>
 <method name="Seek"><arg type="x" direction="in"/></method>
 <method name="SetPosition"><arg type="o" direction="in"/><arg type="x" direction="in"/></method>
 <property name="PlaybackStatus" type="s" access="read"/>
 <property name="Metadata" type="a{sv}" access="read"/>
 <property name="Position" type="x" access="read"/>
 <property name="Rate" type="d" access="read"/>
 <property name="CanControl" type="b" access="read"/>
 <property name="CanPlay" type="b" access="read"/>
 <property name="CanPause" type="b" access="read"/>
 <property name="CanSeek" type="b" access="read"/>
 <property name="CanGoNext" type="b" access="read"/>
 <property name="CanGoPrevious" type="b" access="read"/>
 <signal name="Seeked"><arg type="x"/></signal>
</interface>
</node>"""
PATH = "/org/mpris/MediaPlayer2"
PLAYER = "org.mpris.MediaPlayer2.Player"
NODE = Gio.DBusNodeInfo.new_for_xml(XML)
players = {}
actions = []


def metadata(data):
    return {key: GLib.Variant(
        "x" if key == "mpris:length" else "o" if key == "mpris:trackid"
        else "as" if isinstance(value, list) else "s", value,
    ) for key, value in data.items()}


class Player:
    def __init__(self, name, position=True, exported=True):
        self.name = name
        self.bus = Gio.DBusConnection.new_for_address_sync(
            os.environ["DBUS_SESSION_BUS_ADDRESS"],
            Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,
            None, None,
        )
        self.values = {
            "Identity": GLib.Variant("s", name), "DesktopEntry": GLib.Variant("s", ""),
            "SupportedUriSchemes": GLib.Variant("as", []),
            "SupportedMimeTypes": GLib.Variant("as", []),
            "PlaybackStatus": GLib.Variant("s", "Paused"), "Rate": GLib.Variant("d", 1.0),
            "Position": GLib.Variant("x", 30_000_000), "Metadata": GLib.Variant("a{sv}", {}),
        }
        self.position_at = time.monotonic()
        self.reads = 0
        self.get_all = 0
        self.missing = 0
        self.registrations = []
        self.bus.add_filter(self.filter, None)
        for key in ["CanControl", "CanPlay", "CanPause", "CanSeek", "CanGoNext", "CanGoPrevious"]:
            self.values[key] = GLib.Variant("b", True)
        for key in ["CanQuit", "CanRaise", "HasTrackList"]:
            self.values[key] = GLib.Variant("b", False)
        if not position:
            del self.values["Position"]
        if exported:
            self.export()
        self.bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                           "RequestName", GLib.Variant("(su)", ("org.mpris.MediaPlayer2." + name, 0)),
                           None, Gio.DBusCallFlags.NONE, -1, None)

    def export(self):
        self.registrations = [self.bus.register_object(PATH, iface, self.call, self.get, None)
                              for iface in NODE.interfaces]

    def filter(self, connection, message, incoming, data):
        if incoming and message.get_message_type() == Gio.DBusMessageType.METHOD_CALL and message.get_member() == "GetAll":
            self.get_all += 1
            if not self.registrations:
                self.missing += 1
                print(json.dumps({"missing": self.missing, "player": self.name}), flush=True)
        return message

    def get(self, connection, sender, path, interface, prop):
        if prop == "Position" and prop in self.values:
            self.reads += 1
            return GLib.Variant("x", self.position())
        return self.values.get(prop)

    def position(self):
        value = self.values["Position"].unpack()
        if self.values["PlaybackStatus"].unpack() == "Playing":
            value += int((time.monotonic() - self.position_at) * self.values["Rate"].unpack() * 1000000)
        return value

    def call(self, connection, sender, path, interface, method, args, invocation):
        values = args.unpack()
        actions.append([self.name, method, *values])
        if method in ("SetPosition", "Seek"):
            position = values[-1] + (self.values["Position"].unpack() if method == "Seek" else 0)
            self.values["Position"] = GLib.Variant("x", position)
            self.position_at = time.monotonic()
            self.bus.emit_signal(None, PATH, PLAYER, "Seeked", GLib.Variant("(x)", (position,)))
        if method in ("Play", "Pause", "Stop", "PlayPause"):
            playing = self.values["PlaybackStatus"].unpack() == "Playing"
            status = {"Play": "Playing", "Pause": "Paused", "Stop": "Stopped"}.get(
                method, "Paused" if playing else "Playing")
            self.update({"PlaybackStatus": status})
        invocation.return_value(None)

    def update(self, properties):
        if "Position" in self.values and any(key in properties for key in ("Position", "PlaybackStatus", "Rate")):
            self.values["Position"] = GLib.Variant("x", self.position())
            self.position_at = time.monotonic()
        changed = {}
        for key, value in properties.items():
            changed[key] = GLib.Variant("a{sv}", metadata(value)) if key == "Metadata" else GLib.Variant(
                "x" if key == "Position" else "d" if key == "Rate" else "b" if key.startswith("Can") else "s", value)
        self.values.update(changed)
        if self.registrations:
            self.bus.emit_signal(None, PATH, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                                 GLib.Variant("(sa{sv}as)", (PLAYER, changed, [])))

    def close(self):
        self.bus.close_sync(None)


def cover(name, rgb):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    # Artwork fixture, not a UI metric.
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 2, 8, 2, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress((b"\0" + bytes(rgb) * 2) * 2)) + chunk(b"IEND", b"")
    target = Path(os.environ["TEST_BIN"]) / name
    target.write_bytes(data)
    return target.as_uri()


loop = GLib.MainLoop()


def command(channel, condition):
    line = sys.stdin.readline()
    if not line:
        loop.quit()
        return False
    request = json.loads(line)
    name = request.get("player", "fixture")
    action = request["action"]
    if action == "add":
        players[name] = Player(name, request.get("position", True), request.get("exported", True))
    elif action == "export":
        players[name].export()
    elif action == "remove":
        players.pop(name).close()
    elif action == "update":
        players[name].update(request["properties"])
    elif action == "seek":
        position = request["position"]
        players[name].values["Position"] = GLib.Variant("x", position)
        players[name].position_at = time.monotonic()
        players[name].bus.emit_signal(None, PATH, PLAYER, "Seeked", GLib.Variant("(x)", (position,)))
    elif action == "unlink":
        Path(os.environ["TEST_BIN"], request["file"]).unlink()
    elif action != "actions":
        raise ValueError(action)
    print(json.dumps({"serial": request["serial"], "actions": actions,
                      "reads": sum(player.reads for player in players.values()),
                      "getAll": {name: player.get_all for name, player in players.items()}}), flush=True)
    return True


GLib.io_add_watch(sys.stdin, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, command)
print(json.dumps({"ready": True, "cover": cover("cover.png", (64, 128, 192)),
                  "otherCover": cover("other.png", (192, 128, 64))}), flush=True)
loop.run()
