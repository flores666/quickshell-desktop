pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell

/*!
    Tracks whether the user is currently driving the shell with the keyboard.

    Focus rings are only meaningful during keyboard navigation — showing them on
    every mouse click is noise.  This mirrors the CSS :focus-visible heuristic:
    any pointer press turns the mode off, any key press turns it on.
*/
Singleton {
    id: root

    property bool keyboard: false

    function pointerUsed(): void { root.keyboard = false; }
    function keyboardUsed(): void { root.keyboard = true; }
}
