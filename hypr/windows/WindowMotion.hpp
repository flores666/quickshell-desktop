#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>

// The existing move-to-workspace action is shared by the title-bar minimize
// button and the dock's restore. Hook that boundary, never duplicate actions.
namespace WindowMotion {
    void init(HANDLE handle);
    void exit();
    bool suppressed(PHLWINDOW window);
}
