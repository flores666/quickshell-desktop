pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    Accent and background colour for the shell itself.

    Curated seeds rather than a picker: the rest of the palette is derived from
    whichever seed is chosen, so the two themes stay coherent. Anything not
    offered here can still be set by hand in settings.json.
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

    readonly property var backgrounds: Appearance.dark ? root.darkBackgrounds : root.lightBackgrounds
    readonly property string currentBackground: Appearance.dark
        ? Settings.backgroundDark : Settings.backgroundLight

    spacing: Appearance.s.lg

    Label {
        text: qsTr("Accent")
        role: Label.Role.Small
        muted: true
    }

    Grid {
        width: root.width
        columns: 9
        spacing: Appearance.s.md

        Repeater {
            model: root.accents

            Swatch {
                required property string modelData

                color: this.modelData === "" ? Appearance.c.accent : this.modelData
                isDefault: this.modelData === ""
                selected: Settings.accentColor === this.modelData
                onClicked: Settings.setAccentColor(this.modelData)
            }
        }
    }

    Label {
        text: Appearance.dark ? qsTr("Dark background") : qsTr("Light background")
        role: Label.Role.Small
        muted: true
    }

    Grid {
        width: root.width
        columns: 9
        spacing: Appearance.s.md

        Repeater {
            model: root.backgrounds

            Swatch {
                required property string modelData

                color: this.modelData === "" ? Appearance.c.base : this.modelData
                isDefault: this.modelData === ""
                selected: root.currentBackground === this.modelData
                onClicked: Settings.setBackgroundColor(this.modelData)
            }
        }
    }

    Label {
        width: root.width
        text: qsTr("Only this shell is affected; system and application themes are left alone.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
