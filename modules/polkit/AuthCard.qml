pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

/*!
    The password prompt's card (AuthWindow): what is asked for and for whom,
    PAM's prompt over the field, what a failed attempt said, and Cancel and
    Authenticate. Drawn as a popup's card is: glass at the popups' share, the
    panels' radius, the window shadow.

    What it says is held from the request while there is one, so the card
    fades out still saying it: the request itself is gone by then, freed by
    the agent as it completes.
*/
Surface {
    id: root

    /*! The request (an AuthFlow), or null. */
    property var flow: null

    readonly property alias title: titleLabel
    readonly property alias message: messageLabel
    readonly property alias who: whoLabel
    readonly property alias prompt: promptLabel
    readonly property alias field: passwordField
    readonly property alias notice: noticeLabel
    readonly property alias authenticate: authenticateButton
    readonly property alias cancelButton: cancelAction

    /*! What it says: read off the request while there is one, and what it
        said last once it is gone. */
    readonly property var says: root.flow !== null ? root.read(root.flow) : root.said
    property var said: ({ message: "", who: "", prompt: "", notice: "", error: false, asking: false, echo: false })
    readonly property int pad: Appearance.s.xl

    onSaysChanged: if (root.flow !== null)
        root.said = root.says
    // Whatever was typed goes with the request, however that ends.
    onFlowChanged: if (root.flow === null)
        passwordField.text = ""

    /*! A request as the card says it. A failed attempt is said even where
        PAM said nothing, which a wrong password usually is: the field just
        emptying reads as the press having been lost. */
    function read(flow: var): var {
        const word = flow.supplementaryMessage;
        return {
            message: flow.message,
            who: flow.selectedIdentity?.displayName ?? "",
            prompt: flow.inputPrompt.trim(),
            notice: word !== "" ? word : flow.failed ? qsTr("Sorry, that didn’t work. Please try again.") : "",
            error: word !== "" ? flow.supplementaryIsError : flow.failed,
            asking: flow.isResponseRequired,
            echo: flow.responseVisible
        };
    }

    /*! As the card comes up: the field empty, and the keyboard in it. */
    function begin(): void {
        passwordField.text = "";
        passwordField.input.forceActiveFocus();
    }

    /*! Hands what was typed to the request, and empties the field for the
        next ask. It is never kept, nor logged. */
    function confirm(): void {
        if (!authenticateButton.enabled)
            return;
        const value = passwordField.text;
        passwordField.text = "";
        root.flow.submit(value);
        passwordField.input.forceActiveFocus();
    }

    function cancel(): void {
        passwordField.text = "";
        root.flow?.cancelAuthenticationRequest();
    }

    width: Appearance.m.popoverWidth
    height: body.height + root.pad * 2
    radius: Appearance.r.panel
    elevation: 3
    glass: Appearance.popupOpacity

    // Escape is the card's: the global bind leaves the popups alone while
    // the prompt is up (Overlay.authorizing).
    Keys.onPressed: event => {
        InputMode.keyboardUsed();
        if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            root.cancel();
        }
    }

    Column {
        id: body

        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        spacing: Appearance.s.lg
        // Fades as one flattened image, as a popup's contents do.
        layer.enabled: root.opacity < 1

        Row {
            spacing: Appearance.s.md

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "lock"
                size: Appearance.m.iconLg
                color: Appearance.c.accent
            }

            Label {
                id: titleLabel
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Authentication Required")
                role: Label.Role.Subtitle
            }
        }

        Label {
            id: messageLabel
            width: body.width
            text: root.says.message
            wrapMode: Text.Wrap
        }

        Row {
            visible: root.says.who !== ""
            spacing: Appearance.s.sm

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "user"
                size: Appearance.m.icon
                color: Appearance.c.textMuted
            }

            Label {
                id: whoLabel
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, body.width - Appearance.m.icon - parent.spacing)
                text: root.says.who
                muted: true
            }
        }

        Column {
            width: body.width
            spacing: Appearance.s.sm

            Label {
                id: promptLabel
                width: parent.width
                visible: root.says.prompt !== ""
                text: root.says.prompt
                role: Label.Role.Small
                muted: true
            }

            InputField {
                id: passwordField
                width: parent.width
                echoMode: root.says.echo ? TextInput.Normal : TextInput.Password
                onAccepted: root.confirm()
            }

            Label {
                id: noticeLabel
                width: parent.width
                visible: root.says.notice !== ""
                text: root.says.notice
                role: Label.Role.Small
                color: root.says.error ? Appearance.c.danger : Appearance.c.textMuted
                wrapMode: Text.Wrap
            }
        }

        Item {
            width: body.width
            height: buttons.height

            // Between a password handed over and the answer, or the next ask.
            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.flow !== null && !root.says.asking
                size: Appearance.m.icon
            }

            Row {
                id: buttons
                anchors.right: parent.right
                spacing: Appearance.s.md

                TextButton {
                    id: cancelAction
                    text: qsTr("Cancel")
                    onClicked: root.cancel()
                }

                TextButton {
                    id: authenticateButton
                    text: qsTr("Authenticate")
                    kind: TextButton.Kind.Accent
                    enabled: root.flow !== null && root.says.asking && passwordField.text !== ""
                    onClicked: root.confirm()
                }
            }
        }
    }
}
