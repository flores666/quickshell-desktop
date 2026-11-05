#pragma once

#include "Style.hpp"
#include <hyprland/src/helpers/AnimatedVariable.hpp>
#include <hyprland/src/render/Framebuffer.hpp>

namespace Render { class CRenderContext; }

// A bounded presentation of one live window. Layout, focus, mode and input
// remain Hyprland's; the only retained content is this transition's snapshot.
class CGenie {
  public:
    static UP<CGenie> capture(PHLWINDOW window, const CBox& target, float from);
    ~CGenie();
    void toward(bool minimized);
    void paint(Render::CRenderContext& ctx) const;
    bool finished() const;
    bool valid() const;
    bool sameDestination(PHLWINDOW window) const;
    PHLMONITOR monitor() const;
    void damage() const;
    static void clearPass();

  private:
    CGenie(PHLWINDOW window, const CBox& target, SP<Render::IFramebuffer> snapshot, float from);

    PHLWINDOWREF m_window;
    PHLMONITORREF m_monitor;
    PHLWORKSPACEREF m_workspace;
    CBox m_source, m_frame, m_target, m_windowBox;
    SP<Render::IFramebuffer> m_snapshot;
    SP<Style::Config> m_config;
    PHLANIMVAR<float> m_progress;
};
