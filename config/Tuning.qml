pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/services"

/*!
    The sizes the user is allowed to change, with the value each was tuned to
    and the range it stays coherent over.

    One table rather than a constant in Metrics, a clamp in Radii and a slider
    bound in the settings panel: the guard that protects the shell from a
    hand-edited settings.json and the limits the panel offers are then the same
    numbers by construction, and a knob cannot drift from its own guard rail.

    It is a singleton because Metrics and Radii are both instantiated by
    Appearance and cannot see each other, and because the settings panel needs
    the same limits without reaching into either.

    The ranges are narrow on purpose.  A handful of details inside the bar and
    the dock — the workspace pills, the tray glyph, the running indicator — are
    pixel literals tuned around these defaults, so the shell stays coherent
    across this span without every one of them having to scale too.
*/
Singleton {
    id: root

    readonly property var spec: ({
        barHeight:  { min: 26, max: 40,  def: 30  },
        barGap:     { min: 0,  max: 16,  def: 6   },
        barSideGap: { min: 0,  max: 32,  def: 10  },
        dockIcon:   { min: 28, max: 48,  def: 34  },
        screenGap:  { min: 0,  max: 24,  def: 8   },
        border:     { min: 0,  max: 2,   def: 1   },
        roundness:  { min: 0,  max: 150, def: 100 },
        fontScale:  { min: 85, max: 125, def: 100 }
    })

    /*! A user override, clamped — or the tuned value, when unset (negative). */
    function pick(key: string): int {
        const limits = root.spec[key];
        const override = Settings[key];
        if (override === undefined || override < 0)
            return limits.def;
        return Math.max(limits.min, Math.min(limits.max, override));
    }
}
