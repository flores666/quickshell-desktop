import QtQuick

/*!
    Waits on a service's state: `until` calls back with true once `done()`
    holds, asked now and each time `changed` (a property's change signal)
    fires, or with false after `bound`. One wait at a time.
*/
QtObject {
    id: root

    property int bound: 5000
    property var pending: null

    function until(changed: var, done: var, then: var): void {
        const wait = { changed, done, then, look: () => root.look() };
        root.pending = wait;
        changed.connect(wait.look);
        root.timeout.restart();
        root.look();
    }

    function look(): void {
        const wait = root.pending;
        if (wait !== null && wait.done())
            root.answer(true);
    }

    function answer(ok: bool): void {
        const wait = root.pending;
        if (wait === null)
            return;
        root.pending = null;
        root.timeout.stop();
        wait.changed.disconnect(wait.look);
        wait.then(ok);
    }

    readonly property Timer timeout: Timer {
        interval: root.bound
        onTriggered: root.answer(false)
    }
}
