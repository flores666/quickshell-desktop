import QtQuick
import Quickshell
import "root:/services"

/*!
    The hand-off Overlay records between two popups (Overlay.flight): when
    there is one, and that only the popups it names can move it on.
*/
Item {
    Check {
        id: check
    }

    Component.onCompleted: {
        const one = Quickshell.screens[0];
        const two = Quickshell.screens.length > 1 ? Quickshell.screens[1] : null;

        Overlay.open(Overlay.quickSettings, one);
        check.equal("nothing open before: no hand-off", Overlay.flight, null);

        Overlay.open(Overlay.dateMenu, one);
        check.equal("hand-off from the open popup", Overlay.flight?.from, Overlay.quickSettings);
        check.equal("hand-off to the new one", Overlay.flight?.to, Overlay.dateMenu);
        check.equal("no place yet", Overlay.flight?.rect, null);
        check.equal("no picture yet", Overlay.flight?.contents, null);
        check.equal("not taken off yet", Overlay.flight?.away, false);

        Overlay.depart(Overlay.dateMenu, Qt.rect(1, 2, 3, 4), "picture");
        check.equal("only the popup it is from departs", Overlay.flight?.rect, null);
        Overlay.depart(Overlay.quickSettings, Qt.rect(1, 2, 3, 4), "picture");
        check.equal("departure's place", Overlay.flight?.rect?.toString(), Qt.rect(1, 2, 3, 4).toString());
        check.equal("departure's picture", Overlay.flight?.contents, "picture");

        Overlay.arrive(Overlay.quickSettings);
        check.equal("only the popup it is to arrives", Overlay.flight?.away, false);
        Overlay.arrive(Overlay.dateMenu);
        check.equal("arrival", Overlay.flight?.away, true);

        Overlay.abandon(Overlay.launcher);
        check.equal("a popup it does not name cannot drop it", Overlay.flight?.to, Overlay.dateMenu);
        Overlay.abandon(Overlay.dateMenu);
        check.equal("dropped by the popup it is to", Overlay.flight, null);

        Overlay.open(Overlay.vpnMenu, one);
        Overlay.abandon(Overlay.dateMenu);
        check.equal("dropped by the popup it is from", Overlay.flight, null);

        Overlay.open(Overlay.dateMenu, one);
        Overlay.open(Overlay.dateMenu, one);
        check.equal("the same popup again: none", Overlay.flight, null);
        Overlay.openWith(Overlay.dateMenu, one, {});
        check.equal("the same popup with a new subject: none", Overlay.flight, null);

        Overlay.openWith(Overlay.trayMenu, one, {});
        check.equal("openWith hands off too", Overlay.flight?.from, Overlay.dateMenu);
        check.equal("the subject is still handed over", Overlay.payload !== null, true);

        Overlay.close();
        check.equal("closing clears it", Overlay.flight, null);

        Overlay.toggle(Overlay.quickSettings, one);
        check.equal("toggled open from nothing: none", Overlay.flight, null);
        Overlay.toggle(Overlay.quickSettings, one);
        check.equal("toggled shut: none", Overlay.flight, null);

        if (two !== null) {
            Overlay.open(Overlay.quickSettings, one);
            Overlay.open(Overlay.dateMenu, two);
            check.equal("another screen: none", Overlay.flight, null);
            Overlay.close();
        }

        check.done();
    }
}
