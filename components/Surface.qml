pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"

/*!
    A glass panel: the base of every bar, dock, popover and card.

    The surface colour at the theme's glass opacity, edged with a hairline and
    lifted by a Shadow. What shows through is blurred by the compositor, which
    blurs a shell surface wherever it is more than half opaque (see the layer
    rule in hyprland.conf) — so the shadow around a panel stays crisp paint and
    only the panel itself frosts. A card resting on another surface passes one
    of the washes (`raised`) as its colour instead, and is glass by inheritance.
*/
Item {
    id: root

    /*!
        The scheme its glass is tinted with: the theme's, unless the user has
        thinned it over a wallpaper the theme's text would no longer read on
        (Appearance.glassOver), going by the mean of the wallpaper behind the
        whole of it (Backdrop). Only the bar and the dock know where they are
        (`screen`); every other surface is the theme's.
    */
    readonly property ColorScheme scheme: {
        const behind = Backdrop.colorUnder(root.screen,
            Qt.rect(root.placedAt.x, root.placedAt.y, root.width, root.height));
        return behind === null ? Appearance.c : Appearance.glassOver(behind, root.glass);
    }
    property color color: root.scheme.chrome
    property int radius: Appearance.r.md
    property int elevation: 2
    property bool bordered: true
    property color borderColor: root.scheme.border
    /*! How much of its glass it lays down: its fill, hairline and shadow
        together, its content untouched — the bar and the dock at the user's
        opacity (Appearance.barOpacity). Each faded by its own alpha, so it
        never passes through another colour, and eased, so a step (a reset,
        the dock taking up the bar's) fades rather than jumps. */
    property real glass: 1
    /*! The screen it rests on and where — its top-left there, in the
        screen's logical pixels — for `scheme` and `schemeOver`. Set by the
        bar and the dock, whose glass the user can thin; null elsewhere. */
    property ShellScreen screen: null
    property point placedAt: Qt.point(0, 0)
    default property alias content: inner.data

    /*!
        The colours that read on it under `item`, anything laid on it: its own
        scheme's, or the other's where what shows through there calls for it
        (Appearance.schemeOn) — what is under the item being the fill at its
        glass over the mean of the wallpaper behind the item alone. Where the
        wallpaper is not known, the theme's.

        It goes by where the item rests, not where it is drawn: its parents'
        positions up to the surface, which the binding that calls this hears
        change one by one (mapToItem would hide them), and `placedAt` —
        so a dock sliding in reads as it will at rest.
    */
    function schemeOver(item: Item): ColorScheme {
        let x = root.placedAt.x;
        let y = root.placedAt.y;
        for (let p = item; p !== null && p !== root; p = p.parent) {
            x += p.x;
            y += p.y;
        }
        const behind = Backdrop.colorUnder(root.screen, Qt.rect(x, y, item.width, item.height));
        return behind === null
            ? Appearance.c : Appearance.schemeOn(Appearance.laid(root.color, behind, root.glass));
    }

    Behavior on glass {
        NumberAnimation { duration: Appearance.t.base; easing.type: Appearance.t.standardEasing }
    }

    Shadow {
        anchors.fill: parent
        radius: root.radius
        level: root.elevation
        opacity: root.glass
    }

    Rectangle {
        id: inner
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(root.color, root.color.a * root.glass)
        border.width: root.bordered ? Appearance.m.border : 0
        border.color: Qt.alpha(root.borderColor, root.borderColor.a * root.glass)
        antialiasing: root.radius > 0
    }
}
