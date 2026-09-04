pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    One clock for the whole shell.

    SystemClock ticks on the minute boundary rather than on an interval, so there
    is exactly one wakeup per minute no matter how many monitors are attached.
*/
Singleton {
    id: root

    readonly property date now: clock.date
    /*!
        The locale's short time format with any seconds field removed: the clock
        only ticks once a minute, so showing a frozen ":00" would be a lie.
    */
    readonly property string timeFormat: {
        const f = Qt.locale().timeFormat(Locale.ShortFormat).replace(/[.:]?\bs+/g, "").trim();
        return f.includes("m") ? f : "HH:mm";
    }

    readonly property string time: Qt.formatTime(root.now, root.timeFormat)
    readonly property string dateShort: Qt.formatDate(root.now, "ddd d MMM")
    readonly property string dateLong: Qt.formatDate(root.now, Locale.LongFormat)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
