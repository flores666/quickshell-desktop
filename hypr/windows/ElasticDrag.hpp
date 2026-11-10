#pragma once

#include "Style.hpp"
#include <hyprland/src/render/WindowRenderPresentation.hpp>

namespace Render { class CRenderContext; }

namespace ElasticDrag {
    void init(HANDLE handle);
    void exit();
    bool suppressed(PHLWINDOW window);
    bool capturingOverview();
    void paint(Render::CRenderContext& ctx, PHLMONITOR monitor);
}
