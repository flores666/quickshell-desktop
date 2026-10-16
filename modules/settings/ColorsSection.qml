pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Accent and background colour for the shell itself.

    Curated seeds first, and a picker for anything else. The rest of the
    palette is derived from whichever seed is chosen, so the picker is held to
    the range over which the derivation stays legible (Appearance.seedRange).
*/
Column {
    id: root

    spacing: Appearance.s.lg

    SeedPicker {
        width: root.width
        title: qsTr("Accent")
        seed: "accent"
        presets: Appearance.seedChoices("accent")
        current: Settings.accentColor
        defaultColor: Appearance.c.accent
        onChosen: value => Settings.setAccentColor(value)
    }

    SeedPicker {
        width: root.width
        title: Appearance.dark ? qsTr("Dark background") : qsTr("Light background")
        seed: "background"
        presets: Appearance.seedChoices("background")
        current: Appearance.dark ? Settings.backgroundDark : Settings.backgroundLight
        defaultColor: Appearance.c.base
        onChosen: value => Settings.setBackgroundColor(value)
    }

    Label {
        width: root.width
        text: qsTr("Only this shell is affected; system and application themes are left alone. Right-click a color to pin or remove it.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
