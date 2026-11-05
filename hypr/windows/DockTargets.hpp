#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>

// Resting artwork published atomically by the dock. Addresses identify live
// windows; application identities also identify icons before their first map.
namespace DockTargets {
    void init(HANDLE handle);
    std::optional<CBox> find(PHLWINDOW window);
    void forget(PHLWINDOW window);
    void forget(PHLMONITOR monitor);
    void clear();
}
