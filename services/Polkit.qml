pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

/*!
    The session's polkit agent: what asks for the password when something
    needs administrator rights — pkexec, as the task manager applies
    earlyoom's options, or an application mounting a disk.

    The shell is the agent so that it can draw the prompt itself, above its
    own popups (modules/polkit/AuthWindow): an agent of its own window, as
    hyprpolkitagent was, is an ordinary window, and no ordinary window comes
    above the overlay layer the popups are on.

    Polkit takes one agent per session, so where another has registered
    first this one does not register (`available` stays false), is never
    asked, and nothing of it shows: that agent asks instead. The shell runs
    as a user unit, outside the login session; polkit takes the user's
    display session for it.
*/
Singleton {
    id: root

    /*! Whether the shell is the session's agent. */
    readonly property bool available: agent.isRegistered
    /*! The request being asked about (an AuthFlow), or null. A wrong
        password does not end it: it asks again. It goes once it succeeds or
        is cancelled. */
    readonly property AuthFlow flow: agent.flow

    PolkitAgent {
        id: agent
    }
}
