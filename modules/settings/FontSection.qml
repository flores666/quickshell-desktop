pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The face the shell is set in, and how big it is.

    Every installed family is offered rather than a curated few: a font is not a
    colour seed, nothing downstream is derived from it, so there is no coherence
    to protect and no reason to withhold one.  There are a couple of hundred of
    them on an ordinary machine, which is what the filter is for.
*/
Column {
    id: root

    readonly property var families: filter.text === ""
        ? [""].concat(Fonts.families) : Fonts.search(filter.text)

    spacing: Appearance.s.lg

    SearchField {
        id: filter

        width: root.width
        placeholder: qsTr("Filter font families…")
        /*! A focused text cursor drags any Flickable above it into view, and
            this one is inside the settings pane's own scroll: with the field
            claiming focus as the section loaded, opening Appearance jumped
            straight past the colours to here. Clicking it still focuses it. */
        focus: false
    }

    Item {
        width: root.width
        height: strip.implicitHeight

        Filmstrip {
            id: strip

            anchors.fill: parent
            cellHeight: 58
            model: root.families
            currentIndex: Math.max(0, root.families.indexOf(Settings.fontFamily))

            delegate: Clickable {
                id: chip

                required property string modelData

                /*! The empty entry is the family the shell ships with. */
                readonly property bool isDefault: chip.modelData === ""
                readonly property string family: chip.isDefault
                    ? Appearance.defaultFontFamily : chip.modelData

                /*! One cell per family, all the same width: a name runs as long
                    as it likes, and a strip of ragged chips reads as a mess. */
                implicitWidth: 108
                height: strip.cellHeight
                radius: Appearance.r.md
                focusable: false
                preventStealing: true
                selected: Settings.fontFamily === chip.modelData
                onClicked: Settings.setFontFamily(chip.modelData)

                Column {
                    anchors.centerIn: parent
                    width: chip.width - Appearance.s.sm * 2
                    spacing: Appearance.s.xxs

                    Label {
                        width: parent.width
                        // The only text in the shell not set in the shell's own
                        // family: the point of a sample is that it is the other
                        // one.
                        font.family: chip.family
                        role: Label.Role.Title
                        text: qsTr("Ag")
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Label {
                        width: parent.width
                        text: chip.isDefault ? qsTr("Default") : chip.modelData
                        role: Label.Role.Caption
                        muted: !chip.selected
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Label {
            anchors.centerIn: parent
            visible: root.families.length === 0
            text: qsTr("No families match")
            faint: true
        }
    }

    SettingRow {
        width: root.width
        key: "fontScale"
        label: qsTr("Text size")
        min: Tuning.spec.fontScale.min
        max: Tuning.spec.fontScale.max
        value: Tuning.pick("fontScale")
        suffix: qsTr("%")
        step: 5
    }

    Label {
        width: root.width
        text: qsTr("A font installed while the shell is running appears the next time it starts.")
        role: Label.Role.Caption
        faint: true
        wrapMode: Text.Wrap
    }
}
