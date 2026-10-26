pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    earlyoom's own options: whether it runs, the levels it acts at, and its
    two lists of names.

    Unlike the settings panel, nothing here takes effect as it is moved:
    the options are root's, and every write asks for the password (pkexec),
    so changes are gathered (`staged`) and applied together — Apply and
    Revert show only while there is something to apply. A process is put in
    a list from its menu in Processes, which applies at once.
*/
Column {
    id: root

    /*! The options as edited, or null for none edited. */
    property var staged: null
    readonly property var draft: root.staged ?? EarlyOom.config
    readonly property bool dirty: root.staged !== null
        && EarlyOomArgs.format(root.staged) !== EarlyOomArgs.format(EarlyOom.config)
    readonly property bool hasSwap: Processes.memory.swapTotal > 0

    function stage(changes: var): void {
        root.staged = Object.assign({}, root.draft, changes);
    }

    /*! A level moved: SIGKILL's never above SIGTERM's, which takes it along. */
    function level(prefix: string, which: string, value: int): void {
        const term = which === "Term" ? value : Math.max(value, root.draft[prefix + "Term"]);
        const kill = which === "Kill" ? value : Math.min(value, root.draft[prefix + "Kill"]);
        root.stage({ [prefix + "Term"]: term, [prefix + "Kill"]: Math.min(kill, term) });
    }

    // Once the file says what was applied, there is nothing left to apply.
    Connections {
        target: EarlyOom
        function onConfigChanged(): void {
            if (!root.dirty)
                root.staged = null;
        }
    }

    spacing: Appearance.s.lg

    SettingGroup {
        width: root.width
        title: qsTr("earlyoom")

        MenuRow {
            width: parent.width
            flush: true
            title: EarlyOom.running ? qsTr("Running") : qsTr("Stopped")
            subtitle: EarlyOom.running
                ? qsTr("Stops the process using the most memory once memory and swap are both this low")
                : qsTr("Nothing stops a process before the machine runs out of memory")

            TextButton {
                visible: !EarlyOom.running
                compact: true
                text: qsTr("Start")
                enabled: !EarlyOom.pending
                onClicked: EarlyOom.apply(root.draft)
            }
        }

        ThresholdRow {
            width: parent.width
            label: qsTr("Memory left when a process is asked to quit")
            value: root.draft.memTerm
            onMoved: value => root.level("mem", "Term", value)
        }

        ThresholdRow {
            width: parent.width
            label: qsTr("Memory left when it is made to")
            value: root.draft.memKill
            onMoved: value => root.level("mem", "Kill", value)
        }

        // Without swap earlyoom counts it as none free, past every level:
        // memory alone decides, and these would change nothing.
        ThresholdRow {
            width: parent.width
            visible: root.hasSwap
            label: qsTr("Swap left when a process is asked to quit")
            value: root.draft.swapTerm
            onMoved: value => root.level("swap", "Term", value)
        }

        ThresholdRow {
            width: parent.width
            visible: root.hasSwap
            label: qsTr("Swap left when it is made to")
            value: root.draft.swapKill
            onMoved: value => root.level("swap", "Kill", value)
        }
    }

    SettingGroup {
        width: root.width
        title: qsTr("Protected")

        NameList {
            width: parent.width
            names: root.draft.avoid
            extra: root.draft.avoidExtra
            empty: qsTr("Protect a process from its menu in Processes: earlyoom stops it only when nothing else will do.")
            onRemoved: name => root.stage({ avoid: root.draft.avoid.filter(n => n !== name) })
            onRemovedExtra: root.stage({ avoidExtra: "" })
        }
    }

    SettingGroup {
        width: root.width
        title: qsTr("Killed first")

        NameList {
            width: parent.width
            names: root.draft.prefer
            extra: root.draft.preferExtra
            empty: qsTr("Mark a process from its menu in Processes to have earlyoom stop it before the others.")
            onRemoved: name => root.stage({ prefer: root.draft.prefer.filter(n => n !== name) })
            onRemovedExtra: root.stage({ preferExtra: "" })
        }
    }

    Item {
        width: root.width
        height: apply.height
        visible: root.dirty || EarlyOom.pending || EarlyOom.failure !== ""

        Label {
            anchors.left: parent.left
            anchors.right: revert.left
            anchors.rightMargin: Appearance.s.md
            anchors.verticalCenter: parent.verticalCenter
            text: EarlyOom.pending ? qsTr("Applying…") : EarlyOom.failure !== "" ? EarlyOom.failure
                : qsTr("Applying asks for your password")
            role: Label.Role.Small
            color: EarlyOom.failure !== "" && !EarlyOom.pending ? Appearance.c.danger : Appearance.c.textMuted
            elide: Text.ElideRight
        }

        TextButton {
            id: revert
            anchors.right: apply.left
            anchors.rightMargin: Appearance.s.md
            visible: root.dirty
            text: qsTr("Revert")
            enabled: !EarlyOom.pending
            onClicked: root.staged = null
        }

        TextButton {
            id: apply
            anchors.right: parent.right
            visible: root.dirty
            kind: TextButton.Kind.Accent
            text: qsTr("Apply")
            enabled: !EarlyOom.pending
            onClicked: EarlyOom.apply(root.staged)
        }
    }
}
