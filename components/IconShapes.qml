pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

/*!
    How to draw each application icon so that every one carries the same
    visual weight: measured once per icon, by an AppIcon set `optical` (or
    given an `ink`), and kept for every later copy of it.

    Icons are drawn to fill the same square, but their artwork does not: a
    full-bleed tile covers nearly all of it, a round logo three quarters, a
    glyph inside a margin less. Side by side the tiles read as bigger. So each
    is scaled until the area it covers comes out the same — the rule behind
    Material's keylines and Apple's icon grid, measured here rather than
    designed in — never past its box, and its artwork centred in the box.
*/
QtObject {
    id: root

    /*! The share of its box every icon is brought to: about what a round logo,
        or a tile inside a margin, covers already, so most icons stay as they
        are drawn and the heavy ones come down. */
    readonly property real mass: 0.64
    /*! How far an icon is scaled, either way, at most. */
    readonly property real least: 0.8
    readonly property real most: 1.1

    /*! The grey as far from black as from white, as contrast goes, as an
        8-bit level: what parts an icon's light from its dark. */
    readonly property real midLevel: 255 * (1.055 * Math.pow(Math.sqrt(1.05 * 0.05) - 0.05, 1 / 2.4) - 0.055)

    property var shapes: ({})
    /*! Bumped whenever a measurement lands: what makes a lookup re-evaluate. */
    property int revision: 0

    /*! `{ scale, dx, dy, light }` for an icon, or null until it is measured;
        the offsets are the artwork's from the box's centre, as shares of it,
        and `light` the share of its artwork lighter than mid grey (what an
        icon drawn in one ink goes by: AppIcon's `ink`). */
    function shapeOf(source: string, revision: int): var {
        return root.shapes[source] ?? null;
    }

    /*! Takes in the RGBA of an icon drawn into an n × n canvas. */
    function measure(source: string, pixels: var, n: int): void {
        let covered = 0;
        let light = 0;
        // Two boxes: everything that shows, which the icon may not outgrow,
        // and the solid artwork, which is what gets centred — a faint drop
        // shadow below an icon would otherwise lift it off the line.
        const shows = { x0: n, y0: n, x1: -1, y1: -1 };
        const solid = { x0: n, y0: n, x1: -1, y1: -1 };
        const extend = (box, x, y) => {
            box.x0 = Math.min(box.x0, x);
            box.y0 = Math.min(box.y0, y);
            box.x1 = Math.max(box.x1, x);
            box.y1 = Math.max(box.y1, y);
        };
        for (let y = 0; y < n; ++y) {
            for (let x = 0; x < n; ++x) {
                const i = (y * n + x) * 4;
                const alpha = pixels[i + 3] / 255;
                covered += alpha;
                if (0.2126 * pixels[i] + 0.7152 * pixels[i + 1] + 0.0722 * pixels[i + 2] > root.midLevel)
                    light += alpha;
                if (alpha > 0.1)
                    extend(shows, x, y);
                if (alpha > 0.5)
                    extend(solid, x, y);
            }
        }
        if (solid.x1 < 0)
            return;
        const span = Math.max(shows.x1 - shows.x0 + 1, shows.y1 - shows.y0 + 1) / n;
        const scale = Math.min(1 / span, Math.max(root.least,
            Math.min(root.most, Math.sqrt(root.mass / (covered / (n * n))))));
        root.shapes[source] = {
            scale,
            dx: ((solid.x0 + solid.x1 + 1) / 2 - n / 2) / n,
            dy: ((solid.y0 + solid.y1 + 1) / 2 - n / 2) / n,
            light: light / covered
        };
        root.revision++;
    }
}
