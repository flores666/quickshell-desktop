pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    Screen capture.

    `grim` takes the picture and `slurp` picks the rectangle for a region shot;
    both speak the wlroots screencopy protocol Hyprland implements. The image is
    written under the XDG pictures directory and copied to the clipboard, and
    the shell's own notification server announces where it landed.

    The capture runs detached rather than through a `Process`: nothing here
    needs its output, a region shot blocks for as long as the user takes to drag
    one out, and two of those must not share a single object.
*/
Singleton {
    id: root

    /*! The whole screen. */
    function capture(): void {
        root.run('grim "$f"');
    }

    /*! A rectangle dragged out with the pointer. Escape cancels it. */
    function captureRegion(): void {
        root.run('g=$(slurp) && grim -g "$g" "$f"');
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
}
