pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import "root:/components"
import "root:/config"
import "root:/services"

/*! Keep the decoded cover until its replacement is ready. Two image slots
    cross-fade; requests arriving during a fade wait for its outgoing slot. */
ClippingRectangle {
    id: root

    property url source: ""
    property PlayerState subject: null
    property string trackKey: ""
    property bool animate: false
    property real blend: 1
    property Cover current: second
    readonly property Cover pending: root.current === first ? second : first
    property PlayerState shownSubject: null
    property string shownKey: ""
    property bool initialized: false

    implicitWidth: Appearance.m.mediaArt
    implicitHeight: Appearance.m.mediaArt
    radius: Appearance.r.sm
    // Each slot is a complete, opaque picture, including transparent artwork
    // and the fallback. Fading it over the old slot avoids a mid-fade dark dip.
    color: Qt.tint(Appearance.c.surface, Appearance.c.sunken)

    onSourceChanged: Qt.callLater(root.load)
    onSubjectChanged: Qt.callLater(root.load)
    onTrackKeyChanged: Qt.callLater(root.load)
    onAnimateChanged: if (!root.animate) fade.complete()
    Component.onCompleted: root.load()

    function load(): void {
        if (!root.current || !root.pending || fade.running) return;
        if (!root.needsReplacement()) {
            root.pending.source = "";
            root.remember();
            return;
        }
        root.pending.source = root.source;
        root.present(root.pending);
    }

    function needsReplacement(): bool {
        return root.current.source.toString() !== root.source.toString()
            || (root.current.status === Image.Error
                && (root.subject !== root.shownSubject || root.trackKey !== root.shownKey));
    }

    function present(image: Cover): void {
        if (fade.running || image !== root.pending
            || image.source.toString() !== root.source.toString()
            || !root.needsReplacement()
            || image.status === Image.Loading
            || (image.status === Image.Null && root.source.toString() !== "")) return;
        const changing = root.initialized && root.shownKey !== ""
            && (root.subject !== root.shownSubject || root.trackKey !== root.shownKey);
        root.blend = 0;
        root.current = image;
        root.remember();
        if (root.animate && changing) fade.start();
        else {
            root.blend = 1;
            root.release();
        }
    }

    function remember(): void {
        root.shownSubject = root.subject;
        root.shownKey = root.trackKey;
        root.initialized = true;
    }

    function release(): void {
        root.pending.source = "";
        root.load();
    }

    NumberAnimation {
        id: fade
        target: root
        property: "blend"
        from: 0; to: 1
        duration: Appearance.t.mediaChange
        easing.type: Appearance.t.mediaEasing
        onStopped: root.release()
    }

    component Cover: Rectangle {
        id: cover
        property alias source: image.source
        property alias status: image.status
        anchors.fill: parent
        z: root.current === cover ? 1 : 0
        opacity: root.current === cover ? root.blend : 1
        color: root.color
        // Fade the composed well, glyph and image once, not each child.
        layer.enabled: fade.running

        Icon {
            anchors.centerIn: parent
            visible: image.status !== Image.Ready
            name: "music"
            size: Appearance.m.mediaFallback
            color: PopupStyle.muted
        }

        Image {
            id: image
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Appearance.m.mediaArt * 2
            sourceSize.height: Appearance.m.mediaArt * 2
            asynchronous: true
            cache: true
            onStatusChanged: Qt.callLater(root.load)
        }
    }

    Cover { id: first }
    Cover { id: second }
}
