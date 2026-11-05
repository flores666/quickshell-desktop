#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>

// Present map/unmap and the existing minimize/restore action through the same
// dock Genie. Native window lifetime, layout, focus and actions stay intact.
namespace WindowMotion {
    void init(HANDLE handle);
    void exit();
    bool suppressed(PHLWINDOW window);
}
