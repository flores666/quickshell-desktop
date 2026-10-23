pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    One theme, as a picture of the desktop in it: the wallpaper that is up,
    with a bar, a card and a dock drawn over it in that theme's own tokens.

    Drawn from the scheme it is given rather than from `Appearance.c`, so the
    theme that is not in force still shows as it would look — seeds and accent
    included. Its furniture is laid out in fractions of the picture, which is
    all a miniature has to stay true to.
*/
Clickable {
    id: root

    // Clickable's own, which its focus ring is drawn in as well.
    required scheme
    required property string title

    implicitHeight: preview.height + caption.height + Appearance.s.sm * 3
    radius: Appearance.r.lg
    showStateLayer: false

    ClippingRectangle {
        id: preview

        /*! A hundredth of the picture's width: the unit its furniture is laid out in. */
        readonly property real u: preview.width / 100

        x: Appearance.s.sm
        y: Appearance.s.sm
        width: root.width - Appearance.s.sm * 2
        height: Math.round(preview.width * 9 / 16)
        radius: Appearance.r.md
        color: root.scheme.base
        border.width: root.selected ? Appearance.m.focusRing : Appearance.m.border
        border.color: root.selected ? Appearance.c.accent
            : root.hovered ? Appearance.c.borderStrong : Appearance.c.border

        Image {
            anchors.fill: parent
            visible: Wallpaper.current !== ""
            source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 360
            asynchronous: true
            cache: true
        }

        Rectangle {
            // The bar.
            x: preview.u * 5
            y: preview.u * 4
            width: preview.u * 90
            height: preview.u * 6
            radius: height / 2
            color: root.scheme.chrome

            Rectangle {
                anchors.centerIn: parent
                width: preview.u * 12
                height: preview.u * 1.6
                radius: height / 2
                color: root.scheme.text
                opacity: 0.7
            }

            Rectangle {
                x: preview.u * 3
                anchors.verticalCenter: parent.verticalCenter
                width: preview.u * 5
                height: preview.u * 1.6
                radius: height / 2
                color: root.scheme.accent
            }
        }

        Rectangle {
            // A popup card, with a line of text and an engaged control.
            x: preview.u * 8
            y: preview.u * 16
            width: preview.u * 44
            height: preview.u * 28
            radius: preview.u * 3
            color: root.scheme.chrome
            border.width: 1
            border.color: root.scheme.border

            Column {
                x: preview.u * 4
                y: preview.u * 4
                spacing: preview.u * 2.5

                Rectangle {
                    width: preview.u * 24
                    height: preview.u * 2.2
                    radius: height / 2
                    color: root.scheme.text
                }

                Rectangle {
                    width: preview.u * 32
                    height: preview.u * 1.8
                    radius: height / 2
                    color: root.scheme.textMuted
                }

                Row {
                    spacing: preview.u * 2

                    Rectangle {
                        width: preview.u * 17
                        height: preview.u * 7
                        radius: preview.u * 2
                        color: root.scheme.accentSoft

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: preview.u * 1.5
                            width: preview.u * 4
                            height: width
                            radius: width / 2
                            color: root.scheme.accent
                        }
                    }

                    Rectangle {
                        width: preview.u * 17
                        height: preview.u * 7
                        radius: preview.u * 2
                        color: root.scheme.raised
                    }
                }
            }
        }

        Rectangle {
            // The dock.
            anchors.horizontalCenter: parent.horizontalCenter
            y: preview.height - height - preview.u * 3
            width: preview.u * 38
            height: preview.u * 8
            radius: height / 2
            color: root.scheme.chrome

            Row {
                anchors.centerIn: parent
                spacing: preview.u * 2

                Repeater {
                    model: 5

                    Rectangle {
                        required property int index

                        width: preview.u * 4.5
                        height: width
                        radius: preview.u * 1.2
                        color: index === 1 ? root.scheme.accent : root.scheme.textMuted
                        opacity: index === 1 ? 1 : 0.55
                    }
                }
            }
        }
    }

    Row {
        id: caption

        anchors.horizontalCenter: parent.horizontalCenter
        y: preview.y + preview.height + Appearance.s.sm
        height: Appearance.m.iconLg
        spacing: Appearance.s.sm

        Rectangle {
            // A radio mark: a ring, filled with the accent once chosen.
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.m.iconSm
            height: width
            radius: width / 2
            color: root.selected ? Appearance.c.accent : "transparent"
            border.width: root.selected ? 0 : 1
            border.color: Appearance.c.borderStrong

            Rectangle {
                anchors.centerIn: parent
                visible: root.selected
                width: parent.width / 3
                height: width
                radius: width / 2
                color: Appearance.c.accentText
            }
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            role: Label.Role.Small
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            muted: !root.selected
        }
    }
}
