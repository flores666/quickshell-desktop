#pragma once

#include <hyprland/src/plugins/PluginAPI.hpp>
namespace Render { class CRenderContext; }

// Present map/unmap and the existing minimize/restore action through the same
// dock Genie. Native window lifetime, layout, focus and actions stay intact.
namespace WindowMotion {
    void init(HANDLE handle);
    void exit();
    bool suppressed(PHLWINDOW window);
    bool available();
    void takeForDrag(PHLWINDOW window);
    void paintCarried(Render::CRenderContext& ctx, PHLWINDOW window, PHLMONITOR monitor);
}
