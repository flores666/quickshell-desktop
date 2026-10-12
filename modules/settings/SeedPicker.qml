pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    One colour seed: the curated choices, the colours made for it before, and a
    picker for a new one.

    A picked colour is applied as it is dragged and remembered when the drag
    ends. The remembered ones are those of Settings.recentColors and
    pinnedColors that fall inside this seed's range, and they make a queue of
    one row: a new colour goes in at the front, the oldest drops out of sight
    at the back, and a pinned one holds its place at the end however many come
    after it. Choosing a remembered colour applies it and leaves the order
    alone. A right click opens a menu to pin, unpin or remove one.
*/
Column {
    id: root

    required property string title
    /*! Appearance.seedRange's name for it. */
    required property string seed
    /*! The curated choices; "" first, meaning the theme's own colour. */
    required property var presets
    /*! The setting as stored: "" or a colour. */
    required property string current
    /*! What "" looks like right now. */
    required property color defaultColor

    signal chosen(string value)

    readonly property var range: Appearance.seedRange(root.seed)
    readonly property var remembered: {
        const fits = c => Appearance.inSeedRange(c, root.range);
        const pinned = Settings.pinnedColors.filter(fits);
        return Settings.recentColors.filter(fits)
            .slice(0, Math.max(0, root.capacity - pinned.length))
            .concat(pinned)
            .slice(0, root.capacity);
    }
    /*! How many remembered colours the row holds beside its add button. */
    readonly property int capacity: root.columns - 1
    readonly property int columns: 9
    property bool picking: false
    /*! The colour this visit to the picker last remembered; the next one
        replaces it. */
    property string made: ""

    onPickingChanged: root.made = ""

    /*! A swatch rather than the picker: what the picker made is kept. */
    function choose(value: string): void {
        root.made = "";
        root.chosen(value);
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

    Grid {
        width: root.width
        columns: root.columns
        spacing: Appearance.s.md

        Repeater {
            model: root.presets

            Swatch {
                required property string modelData

                color: this.modelData === "" ? root.defaultColor : this.modelData
                isDefault: this.modelData === ""
                selected: root.current === this.modelData
                onClicked: root.choose(this.modelData)
            }
        }
    }

    Grid {
        width: root.width
        columns: root.columns
        spacing: Appearance.s.md

        Repeater {
            model: root.remembered

            Swatch {
                required property string modelData

                acceptedButtons: Qt.LeftButton | Qt.RightButton
                color: this.modelData
                pinned: Settings.isColorPinned(this.modelData)
                selected: root.current === this.modelData
                onClicked: root.choose(this.modelData)
                onRightClicked: {
                    const value = this.modelData;
                    Overlay.openMenu(this, [
                        this.pinned
                            ? { label: qsTr("Unpin"), icon: "pin", run: () => Settings.togglePinnedColor(value) }
                            : { label: qsTr("Pin"), icon: "pin", run: () => Settings.togglePinnedColor(value) },
                        { label: qsTr("Remove"), icon: "trash", danger: true, run: () => Settings.forgetColor(value) }
                    ]);
                }
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
                if (root.presets.indexOf(value) !== -1)
                    return;
                Settings.rememberColor(value, root.made);
                root.made = value;
            }
        }
    }
}
