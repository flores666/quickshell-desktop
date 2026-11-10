#pragma once

#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/output/Monitor.hpp>

// Native rect/texture passes leave explicit clip boxes in output coordinates
// when a transformer renders into a cropped framebuffer. Keep the title bar's
// clip in the same coordinate system as its drawing, including Genie/wobble.
template <typename Data>
class CClippedPass : public IPassElement {
  public:
    explicit CClippedPass(const Data& data) : m_data(data) {}
    std::vector<UP<IPassElement>> draw(Render::CRenderContext& ctx) override {
        auto data = m_data;
        if (!data.clipBox.empty() && ctx.m_data.renderingTransformedSource)
            ctx.m_data.renderModif.applyToBox(data.clipBox);
        g_pHyprRenderer->draw(ctx, data, ctx.m_data.damage);
        return {};
    }
    bool needsLiveBlur(Render::CRenderContext&) override { return false; }
    bool needsPrecomputeBlur(Render::CRenderContext&) override { return false; }
    bool disableSimplification(Render::CRenderContext&) override { return true; }
    std::optional<CBox> boundingBox(Render::CRenderContext& ctx) override { return m_data.box.copy().scale(1 / ctx.m_data.pMonitor->m_scale); }
    ePassElementType type() override { return EK_CUSTOM; }
    const char* passName() override { return "CClippedPass"; }

  private:
    Data m_data;
};

template <typename Data>
UP<IPassElement> clippedPass(const Data& data) { return makeUnique<CClippedPass<Data>>(data); }
