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
    Or the accent matches the wallpaper (Appearance.fromWallpaper), and goes
    out to GTK, the terminal and the window border too (DesktopTheme).
*/
Column {
    id: root

    spacing: Appearance.s.lg

    // While the accent follows the wallpaper this row drives nothing, so it is
    // not offered.
    SeedPicker {
        objectName: "accentPicker"
        width: root.width
        visible: !Appearance.followsWallpaper
        title: qsTr("Accent")
        seed: "accent"
        presets: Appearance.seedChoices("accent")
        current: Settings.accentColor
        defaultColor: Appearance.c.accent
        onChosen: value => Settings.setAccentColor(value)
    }

    /*! Absent until the wallpaper has been measured: there would be nothing
        to follow. */
    MenuRow {
        objectName: "matchWallpaper"
        width: root.width
        visible: Settings.wallpaperAccent !== ""
        flush: true
        title: qsTr("Match wallpaper")
        subtitle: qsTr("The accent follows the wallpaper's main color")
        onClicked: Settings.setAccentFollowsWallpaper(!Settings.accentFollowsWallpaper)

        ToggleSwitch {
            checked: Settings.accentFollowsWallpaper
            onToggled: value => Settings.setAccentFollowsWallpaper(value)
        }
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
        text: qsTr("Only this shell is affected, unless the accent matches the wallpaper: GTK applications, the terminal and the window border then take it too. Right-click a color to pin or remove it.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
