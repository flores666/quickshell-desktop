import QtQuick

/*!
    The tests' assertions and their report (see tools/test.sh): a PASS or FAIL
    line for every check, and `done`'s closing line, which the script waits
    for.
*/
QtObject {
    id: root

    property int failed: 0

    function report(name: string, ok: bool, detail: string): void {
        if (ok) {
            console.log("PASS", name);
        } else {
            root.failed++;
            console.log("FAIL", name + ":", detail);
        }
    }

    function equal(name: string, actual: var, expected: var): void {
        root.report(name, actual === expected, "got " + actual + ", expected " + expected);
    }

    /*! Numbers, to a thousandth. */
    function near(name: string, actual: real, expected: real): void {
        root.report(name, Math.abs(actual - expected) < 0.001, "got " + actual + ", expected " + expected);
    }

    /*! An item's box, against a rect. */
    function box(name: string, item: Item, expected: rect): void {
        const ok = Math.abs(item.x - expected.x) < 0.001 && Math.abs(item.y - expected.y) < 0.001
            && Math.abs(item.width - expected.width) < 0.001
            && Math.abs(item.height - expected.height) < 0.001;
        root.report(name, ok, "got " + Qt.rect(item.x, item.y, item.width, item.height)
            + ", expected " + expected);
    }

    function done(): void {
        console.log("TESTS DONE", root.failed, "failed");
    }
}
