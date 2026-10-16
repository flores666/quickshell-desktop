pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    One color seed: one row of choices, and a picker for a new one.

    The row is always a single line, as many swatches as fit and the add
    button last: the color in force first, wearing a halo; then the pinned
    ones, in the order they were pinned, newest first; then the colors made
    for this seed, newest first, and the built-in choices. What does not fit
    is out of sight, not gone. Picking a new color puts it first, since it is
    then the one in force; choosing one already in the row moves only that one
    to the front. A right click pins, unpins or removes a color, built-in
    choices included — except "", the theme's own color, which is the way back
    and stays.

    A picked color is applied as it is dragged and remembered when the drag
    ends. The remembered ones are Settings.recentColors and pinnedColors that
    fall inside this seed's range (Appearance.seedRange).
*/
Column {
    id: root

    required property string title
    /*! Appearance.seedRange's name for it. */
    required property string seed
    /*! The curated choices; "" first, meaning the theme's own color. */
    required property var presets
    /*! The setting as stored: "" or a color. */
    required property string current
    /*! What "" looks like right now. */
    required property color defaultColor

    signal chosen(string value)

    readonly property var range: Appearance.seedRange(root.seed)
    /*! The built-in choices not removed. */
    readonly property var shownPresets: root.presets
        .filter(c => c === "" || !Settings.hiddenColors.includes(c))
    /*! Every swatch the row would show given the room, in order, once each. */
    readonly property var order: {
        const fits = c => Appearance.inSeedRange(c, root.range);
        const all = [root.current]
            .concat(Settings.pinnedColors.filter(fits))
            .concat(Settings.recentColors.filter(fits))
            .concat(root.shownPresets);
        return all.filter((c, i) => all.indexOf(c) === i);
    }
    /*! How many swatches fit across, the add button among them. */
    readonly property int slots: Math.max(2, Math.floor((root.width + Appearance.s.md)
        / (Appearance.m.swatch + Appearance.s.md)))
    readonly property var row: root.order.slice(0, root.slots - 1)
    property bool picking: false
    /*! The color this visit to the picker last remembered; the next one
        replaces it. */
    property string made: ""

    onPickingChanged: root.made = ""

    /*! A swatch rather than the picker: what the picker made is kept. */
    function choose(value: string): void {
        root.made = "";
        root.chosen(value);
    }

    function openMenu(swatch: Item, value: string): void {
        if (value === "")
            return;
        const pinned = Settings.isColorPinned(value);
        Overlay.openMenu(swatch, [
            { label: pinned ? qsTr("Unpin") : qsTr("Pin"), icon: "pin",
              run: () => Settings.togglePinnedColor(value) },
            { label: qsTr("Remove"), icon: "trash", danger: true,
              run: () => Settings.forgetColor(value) }
        ]);
    }

    spacing: Appearance.s.md

    Item {
        width: root.width
        height: heading.height

        Label {
            id: heading
            text: root.title
            role: Label.Role.Small
            muted: true
        }

        Label {
            anchors.right: parent.right
            visible: root.picking
            text: picker.current.toString()
            role: Label.Role.Small
            faint: true
        }
    }

    Row {
        spacing: Appearance.s.md

        Repeater {
            model: root.row

            Swatch {
                required property string modelData
                required property int index

                acceptedButtons: Qt.LeftButton | Qt.RightButton
                color: this.modelData === "" ? root.defaultColor : this.modelData
                isDefault: this.modelData === ""
                pinned: this.modelData !== "" && Settings.isColorPinned(this.modelData)
                // The first is always the color in force.
                selected: this.index === 0
                onClicked: root.choose(this.modelData)
                onRightClicked: root.openMenu(this, this.modelData)
            }
        }

        Swatch {
            icon: root.picking ? "close" : "add"
            onClicked: root.picking = !root.picking
        }
    }

    Item {
        // Opens and closes by growing and shrinking, on the clock a popup
        // resizes on, rather than landing at full height in one frame. Clipped
        // only while it moves: at rest a knob on the plane's edge hangs over it.
        width: root.width
        height: root.picking ? picker.implicitHeight : 0
        visible: height > 0
        clip: height < picker.implicitHeight

        Behavior on height {
            NumberAnimation { duration: Appearance.t.resize; easing.type: Appearance.t.resizeEasing }
        }

        ColorPicker {
            id: picker
            width: parent.width
            opacity: root.picking ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.standardEasing }
            }

            value: root.current === "" ? root.defaultColor : root.current
            saturationRange: root.range.saturation
            valueRange: root.range.value
            onMoved: value => root.chosen(value)
            onCommitted: value => {
                if (root.shownPresets.indexOf(value) !== -1)
                    return;
                Settings.rememberColor(value, root.made);
                root.made = value;
            }
        }
    }
}
