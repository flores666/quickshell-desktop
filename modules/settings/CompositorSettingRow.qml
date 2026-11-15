pragma ComponentBehavior: Bound

import QtQuick
import "root:/services"

/*! One compositor setting, using the same limits and current value as its
    service. Sections only choose the label and display units. */
SettingRow {
    readonly property var limits: CompositorOptions.spec[this.key]

    width: parent.width
    min: this.limits.min
    max: this.limits.max
    known: CompositorOptions.known(this.key)
    value: this.known ? CompositorOptions.value(this.key) : this.min
}
