pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules/common"

/*!
    The settings surface: everything about the shell a user is allowed to change.

    One tab per thing that can be configured, and each thing in exactly one tab:
    the dock's hide delay is under Dock rather than filed with the other
    timings, and the border and corner radius every surface is drawn with are
    under Appearance rather than under the panel that happened to need them
    first.  Somewhere to look is worth more than a tidy grouping of like
    controls.

    Sections down the left, one of them on the right, and a search above that
    narrows the sections to those holding what was typed.  A list rather than the
    sub-page slide quick settings uses — quick settings is a popover you dip
    into and dismiss, where a page at a time is the point; this is somewhere you
    stay while you try values, and losing your place on every move would make
    comparing two of them tedious.

    Every control writes straight through to Settings and the shell redraws as
    you drag.  Bar height and the gaps around it change what the bar reserves,
    so the compositor relays out the windows underneath while you move them —
    that is the honest cost of seeing the change rather than a preview of it.
    Nothing here previews; there is no apply button and nothing to cancel.
*/
ShellOverlay {
    id: root

    overlayId: Overlay.settings
    placement: ShellOverlay.Placement.Centre
    cardWidth: Math.min(820, (root.screen ? root.screen.width : 1920) - Appearance.s.huge * 2)
    cardHeight: Math.min(580, (root.screen ? root.screen.height : 1080) - Appearance.s.huge * 3)

    /*! Every section, in the order the sidebar lists them. */
    readonly property var sections: [
        { key: "appearance", title: qsTr("Appearance"), icon: "night-light", component: appearanceSection },
        { key: "wallpaper", title: qsTr("Wallpaper"), icon: "wallpaper", component: wallpaperSection },
        { key: "panel", title: qsTr("Top panel"), icon: "display", component: panelSection },
        { key: "dock", title: qsTr("Dock"), icon: "apps", component: dockSection },
        { key: "notifications", title: qsTr("Notifications"), icon: "bell", component: notificationsSection },
        { key: "windows", title: qsTr("Windows"), icon: "window", component: windowsSection },
        { key: "input", title: qsTr("Input"), icon: "mouse", component: inputSection },
        { key: "reset", title: qsTr("Reset"), icon: "refresh", component: resetSection }
    ]

    /*!
        What the search finds each section by: its title and the names of the
        controls in it, by key.

        Read off the sections themselves rather than kept beside them, so a
        control renamed is found by its new name. A section is only built while
        it is shown, so the first search of each opening builds a copy of every
        one away from the screen, reads it, and lets it go; a control this
        machine leaves out — the touchpad's, without a touchpad — is left out of
        the copy too, and is not found. Dropped when the panel closes, since
        what is left out can change while it is away.
    */
    property var index: null

    function buildIndex(): var {
        // A copy has no parent, so each item's `visible` is its own choice and
        // its ancestors' within the copy, never the screen's.
        const names = item => {
            if (!item || !item.visible)
                return [];
            const out = [item.title, item.label, item.subtitle]
                .filter(t => typeof t === "string" && t !== "");
            for (let i = 0; i < item.children.length; ++i)
                out.push(...names(item.children[i]));
            return out;
        };
        const index = {};
        for (const section of root.sections) {
            const copy = section.component.createObject(null);
            index[section.key] = [section.title].concat(names(copy)).join(" ").toLowerCase();
            copy?.destroy();
        }
        return index;
    }

    /*! The sections the search leaves, in order; all of them when it is empty. */
    readonly property var matches: {
        const needle = search.text.trim().toLowerCase();
        if (needle === "" || root.index === null)
            return root.sections;
        return root.sections.filter(s => root.index[s.key].includes(needle));
    }
    readonly property var current: root.sections.find(s => s.key === root.section)

    property string section: "appearance"

    // A search that leaves the open section out moves to the first it keeps.
    onMatchesChanged: if (root.matches.length > 0 && !root.matches.includes(root.current))
        root.section = root.matches[0].key

    // Back to the first tab once the surface is gone rather than as it comes
    // back: the pane starts building as the popup opens, and switching it then
    // threw away a half-built section — whichever was left open last time.
    onRenderedChanged: if (!root.rendered) {
        root.index = null;
        search.clear();
        root.section = "appearance";
    }

    onShownChanged: {
        if (!root.shown)
            return;
        // The scroller outlives being closed, so without this it reopens
        // wherever it was left — which since Appearance grew a type section is
        // halfway down a list the user came back to the top of.
        scroller.contentY = 0;
    }

    /*! Up and Down walk the sections the search left; Tab leaves the field. */
    function navigate(key: int): void {
        if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
            const next = search.input.nextItemInFocusChain(key === Qt.Key_Tab);
            if (next)
                next.forceActiveFocus(Qt.TabFocusReason);
            return;
        }
        const i = root.matches.indexOf(root.current);
        const step = key === Qt.Key_Down ? 1 : key === Qt.Key_Up ? -1 : 0;
        const j = Math.max(0, Math.min(root.matches.length - 1, i + step));
        if (step !== 0 && root.matches.length > 0)
            root.section = root.matches[j].key;
    }

    readonly property int navWidth: 196

    Item {
        anchors.fill: parent

        Label {
            id: heading
            anchors.left: parent.left
            anchors.verticalCenter: search.verticalCenter
            anchors.leftMargin: Appearance.s.xl
            text: qsTr("Settings")
            role: Label.Role.Subtitle
        }

        // As wide as the pane it searches, starting where the pane does.
        SearchField {
            id: search

            anchors.top: parent.top
            anchors.topMargin: Appearance.s.lg
            x: root.navWidth + Appearance.s.xl
            width: parent.width - x - Appearance.s.xl
            placeholder: qsTr("Search settings…")
            onTextChanged: if (search.text !== "" && root.index === null) root.index = root.buildIndex()
            onEscaped: Overlay.close()
            onNavigate: key => root.navigate(key)
        }

        Divider {
            id: rule
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: search.bottom
            anchors.topMargin: Appearance.s.lg
        }

        Column {
            id: nav

            anchors.left: parent.left
            anchors.top: rule.bottom
            anchors.leftMargin: Appearance.s.md
            anchors.topMargin: Appearance.s.md
            // Inset from the spine as well as from the card, or the selected
            // row's fill runs under the divider.
            width: root.navWidth - Appearance.s.md * 2
            spacing: Appearance.s.xxs

            Repeater {
                model: root.matches

                MenuRow {
                    required property var modelData

                    width: nav.width
                    implicitWidth: nav.width
                    implicitHeight: Appearance.m.navRowHeight
                    spacing: Appearance.s.md
                    title: this.modelData.title
                    icon: this.modelData.icon
                    selected: root.section === this.modelData.key
                    onClicked: root.section = this.modelData.key
                }
            }

            Label {
                visible: root.matches.length === 0
                width: nav.width
                leftPadding: Appearance.s.lg
                topPadding: Appearance.s.md
                text: qsTr("Nothing matches")
                role: Label.Role.Small
                faint: true
            }
        }

        Divider {
            id: spine
            anchors.left: parent.left
            anchors.leftMargin: root.navWidth
            anchors.top: rule.bottom
            anchors.bottom: parent.bottom
            vertical: true
        }

        Flickable {
            id: scroller

            anchors.left: spine.right
            anchors.right: parent.right
            anchors.top: rule.bottom
            anchors.bottom: parent.bottom
            anchors.margins: Appearance.s.xl
            clip: true
            contentHeight: page.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: page

                /*! Clear of the scrollbar, which floats over the pane's
                    trailing edge rather than taking room in the layout. */
                width: scroller.width - scrollbar.footprint
                spacing: Appearance.s.lg

                Label {
                    text: root.current?.title ?? ""
                    role: Label.Role.Title
                }

                Loader {
                    id: pane

                    width: page.width
                    // Built afresh for every visit and dropped once the surface
                    // is gone, so nothing a pane holds for the moment — a colour
                    // picker left open, a font filter half typed — is there
                    // next time.
                    active: root.rendered
                    sourceComponent: root.current?.component ?? null
                }
            }
        }

        ThinScrollBar { id: scrollbar; flickable: scroller }
    }

    Component { id: appearanceSection; AppearanceSection { width: pane.width } }
    Component { id: wallpaperSection; WallpaperSection { width: pane.width } }
    Component { id: panelSection; PanelSection { width: pane.width } }
    Component { id: dockSection; DockSection { width: pane.width } }
    Component { id: notificationsSection; NotificationsSection { width: pane.width } }
    Component { id: windowsSection; WindowsSection { width: pane.width } }
    Component { id: inputSection; InputSection { width: pane.width } }
    Component { id: resetSection; ResetSection { width: pane.width } }
}
