#pragma once

#define WLR_USE_UNSTABLE

#include <hyprland/src/plugins/PluginAPI.hpp>

/*
    Windows stacked in the order they were last clicked, tiled ones among the
    floating.

    Hyprland raises whatever window is clicked, tiled or floating, and keeps
    its windows in that order, but draws every tiled window below every
    floating one and offers the pointer to the floating first: a tiled window
    clicked under a floating one took focus and stayed covered. Here a tiled
    window clicked after a floating one is drawn over it, and takes the
    pointer wherever it is drawn over it; clicking the floating one, or
    focusing it from the dock or Alt+Tab, brings it back over. A hover still
    focuses without raising anything.

    Two of Hyprland's functions are hooked for it: the one that draws a
    workspace's windows, which keeps Hyprland's own order whenever no tiled
    window is above a floating one, and the hit test. A workspace with a
    fullscreen or maximized window is drawn and hit as Hyprland does.
*/
namespace Stacking {
    void init(HANDLE handle);
}
