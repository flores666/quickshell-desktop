pragma ComponentBehavior: Bound

import QtQuick

/*! Place the departing picture and its glass cutouts together during a flight. */
Item {
    id: root

    required property Item captureSource
    required property Item frame
    required property var picture
    required property size pictureSize
    required property real incoming
    required property real outgoing
    property Component glassCutouts: null
    readonly property Item cutoutMask: root.glassCutouts !== null || departingMask.source.toString() !== "" ? mask : null

    function capture(then: var): bool {
        const ratio = root.Screen.devicePixelRatio;
        const size = Qt.size(Math.ceil(root.width * ratio), Math.ceil(root.height * ratio));
        const cutoutMask = root.cutoutMask;
        let image = null;
        let cutout = null;
        const publish = () => {
            if (image !== null && (cutoutMask === null || cutout !== null))
                then(cutout === null ? image : { url: image.url, image, cutout });
        };
        return root.captureSource.grabToImage(result => {
            image = result;
            publish();
        }, size) && (cutoutMask === null || cutoutMask.grabToImage(result => {
            cutout = result;
            publish();
        }, size));
    }

    Image {
        id: departing
        anchors.centerIn: parent
        width: root.pictureSize.width
        height: root.pictureSize.height
        visible: root.outgoing > 0 && root.picture !== null
        source: root.picture?.url ?? ""
        opacity: root.outgoing
        cache: false
    }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: root.cutoutMask !== null && root.visible

        Loader {
            x: root.frame.x
            y: root.frame.y
            width: root.frame.width
            height: root.frame.height
            opacity: root.incoming
            sourceComponent: root.glassCutouts
        }

        Image {
            id: departingMask
            x: departing.x
            y: departing.y
            width: departing.width
            height: departing.height
            visible: departing.visible
            source: root.picture?.cutout?.url ?? ""
            opacity: departing.opacity
            cache: false
        }
    }
}
