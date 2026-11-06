pragma ComponentBehavior: Bound

import QtQuick
import "root:/components"

/*! QS icon action with a name shared by assistive technology and its tooltip. */
IconButton {
    id: root
    required property string label
    property bool tipBelow: false
    Accessible.role: Accessible.Button
    Accessible.name: root.label

    Tooltip {
        id: tip
        objectName: "tooltip:" + root.label
        parent: root.Window.contentItem ?? root
        // mapToItem alone does not subscribe to ancestors moving during layout
        // or scrolling. Read every position on the path to the window.
        readonly property point at: {
            if (!tip.show && !tip.visible) return Qt.point(0, 0);
            let x = root.width / 2;
            let y = root.tipBelow ? root.height : 0;
            for (let item = root; item && item !== tip.parent; item = item.parent) {
                x += item.x;
                y += item.y;
            }
            return Qt.point(x, y);
        }
        anchorX: at.x
        anchorY: at.y
        below: root.tipBelow
        text: root.label
        show: root.Window.window !== null && root.visible && root.enabled && (root.hovered || root.focusVisible)
        z: 1
    }
}
