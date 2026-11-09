pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    A scheduled task, new or being changed: a name, the command, and when.

    The command offers the applications whose names match what is typed; one
    chosen fills in the command that starts it. A custom schedule is read by
    systemd as it is typed, which says when it would run next. Save is there
    only once all of it is good.
*/
Column {
    id: root

    /*! The task being changed, or one with no id for a new task. */
    property var task: ({})

    signal done

    readonly property var kinds: [
        { key: "once", title: qsTr("Once") }, { key: "hourly", title: qsTr("Hourly") },
        { key: "daily", title: qsTr("Daily") }, { key: "weekly", title: qsTr("Weekly") },
        { key: "calendar", title: qsTr("Custom") }, { key: "login", title: qsTr("At login") }
    ]
    readonly property var initial: TaskUnits.parts(root.task.schedule ?? "daily 09:00")
    property string kind: root.initial.kind
    property var days: root.initial.kind === "weekly" ? root.initial.rest.split(" ")[0].split(",") : ["Mon"]
    /*! systemd's reading of the custom expression: `{ valid, next }`. */
    property var reading: null
    property bool privileged: root.task.privileged ?? false
    property string pendingId: ""

    Connections {
        target: Tasks
        function onSaved(id: string): void {
            if (id === root.pendingId)
                root.done();
        }
    }

    readonly property string schedule: {
        switch (root.kind) {
        case "once": return `once ${date.text.trim()} ${time.text.trim()}`;
        case "hourly": return `hourly ${String(Number(minute.text.trim() || "x"))}`;
        case "daily": return `daily ${time.text.trim()}`;
        case "weekly": return `weekly ${TaskUnits.days.filter(d => root.days.includes(d)).join(",")} ${time.text.trim()}`;
        case "calendar": return `calendar ${expression.text.trim()}`;
        }
        return "login";
    }
    readonly property bool valid: name.text.trim() !== "" && TaskUnits.validCommand(command.text)
        && TaskUnits.validSchedule(root.schedule) && (root.kind !== "calendar" || (root.reading?.valid ?? false))

    readonly property var suggestions: command.input.activeFocus && command.text.trim() !== ""
        ? Apps.search(command.text.trim()).slice(0, 4) : []

    function quoted(words: var): string {
        return words.map(w => /^[\w@%+=:,./-]+$/.test(w) ? w : "'" + w.replace(/'/g, "'\\''") + "'").join(" ");
    }

    function save(): void {
        if (!root.valid || Tasks.busy)
            return;
        root.pendingId = Tasks.save({ id: root.task.id ?? "", name: name.text.trim(),
            command: command.text.trim(), schedule: root.schedule, privileged: root.privileged });
    }

    spacing: Appearance.s.lg

    Component.onCompleted: {
        const words = root.initial.rest.split(" ");
        const tomorrow = new Date(Date.now() + 24 * 3600 * 1000);
        name.text = root.task.name ?? "";
        command.text = root.task.command ?? "";
        date.text = root.kind === "once" ? words[0] : Qt.formatDate(tomorrow, "yyyy-MM-dd");
        time.text = ["once", "weekly"].includes(root.kind) ? words[1] : root.kind === "daily" ? words[0] : "09:00";
        minute.text = root.kind === "hourly" ? words[0] : "0";
        expression.text = root.kind === "calendar" ? root.initial.rest : "";
        name.input.forceActiveFocus();
    }

    SettingGroup {
        width: root.width
        title: root.task.id ? qsTr("Change task") : qsTr("New task")
        enabled: !Tasks.busy

        InputField {
            id: name
            width: parent.width
            placeholder: qsTr("Name")
            onAccepted: command.input.forceActiveFocus()
        }

        InputField {
            id: command
            width: parent.width
            placeholder: qsTr("Command, or an application's name")
            onAccepted: root.save()
        }

        Repeater {
            model: root.suggestions

            MenuRow {
                required property var modelData

                width: parent.width
                implicitHeight: Appearance.m.navRowHeight
                title: this.modelData.name
                subtitle: root.quoted(this.modelData.command)
                onClicked: {
                    command.text = root.quoted(this.modelData.command);
                    if (name.text.trim() === "")
                        name.text = this.modelData.name;
                    command.input.forceActiveFocus();
                    command.input.deselect();
                    command.input.cursorPosition = command.text.length;
                }
            }
        }

        MenuRow {
            width: parent.width
            flush: true
            icon: "lock"
            title: qsTr("Run as administrator")
            subtitle: qsTr("Authorize on save; future runs need no password.")
            onClicked: root.privileged = !root.privileged

            ToggleSwitch {
                checked: root.privileged
                onToggled: value => root.privileged = value
            }
        }

        Label {
            width: parent.width
            visible: root.privileged
            text: qsTr("The entire command runs as root, including redirects and pipes. "
                + "Use full paths. Changing or removing its authorization asks again.")
            role: Label.Role.Small
            muted: true
            wrapMode: Text.Wrap
        }
    }

    SettingGroup {
        width: root.width
        title: qsTr("When")
        enabled: !Tasks.busy

        Flow {
            width: parent.width
            spacing: Appearance.s.xs

            Repeater {
                model: root.kinds

                TextButton {
                    required property var modelData

                    compact: true
                    text: this.modelData.title
                    kind: root.kind === this.modelData.key ? TextButton.Kind.Accent : TextButton.Kind.Normal
                    onClicked: root.kind = this.modelData.key
                }
            }
        }

        Row {
            visible: root.kind === "weekly"
            spacing: Appearance.s.xs

            Repeater {
                model: TaskUnits.days

                TextButton {
                    required property string modelData

                    compact: true
                    text: Qt.locale().dayName((TaskUnits.days.indexOf(this.modelData) + 1) % 7, Locale.ShortFormat)
                    selected: root.days.includes(this.modelData)
                    onClicked: root.days = this.selected ? root.days.filter(d => d !== this.modelData)
                                                         : root.days.concat([this.modelData])
                }
            }
        }

        Row {
            spacing: Appearance.s.md
            visible: root.kind !== "calendar" && root.kind !== "login"

            InputField {
                id: date
                visible: root.kind === "once"
                width: Appearance.m.wideColumn + Appearance.s.xl
                placeholder: qsTr("YYYY-MM-DD")
            }

            InputField {
                id: time
                visible: root.kind !== "hourly"
                width: Appearance.m.wideColumn
                placeholder: qsTr("HH:MM")
            }

            InputField {
                id: minute
                visible: root.kind === "hourly"
                width: Appearance.m.wideColumn
                placeholder: qsTr("Minute")
            }
        }

        InputField {
            id: expression
            width: parent.width
            visible: root.kind === "calendar"
            placeholder: qsTr("A systemd calendar expression, e.g. Sat *-*-1..7 18:00")
            onTextChanged: Tasks.validate(this.text, reading => root.reading = reading)
        }

        Label {
            width: parent.width
            text: root.kind === "login" ? qsTr("Runs each time you log in.")
                : root.kind !== "calendar" ? (TaskUnits.validSchedule(root.schedule) ? TaskUnits.describe(root.schedule) : qsTr("Not a time"))
                : !(root.reading?.valid ?? false) ? qsTr("Not a calendar expression")
                : root.reading.next > 0 ? qsTr("Next: %1").arg(Tasks.formatWhen(root.reading.next)) : qsTr("Never runs again")
            role: Label.Role.Small
            color: root.valid || name.text.trim() === "" || !TaskUnits.validCommand(command.text)
                ? PopupStyle.muted : PopupStyle.danger
            wrapMode: Text.Wrap
        }
    }

    Row {
        anchors.right: parent.right
        spacing: Appearance.s.md

        TextButton {
            text: qsTr("Cancel")
            enabled: !Tasks.busy
            onClicked: root.done()
        }

        TextButton {
            text: Tasks.busy ? qsTr("Saving…") : qsTr("Save")
            kind: TextButton.Kind.Accent
            enabled: root.valid && !Tasks.busy
            onClicked: root.save()
        }
    }
}
