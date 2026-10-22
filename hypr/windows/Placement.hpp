#pragma once

#include <hyprland/src/desktop/DesktopTypes.hpp>

/*
    Where an application's window opens, and what it opens as.

    Windows float by default — a window rule in the config, `float-by-default`,
    which Hyprland reads at the window's first commit so that the application
    is asked for its own size rather than a tile's. On top of it this keeps,
    per application and across sessions, whether its windows were last left
    floating or tiled and at what size, and opens the next one so: tiled, or
    floating at that size, centred in the work area. An application seen for
    the first time opens at the size it picks, cut down to a sensible share of
    the screen; one that picks none opens at that share.

    Only for an application's own windows that the default rule floats and no
    rule of the user's places: dialogs, fixed-size windows, ones asking for
    fullscreen, and anything a `float`, `tile`, `size`, `move`, `center`,
    `fullscreen` or `maximize` rule speaks for are Hyprland's as before.
*/
namespace Placement {
    // The config's rule; the name is how it is told from the user's rules.
    inline constexpr const char* DEFAULT_RULE = "float-by-default";

    /*! Read what was remembered in earlier sessions. */
    void load();
    /*! A window is about to be placed (`openEarly`): tiled, or its size and place. */
    void place(PHLWINDOW window);
    /*! The user floated or tiled a window: placed as it would open, and remembered. */
    void floatingChanged(PHLWINDOW window);
    /*! Remember a window's state (it closed, or Hyprland exits). */
    void remember(PHLWINDOW window);
    /*! Every open window's, as Hyprland exits. */
    void rememberAll();
}
