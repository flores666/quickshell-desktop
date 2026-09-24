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

    readonly property var accents: [
        "", "#c15f3c", "#b5453f", "#a8632a", "#6f7f45", "#3f7d6d", "#4a6f9c", "#7a5a9b", "#5c6470"
    ]
    readonly property var lightBackgrounds: [
        "", "#faf9f5", "#ffffff", "#f6f5f2", "#f7f6f9", "#f4f7f6", "#f8f5f1"
    ]
    readonly property var darkBackgrounds: [
        "", "#191817", "#141414", "#17181c", "#151a19", "#1b1720", "#1a1a1a"
    ]

    spacing: Appearance.s.lg

    SeedPicker {
        width: root.width
        title: qsTr("Accent")
        seed: "accent"
        presets: root.accents
        current: Settings.accentColor
        defaultColor: Appearance.c.accent
        onChosen: value => Settings.setAccentColor(value)
    }

    SeedPicker {
        width: root.width
        title: Appearance.dark ? qsTr("Dark background") : qsTr("Light background")
        seed: "background"
        presets: Appearance.dark ? root.darkBackgrounds : root.lightBackgrounds
        current: Appearance.dark ? Settings.backgroundDark : Settings.backgroundLight
        defaultColor: Appearance.c.base
        onChosen: value => Settings.setBackgroundColor(value)
    }

    Label {
        width: root.width
        text: qsTr("Only this shell is affected; system and application themes are left alone. Right-click a colour you made to pin it.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
