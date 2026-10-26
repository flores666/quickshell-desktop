import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/services"
import "root:/modules/common"
import "root:/modules/tasks"
import "root:/modules/polkit"

/*!
    The polkit agent's password prompt (AuthWindow), handed a stand-in for the
    agent's AuthFlow, so that no test registers an agent for the session: its
    own surface on the overlay layer, mapped exactly while a request is asked
    about and through its fade; what it says; the field taking the keyboard as
    the card appears, Enter submitting and emptying it; a failed attempt said
    in the danger colour; Escape and Cancel cancelling; and the task manager
    under it kept open by Escape's bind and an outside click until it is gone.
    Keys and clicks are Qt's own events (TestEvent) on the window Hyprland
    gave the keyboard. And hyprpolkitagent gone from the project, the layer
    rule there.
*/
Item {
    id: root

    property var flow: null
    readonly property var card: auth.card

    Check {
        id: check
    }

    Command {
        id: sh
    }

    Until {
        id: wait
    }

    TestEvent {
        id: keys
    }

    ShellIpc {
        id: ipc
    }

    OverlaySurface {
        TaskManager {
            id: manager
        }
    }

    AuthWindow {
        id: auth
        flow: root.flow
    }

    Component {
        id: standIn

        /*! What AuthFlow says that the prompt reads, and the two calls it
            makes, noted. */
        QtObject {
            id: asked

            property string message: "Authentication is needed to run `/usr/bin/true' as the super user"
            property QtObject selectedIdentity: QtObject {
                property string displayName: "Test User"
            }
            property bool isResponseRequired: true
            property string inputPrompt: "Password: "
            property bool responseVisible: false
            property string supplementaryMessage: ""
            property bool supplementaryIsError: false
            property bool failed: false
            property var submitted: []
            property int cancelled: 0

            function submit(value: string): void {
                asked.submitted = asked.submitted.concat([value]);
                asked.isResponseRequired = false;
                asked.inputPrompt = "";
            }

            function cancelAuthenticationRequest(): void {
                asked.cancelled++;
            }
        }
    }

    function path(file: string): string {
        return Qt.resolvedUrl("../" + file).toString().replace("file://", "");
    }

    /*! Waits until `done()` holds, hearing `changed()` (a change signal),
        and goes on with `next`; where what it waits on is not there, `name`
        fails and it goes on all the same. */
    function after(name: string, bound: int, changed: var, done: var, next: var): void {
        try {
            wait.bound = bound;
            wait.until(changed(), done, ok => {
                check.equal(name, ok, true);
                next();
            });
        } catch (e) {
            check.report(name, false, String(e));
            next();
        }
    }

    /*! Types `text` into whatever has the keyboard, key by key. */
    function type(text: string): bool {
        return Array.from(text).every(c => keys.keyClickChar(c, Qt.NoModifier, -1));
    }

    /*! The overlay layer's namespaces on the nested screen. */
    function layers(then: var): void {
        sh.run("hyprctl layers -j", [], out => {
            const names = [];
            try {
                const monitors = JSON.parse(out);
                for (const m of Object.values(monitors))
                    for (const l of (m.levels["3"] ?? []))
                        names.push(l.namespace);
            } catch (e) {
                names.push("unreadable: " + e);
            }
            then(names);
        });
    }

    Component.onCompleted: {
        check.equal("no request: not mapped", auth.visible, false);
        check.equal("no request: not authorizing", Overlay.authorizing, false);
        check.attempt("its own surface", () => {
            check.equal("namespace", auth.WlrLayershell.namespace, "shell-auth");
            check.equal("on the overlay layer", auth.WlrLayershell.layer, WlrLayer.Overlay);
            check.equal("covering no panel's room", auth.exclusionMode, ExclusionMode.Ignore);
        });

        // The task manager up first, its surface mapped, as when it asks.
        ipc.run("taskManager");
        check.equal("the task manager is open", Overlay.active, Overlay.taskManager);
        root.after("the task manager drawn", 3000,
            () => manager.cardItem.opacityChanged, () => manager.cardItem.opacity === 1, root.asking);
    }

    function asking(): void {
        root.flow = standIn.createObject(root);
        check.equal("a request: mapped", auth.visible, true);
        check.equal("a request: authorizing", Overlay.authorizing, true);
        check.attempt("where", () => {
            check.equal("on the focused screen", auth.screen, Compositor.focusedScreen);
            check.equal("the keyboard on demand", auth.WlrLayershell.keyboardFocus, WlrKeyboardFocus.OnDemand);
            check.equal("input on the card alone", auth.mask?.item, root.card);
        });
        check.attempt("drawn as a popup's card", () => {
            check.equal("glass at the popups' share", root.card.glass, Appearance.popupOpacity);
            check.equal("the panels' radius", root.card.radius, Appearance.r.panel);
            check.equal("the window shadow", root.card.elevation, 3);
            check.report("fading in", root.card.opacity < 1, "opacity " + root.card.opacity);
        });
        check.attempt("what it says", () => {
            check.equal("the title", root.card.title.text, "Authentication Required");
            check.equal("the action's message", root.card.message.text, root.flow.message);
            check.equal("who is asked for", root.card.who.text, "Test User");
            check.equal("PAM's prompt", root.card.prompt.text, "Password:");
            check.equal("echo off", root.card.field.input.echoMode, TextInput.Password);
            check.equal("nothing failed: no notice", root.card.notice.text, "");
        });

        root.after("in over t.popupFade", Appearance.t.popupFade + 200,
            () => root.card.opacityChanged, () => root.card.opacity === 1,
            () => root.after("the field has the keyboard as the card appears", 3000,
                () => root.card.field.input.activeFocusChanged, () => root.card.field.input.activeFocus,
                root.submitting));
    }

    function submitting(): void {
        const flow = root.flow;
        check.attempt("centred", () => {
            check.within("across", root.card.x + root.card.width / 2, auth.width / 2, 1);
            check.within("down", root.card.y + root.card.height / 2, auth.height / 2, 1);
            check.equal("the window the screen's", auth.width, auth.screen.width);
        });
        check.attempt("submitting", () => {
            check.equal("empty: Authenticate disabled", root.card.authenticate.enabled, false);
            check.equal("typed into the field", root.type("hunter2") && root.card.field.text, "hunter2");
            check.equal("typed: Authenticate enabled", root.card.authenticate.enabled, true);
            flow.isResponseRequired = false;
            check.equal("nothing asked: Authenticate disabled", root.card.authenticate.enabled, false);
            flow.isResponseRequired = true;
            flow.responseVisible = true;
            check.equal("echo on when PAM asks for it", root.card.field.input.echoMode, TextInput.Normal);
            flow.responseVisible = false;
            check.equal("Enter reaches the field", keys.keyClick(Qt.Key_Return, Qt.NoModifier, -1), true);
            check.equal("Enter submits the text", JSON.stringify(flow.submitted), JSON.stringify(["hunter2"]));
            check.equal("and empties the field", root.card.field.text, "");
        });

        check.attempt("a failed attempt", () => {
            // As the agent goes on after one: failed, PAM's word, asked again.
            flow.failed = true;
            flow.supplementaryMessage = "Authentication failure";
            flow.supplementaryIsError = true;
            flow.isResponseRequired = true;
            flow.inputPrompt = "Password: ";
            check.equal("said", root.card.notice.text, "Authentication failure");
            check.sameColor("in the danger colour", root.card.notice.color, Appearance.c.danger, 1);
            check.equal("asked again, the field empty", root.card.field.text, "");
            check.equal("the field still has the keyboard", root.card.field.input.activeFocus, true);
            flow.supplementaryMessage = "";
            flow.supplementaryIsError = false;
            check.report("failed with nothing said: still said", root.card.notice.text !== "",
                "no notice");
            check.sameColor("failed with nothing said: in the danger colour", root.card.notice.color,
                Appearance.c.danger, 1);
            flow.supplementaryMessage = "Your password expires in 3 days";
            check.equal("an info message", root.card.notice.text, "Your password expires in 3 days");
            check.sameColor("not in the danger colour", root.card.notice.color, Appearance.c.textMuted, 1);
            root.type("again");
            const button = root.card.authenticate;
            keys.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
            check.equal("Authenticate submits", JSON.stringify(flow.submitted), JSON.stringify(["hunter2", "again"]));
            check.equal("Authenticate empties the field", root.card.field.text, "");
            check.equal("the keyboard back in the field", root.card.field.input.activeFocus, true);
        });

        check.attempt("the popup under it", () => {
            Overlay.dismissOnEscape();
            check.equal("Escape's bind leaves it open", Overlay.active, Overlay.taskManager);
            Overlay.dismissOnOutsideClick();
            check.equal("an outside click leaves it open", Overlay.active, Overlay.taskManager);
        });

        check.attempt("cancelling", () => {
            check.equal("Escape reaches the card", keys.keyClick(Qt.Key_Escape, Qt.NoModifier, -1), true);
            check.equal("Escape cancels", flow.cancelled, 1);
            const button = root.card.cancelButton;
            keys.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton, Qt.NoModifier, -1);
            check.equal("Cancel cancels", flow.cancelled, 2);
        });

        root.layers(names => {
            check.report("on the overlay layer, in Hyprland", names.includes("shell-auth"), names.join(", "));
            root.going();
        });
    }

    function going(): void {
        root.flow = null;
        check.equal("going: mapped through its fade", auth.visible, true);
        check.equal("going: still authorizing", Overlay.authorizing, true);
        check.attempt("going", () => {
            check.equal("going: no input", auth.mask?.item ?? null, null);
            check.equal("going: says what it said", root.card.message.text,
                "Authentication is needed to run `/usr/bin/true' as the super user");
        });
        // Read a moment after: the window hears the same change.
        root.after("let go after its fade", Appearance.t.popupFade + Appearance.t.grace + 300,
            () => Overlay.authorizingChanged, () => !Overlay.authorizing, () => Qt.callLater(root.gone));
    }

    function gone(): void {
        check.equal("gone: unmapped", auth.visible, false);
        Overlay.dismissOnEscape();
        check.equal("gone: Escape's bind closes the popup again", Overlay.active, Overlay.none);
        ipc.run("taskManager");
        Overlay.dismissOnOutsideClick();
        check.equal("gone: an outside click closes it again", Overlay.active, Overlay.none);

        root.layers(names => {
            check.report("gone from Hyprland", !names.includes("shell-auth"), names.join(", "));
            root.project();
        });
    }

    function project(): void {
        sh.run("printf 'agent %s\\n' \"$(cat \"$1\" \"$2\" | grep -c hyprpolkitagent)\"; "
            + "printf 'polkit %s\\n' \"$(grep -cx polkit \"$1\")\"; "
            + "printf 'rule %s\\n' \"$(awk '/^layerrule\\[shell-auth\\] \\{$/ { on = 1; next } "
            + "on && /^\\}/ { on = 0 } on' \"$3\" | sed 's/^ *//' | sort | paste -sd '|')\"",
            [root.path("packages.txt"), root.path("hypr/conf.d/20-autostart.conf"), root.path("hyprland.conf")],
            out => {
                const lines = out.trim().split("\n");
                check.equal("hyprpolkitagent neither listed nor started", lines[0], "agent 0");
                check.equal("polkit stays", lines[1], "polkit 1");
                check.equal("the layer rule: above the popups, no fade of Hyprland's", lines[2],
                    "rule match:namespace = shell-auth|no_anim = on|order = -1");
                check.done();
            });
    }
}
