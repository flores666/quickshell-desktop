#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>

// Resting artwork and pin membership published atomically by the dock.
// Addresses identify live windows; app identities also cover their first map.
namespace DockTargets {
    void init(HANDLE handle);
    // Close targets only persistent pins; minimize/restore also use running icons.
    std::optional<CBox> find(PHLWINDOW window, bool pinnedOnly = false);
    void forget(PHLWINDOW window);
    void forget(PHLMONITOR monitor);
    void clear();
}
