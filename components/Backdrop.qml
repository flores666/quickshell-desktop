pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/services"

/*!
    What the wallpaper is like under any part of a screen: the mean colour of
    the picture there, as hyprpaper lays it — scaled to cover the screen and
    centred, the overflow cut off. The bar and the dock read it where the user
    has thinned their glass (Surface.schemeOver), so that what is drawn on them
    stays legible over a pale sky and a dark forest alike.

    Each screen's picture is measured once, by that screen's bar
    (BackdropProbe), and kept as a summed-area table: the mean under any
    rectangle costs four lookups however large it is, so the bindings that
    ask can re-run freely as the dock's icons move.
*/
QtObject {
    id: root

    /*!
        How much of the screen one measured pixel of the picture covers, in
        logical pixels, where the picture has the screen's shape (one of
        another shape is coarser along the side it overflows). Fine enough
        for the strip a dock's window dots sit in; coarse enough that a
        screen is measured within a frame.
    */
    readonly property int cell: 8

    /*! By screen name: `{ path, gauge, width, height, sums }`. Replaced whole
        when one lands, which is what re-runs every binding that asked. */
    property var tables: ({})

    /*! The size a screen's picture is decoded to fit: one pixel per cell. */
    function gauge(screen: ShellScreen): size {
        return Qt.size(Math.ceil(screen.width / root.cell), Math.ceil(screen.height / root.cell));
    }

    /*! Whether the picture now on a screen is measured, at its size. */
    function measured(screen: ShellScreen): bool {
        const table = root.tables[screen.name];
        return table !== undefined && table.path === Wallpaper.current
            && table.gauge === root.gauge(screen).toString();
    }

    /*! Takes in a screen's picture, decoded to fit its gauge (a canvas's
        CanvasImageData): each entry of the table is the sum of the pixels
        above and to the left of it, a row's running sum added to the row
        above's. */
    function measure(screen: ShellScreen, path: string, gauge: size, image: var): void {
        const w = image.width;
        const h = image.height;
        if (w === 0 || h === 0)
            return;
        // Read once, natively: indexing the canvas's own array element by
        // element costs more than all the rest together.
        const px = new Uint8Array(image.data);
        const sums = new Float64Array((w + 1) * 3 * (h + 1));
        // A call a row: the engine compiles a function once it has been
        // called a few times, and a loop run once is never compiled.
        for (let y = 0; y < h; ++y)
            root.sumRow(px, sums, w, y);
        const next = Object.assign({}, root.tables);
        next[screen.name] = { path, gauge: gauge.toString(), width: w, height: h, sums };
        root.tables = next;
    }

    /*! Adds row `y` of the picture's pixels to the table. */
    function sumRow(px: var, sums: var, w: int, y: int): void {
        const row = (w + 1) * 3;
        let r = 0, g = 0, b = 0;
        for (let x = 0, i = y * w * 4, o = (y + 1) * row + 3; x < w; ++x, i += 4, o += 3) {
            r += px[i];
            g += px[i + 1];
            b += px[i + 2];
            sums[o] = sums[o - row] + r;
            sums[o + 1] = sums[o + 1 - row] + g;
            sums[o + 2] = sums[o + 2 - row] + b;
        }
    }

    /*!
        The mean colour of the wallpaper under `area` of a screen, in its
        logical pixels; null where it is not known — no picture, none measured
        yet, or the area off the screen. A picture just chosen is answered
        from the one before until it is measured, rather than from nothing.
    */
    function colorUnder(screen: ShellScreen, area: rect): var {
        const table = screen ? root.tables[screen.name] : undefined;
        if (table === undefined || Wallpaper.current === "")
            return null;
        const scale = Math.max(screen.width / table.width, screen.height / table.height);
        const left = (table.width * scale - screen.width) / 2;
        const top = (table.height * scale - screen.height) / 2;
        const across = v => Math.max(0, Math.min(table.width, (v + left) / scale));
        const down = v => Math.max(0, Math.min(table.height, (v + top) / scale));
        const u0 = across(area.x), u1 = across(area.x + area.width);
        const v0 = down(area.y), v1 = down(area.y + area.height);
        const size = (u1 - u0) * (v1 - v0) * 255;
        if (!(size > 0))
            return null;
        const mean = c => (root.sumTo(table, u1, v1, c) - root.sumTo(table, u0, v1, c)
            - root.sumTo(table, u1, v0, c) + root.sumTo(table, u0, v0, c)) / size;
        return Qt.rgba(mean(0), mean(1), mean(2), 1);
    }

    /*! Channel `c` summed over the picture from its corner to (u, v), which
        may fall inside a pixel: interpolating the table is exact for that,
        each pixel being one colour all over. */
    function sumTo(table: var, u: real, v: real, c: int): real {
        const x = Math.min(Math.floor(u), table.width - 1);
        const y = Math.min(Math.floor(v), table.height - 1);
        const fx = u - x;
        const fy = v - y;
        const row = (table.width + 1) * 3;
        const s = table.sums;
        const i = y * row + x * 3 + c;
        return (s[i] * (1 - fx) + s[i + 3] * fx) * (1 - fy)
            + (s[i + row] * (1 - fx) + s[i + row + 3] * fx) * fy;
    }
}
