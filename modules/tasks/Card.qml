pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

/*!
    A `raised` card on the task manager's glass, as SettingGroup's and
    StatCard's are: the readings' panes lay their figures, bars and charts on
    these. `padding` is the room inside its edge, which what it holds keeps.
*/
Rectangle {
    readonly property int padding: Appearance.s.lg

    radius: Appearance.r.lg
    color: Appearance.c.raised
    border.width: Appearance.m.border
    border.color: Appearance.c.border
}
