pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

/*!
    Screen capture.

    `grim` takes the picture and `slurp` picks the rectangle for a region shot;
    both speak the wlroots screencopy protocol Hyprland implements. The image is
    written under the XDG pictures directory and copied to the clipboard, and
    the shell's own notification server announces where it landed.

    A region shot freezes the screen first, so that what is saved is what was on
    screen when the key was pressed: `hyprpicker`, its lens off, shows every
    screen as it was, slurp is dragged out over it, and grim takes the frozen
    frame before the freeze is lifted. slurp waits for Hyprland to announce the
    freeze's layer, since a freeze that came up after it would have frozen its
    dimming too. Without hyprpicker the shot is taken unfrozen. hyprland.conf's
    layer rules keep slurp above the freeze and a toast below it.

    The capture itself runs detached rather than through a `Process`: nothing
    here needs its output, and the freeze, the one `Process`, already keeps
    region shots to one at a time — a press while one is dragged out does
    nothing.
*/
Singleton {
    id: root

    /*! slurp, then grim on what it picked. */
    readonly property string selection: 'g=$(slurp) && grim -g "$g" "$f"'

    /*! The whole screen. */
    function capture(): void {
        root.run('grim "$f"');
    }

    /*! A rectangle dragged out with the pointer. Escape cancels it. */
    function captureRegion(): void {
        if (freeze.running)
            return;
        freeze.shown = false;
        freeze.running = true;
    }

    /*!
        A cancelled selection is the ordinary way for the capture step to fail,
        so it leaves quietly; there is nothing to save or announce either way.
    */
    function run(step: string): void {
        Quickshell.execDetached(["sh", "-c",
            'd=$(xdg-user-dir PICTURES); d=${d:-$HOME/Pictures}/Screenshots; mkdir -p "$d" || exit 1;'
            + ' f="$d/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png";'
            + ` ${step} || exit 0;`
            + ' wl-copy < "$f";'
            + ' notify-send -a Screenshot -i "$f" "Screenshot saved" "$f"']);
    }

    Process {
        id: freeze

        property bool shown

        command: ["hyprpicker", "--render-inactive", "--no-zoom", "--quiet"]
        // Gone without ever showing — not installed, or failed — it leaves the
        // region shot to be taken unfrozen. A start that fails never reports
        // running, which is why `shown` is reset by the press, not here.
        onRunningChanged: {
            if (!running && !shown)
                root.run(root.selection);
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "openlayer" || event.data !== "hyprpicker" || !freeze.running || freeze.shown)
                return;
            // One layer per screen, and the first is enough: hyprpicker asks for
            // every screen's frame at once, each arrives with its screen's next
            // frame, and slurp is a process started only now.
            freeze.shown = true;
            root.run(`${root.selection}; s=$?; kill ${freeze.processId}; [ $s = 0 ]`);
        }
    }
}
