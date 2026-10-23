import QtQuick
import Quickshell
import "root:/components"
import "root:/services"

/*!
    A screen's wallpaper measured for Backdrop (BackdropProbe), and nothing
    tried where there is nothing to measure with: no screen — one going, a
    moment before its bar — and a canvas out of its window — its bar going,
    in a reload, with the picture still decoding.
*/
Item {
    id: root

    property ShellScreen screen: null
    /*! The probe's canvas, once it has one. */
    readonly property var canvas: probe.item

    Check {
        id: check
    }

    FloatingWindow {
        implicitWidth: 100
        implicitHeight: 100
        color: "transparent"

        BackdropProbe {
            id: probe
            screen: root.screen
        }
    }

    Component.onCompleted: {
        if (Wallpaper.current !== "")
            root.begin();
    }

    Connections {
        target: Wallpaper

        function onCurrentChanged(): void {
            if (Wallpaper.current !== "" && !root.started)
                root.begin();
        }
    }

    property bool started: false

    function begin(): void {
        root.started = true;
        check.equal("no screen: nothing to measure", probe.active, false);
        root.screen = Quickshell.screens[0];
    }

    /*! What happens to a probe's canvas out of its window. */
    function tryTake(canvas: var): string {
        try {
            canvas.take();
            return "";
        } catch (e) {
            return String(e);
        }
    }

    Connections {
        target: root.canvas
        ignoreUnknownSignals: true

        // The canvas asked for the picture; out of its window before the
        // picture is in, as a reload leaves it.
        function onAvailableChanged(): void {
            root.canvas.parent = null;
        }

        function onImageLoaded(): void {
            const canvas = root.canvas;
            if (canvas.parent !== null)
                return;
            check.equal("out of its window: takes nothing, and does not fail", root.tryTake(canvas), "");
            check.equal("out of its window: nothing measured", Backdrop.measured(root.screen), false);
            canvas.parent = probe;
            canvas.take();
            check.equal("back in it: measured", Backdrop.measured(root.screen), true);
            check.equal("measured: the probe stands down", probe.active, false);
            // Another screen, not measured yet, going while it is measured.
            root.screen = Quickshell.screens[1];
            check.equal("another screen: measuring it", probe.active, true);
            root.screen = null;
            check.equal("its screen gone while measuring: stands down", probe.active, false);
            check.done();
        }
    }
}
