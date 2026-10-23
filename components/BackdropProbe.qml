pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/services"

/*!
    Measures one screen's wallpaper for Backdrop whenever the picture or the
    screen's size has changed since it was last measured: the picture is
    decoded off the main thread, already shrunk to Backdrop's gauge, into a
    canvas nobody sees — a canvas needs a window, which a service has not.
    Any window on that screen can hold it; the bar does.
*/
Loader {
    id: root

    /*! Null for a moment as a screen goes, ahead of the bar that holds this. */
    required property ShellScreen screen

    active: root.screen !== null && Wallpaper.current !== "" && !Backdrop.measured(root.screen)

    sourceComponent: Canvas {
        id: probe

        readonly property string path: Wallpaper.current
        // Each part of the path encoded on its own: a picture's name may hold
        // a '#' or a '?', which a URL would take for something else. A string,
        // not a url: createImageData takes a picture by string alone.
        readonly property string source: "file://" + probe.path.split("/").map(encodeURIComponent).join("/")
        readonly property size gauge: Backdrop.gauge(root.screen)

        width: 1
        height: 1
        opacity: 0

        onAvailableChanged: probe.begin()
        onSourceChanged: probe.begin()
        onGaugeChanged: probe.begin()
        // Any picture this canvas asked for, a stale one included.
        onImageLoaded: probe.take()

        function begin(): void {
            if (!probe.available)
                return;
            // A canvas keeps one picture per URL, at the size first asked.
            probe.unloadImage(probe.source);
            probe.loadImage(probe.source, probe.gauge);
            // One the image cache holds already loads at once and says
            // nothing.
            probe.take();
        }

        function take(): void {
            // No context once the canvas is out of its window: a reload takes
            // the bar while the picture is still decoding.
            const context = probe.getContext("2d");
            if (context !== null && probe.isImageLoaded(probe.source))
                Backdrop.measure(root.screen, probe.path, probe.gauge,
                    context.createImageData(probe.source));
        }
    }
}
