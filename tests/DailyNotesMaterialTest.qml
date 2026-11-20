pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/modules/common"
import "root:/modules/widgets"
import "root:/services"

Item {
    id: root

    Check { id: check }
    Until { id: ready }
    property var capture: null
    property bool scaled: false
    property bool transferring: false
    property size captureSize
    property point restingEdge
    property point cardCenter
    property point cardGap
    property real cardPaintOpacity

    OverlaySurface {
        DailyNotesPanel { id: notes }
        ShellOverlay {
            id: next
            overlayId: Overlay.dateMenu
            placement: ShellOverlay.Placement.AboveDock
        }

        Canvas {
            id: pixels
            width: root.captureSize.width
            height: root.captureSize.height
            opacity: 0

            onImageLoaded: pixels.requestPaint()
            onPaint: if (root.capture !== null && pixels.isImageLoaded(root.capture.url)) {
                const context = pixels.getContext("2d");
                context.clearRect(0, 0, pixels.width, pixels.height);
                context.drawImage(root.capture.url, 0, 0, pixels.width, pixels.height);
                if (root.transferring) {
                    const cutout = root.pixelAt(context, root.cardCenter);
                    check.within("the outgoing mask carries the category cutout", cutout[3] / 255, 1, 2 / 255);
                    check.within("the outgoing mask retains the category's paint opacity", cutout[0] / 255, root.cardPaintOpacity, 2 / 255);
                    check.within("the outgoing mask excludes the gap", root.alphaAt(context, root.cardGap), 0, 2 / 255);
                } else {
                    check.attempt("category glass pixels", () => root.checkPixels(context));
                }
                pixels.unloadImage(root.capture.url);
                root.capture = null;
                if (root.transferring)
                    check.done();
                else if (root.scaled)
                    Qt.callLater(root.handOff);
                else
                    Qt.callLater(root.scaleCategory);
            }
        }
    }

    Timer {
        id: settle
        interval: Appearance.t.popupFade + Appearance.t.popupResize + Appearance.t.base + Appearance.t.grace
        onTriggered: {
            root.captureSize = Qt.size(notes.cardItem.width, notes.cardItem.height);
            if (!notes.cardItem.grabToImage(root.loadCapture, root.captureSize)) {
                check.report("the notes popup can be captured", false, "the surface is not mapped");
                check.done();
            }
        }
    }

    function loadCapture(result: var): void {
        root.capture = result;
        pixels.loadImage(result.url);
        if (pixels.isImageLoaded(result.url))
            pixels.requestPaint();
    }

    function find(item: Item, matches: var): Item {
        if (matches(item))
            return item;
        for (const child of item.children) {
            const found = root.find(child, matches);
            if (found)
                return found;
        }
        return null;
    }

    function tile(key: string): DailyNoteCategory {
        return root.find(notes.cardItem, item => item instanceof DailyNoteCategory && item.category === key) as DailyNoteCategory;
    }

    function pixelAt(context: var, point: point): var {
        return context.getImageData(Math.round(point.x), Math.round(point.y), 1, 1).data;
    }

    function alphaAt(context: var, point: point): real {
        return root.pixelAt(context, point)[3] / 255;
    }

    function cornerShortfall(context: var, card: DailyNoteCategory): real {
        const from = card.mapToItem(notes.cardItem, 0, 0);
        const to = card.mapToItem(notes.cardItem, card.radius, card.radius);
        let shortfall = 0;
        for (let y = Math.ceil(from.y); y < to.y; y++) {
            const glass = root.alphaAt(context, Qt.point(from.x - Appearance.s.xs, y));
            const minimum = Math.min(glass, card.fill.a);
            for (let x = Math.ceil(from.x); x < to.x; x++)
                shortfall = Math.max(shortfall, minimum - root.alphaAt(context, Qt.point(x, y)));
        }
        return shortfall;
    }

    function checkPixels(context: var): void {
        const work = root.tile("Work");
        const personal = root.tile("Personal");
        const left = work.mapToItem(notes.cardItem, 0, work.height / 2);
        const center = work.mapToItem(notes.cardItem, work.width / 2, work.height - Appearance.s.xs);
        const right = work.mapToItem(notes.cardItem, work.width, work.height / 2);
        const other = personal.mapToItem(notes.cardItem, 0, personal.height / 2);
        const gap = Qt.point((right.x + other.x) / 2, left.y);
        const rim = Qt.point(Appearance.s.xs, gap.y);
        const tolerance = 2 / 255;
        check.within("the card transmits through its own fill", root.alphaAt(context, center), work.fill.a, tolerance);
        const pixel = root.pixelAt(context, center);
        check.sameColor("the category tint has no popup material beneath it",
            Qt.rgba(pixel[0] / 255, pixel[1] / 255, pixel[2] / 255, pixel[3] / 255), work.fill, 2);
        check.within("the gap keeps the popup glass", root.alphaAt(context, gap), root.alphaAt(context, rim), tolerance);
        check.equal("the fixture uses rounded corners", work.radius > 0, true);
        check.within("the rounded edge is no more transparent than either glass", root.cornerShortfall(context, work), 0, tolerance);
        if (root.scaled) {
            root.cardCenter = center;
            root.cardGap = gap;
            root.cardPaintOpacity = work.fill.a;
            check.equal("the selected card extends past its resting edge", left.x < root.restingEdge.x - 2, true);
            const overlap = Qt.point((left.x + root.restingEdge.x) / 2, left.y);
            check.within("the cutout expands with the selected card", root.alphaAt(context, overlap), work.fill.a, tolerance);
        } else {
            root.restingEdge = left;
        }
    }

    function scaleCategory(): void {
        root.scaled = true;
        notes.selectCategory("Work");
        const composer = root.find(notes.cardItem, item => item.objectName === "quickNote") as DailyNoteComposer;
        composer.text = "Draft";
        settle.start();
    }

    function handOff(): void {
        root.transferring = true;
        Overlay.open(Overlay.dateMenu, Overlay.screen, Overlay.screen.width / 2);
        ready.until(Overlay.flightChanged, () => Overlay.flight?.away === true, ok => {
            const cutout = Overlay.flight?.contents?.cutout ?? null;
            check.equal("the popup flight hands off its cutouts with its content", ok && cutout !== null, true);
            check.equal("the receiving popup applies the outgoing cutouts", next.cardItem.glassCutoutMask !== null, true);
            if (ok && cutout !== null)
                root.loadCapture(cutout);
            else
                check.done();
        });
    }

    Component.onCompleted: {
        if (Quickshell.env("TEST_BIN") === "" || Quickshell.screens.length === 0) {
            check.report("isolated desktop fixture required", false, "run tools/test.sh DailyNotesMaterialTest");
            check.done();
            return;
        }
        ready.until(Settings.readyChanged, () => Settings.ready, ok => {
            check.equal("settings are ready", ok, true);
            if (!ok) { check.done(); return; }
            Settings.setRoundnessFollowsWindows(false);
            Settings.setOverride("roundness", 120);
            Settings.setOverride("popupOpacity", 100);
            Settings.setTheme("dark");
            ready.until(DailyNotes.readyChanged, () => DailyNotes.ready, root.openNotes);
        });
    }

    function openNotes(ok: bool): void {
        check.equal("the notes service is ready", ok, true);
        if (ok) {
            DailyNotes.addCategory(DailyNotes.today, "Work");
            DailyNotes.addCategory(DailyNotes.today, "Personal");
            const screen = Quickshell.screens[0];
            Overlay.open(Overlay.dailyNotes, screen, screen.width / 2);
            settle.start();
        } else {
            check.done();
        }
    }
}
