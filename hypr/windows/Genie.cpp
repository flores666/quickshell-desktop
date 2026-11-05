#include "Genie.hpp"

#include <hyprland/src/animation/AnimationManager.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/OpenGL.hpp>

#include <algorithm>
#include <cmath>

namespace {
    double smooth(double from, double to, double value) {
        const double T = std::clamp((value - from) / (to - from), 0.0, 1.0);
        return T * T * (3 - 2 * T);
    }

    // First the lower edge draws a neck toward the icon, then the upper
    // edge follows it down. A strip mesh keeps the image continuous; UVs
    // always refer to the original snapshot, never to a resized client.
    std::vector<SMeshRenderVertex> mesh(const CBox& source, const CBox& frame, const CBox& target, const Vector2D& output, double progress) {
        constexpr int STRIPS = 64;
        const double NECK = smooth(0, 0.4, progress);
        const double FALL = smooth(0.35, 1, progress);
        const double END = target.y + target.h / 2;
        const double TOP = std::lerp(frame.y, END, FALL);
        const double BOTTOM = std::lerp(frame.y + frame.h, END, NECK);
        const auto VERTEX = [&](double u, double v) -> SMeshRenderVertex {
            const double X = source.x + source.w * u, Y = source.y + source.h * v;
            const double V = (Y - frame.y) / frame.h;
            const double PULL = FALL + (1 - FALL) * NECK * smooth(0, 1, V);
            const double LEFT = std::lerp(frame.x, target.x, PULL);
            const double RIGHT = std::lerp(frame.x + frame.w, target.x + target.w, PULL);
            // Deform around the actual frame, extending the same mapping to
            // its shadow. Transparent shadow padding must not stop the window
            // itself reaching the icon or postpone formation of the neck.
            return {sc<float>(std::lerp(LEFT, RIGHT, (X - frame.x) / frame.w) / output.x), sc<float>(std::lerp(TOP, BOTTOM, V) / output.y),
                sc<float>(X / output.x), sc<float>(Y / output.y)};
        };
        std::vector<SMeshRenderVertex> out;
        out.reserve(STRIPS * 6);
        for (int i = 0; i < STRIPS; ++i) {
            const double A = sc<double>(i) / STRIPS, B = sc<double>(i + 1) / STRIPS;
            for (const auto& point : {VERTEX(0, A), VERTEX(0, B), VERTEX(1, A), VERTEX(1, A), VERTEX(0, B), VERTEX(1, B)})
                out.push_back(point);
        }
        return out;
    }

    class CGeniePass : public IPassElement {
      public:
        CGeniePass(SP<Render::IFramebuffer> snapshot, const CBox& source, const CBox& frame, const CBox& target, const Vector2D& output, float progress, bool privateContent) :
            m_snapshot(snapshot), m_output(output), m_vertices(mesh(source, frame, target, output, progress)), m_private(privateContent) {}

        std::vector<UP<IPassElement>> draw(Render::CRenderContext& ctx) override {
            // The renderer owns this backend uniquely. Its weak reference
            // can be used during this draw, but cannot become a shared owner.
            const auto GL = g_pHyprRenderer->glBackend();
            if (GL && ctx.shouldRenderContent(m_private)) {
                const auto MONITOR = ctx.m_data.pMonitor.lock();
                if (MONITOR)
                    GL->renderTextureMesh(ctx, m_snapshot->getTexture(), {0, 0, MONITOR->m_transformedSize.x, MONITOR->m_transformedSize.y},
                        m_vertices, {.damage = &ctx.m_data.damage, .allowDim = false});
            }
            return {};
        }
        bool needsLiveBlur(Render::CRenderContext&) override { return false; }
        bool needsPrecomputeBlur(Render::CRenderContext&) override { return false; }
        const char* passName() override { return "CGeniePass"; }
        ePassElementType type() override { return EK_CUSTOM; }
        std::optional<CBox> boundingBox(Render::CRenderContext&) override { return CBox{0, 0, m_output.x, m_output.y}; }

      private:
        SP<Render::IFramebuffer> m_snapshot;
        Vector2D m_output;
        std::vector<SMeshRenderVertex> m_vertices;
        bool m_private;
    };
}

UP<CGenie> CGenie::capture(PHLWINDOW window, const CBox& target, float from) {
    const auto MONITOR = window->m_monitor.lock();
    if (!MONITOR || !Style::motionEnabled() || !g_pHyprRenderer->glBackend())
        return nullptr;
    const auto BOX = target.intersection({0, 0, MONITOR->m_size.x, MONITOR->m_size.y});
    if (BOX.empty())
        return nullptr;
    const auto SNAPSHOT = g_pHyprRenderer->makeSnapshotFB(window);
    if (!SNAPSHOT || !SNAPSHOT->isAllocated())
        return nullptr;
    auto effect = UP<CGenie>(new CGenie(window, BOX, SNAPSHOT, from));
    // A minimize can race the first frame of an opening window. There is
    // nothing to deform until both its image and its frame have an extent.
    if (effect->m_source.empty() || effect->m_frame.empty())
        return nullptr;
    return effect;
}

CGenie::CGenie(PHLWINDOW window, const CBox& target, SP<Render::IFramebuffer> snapshot, float from) :
    m_window(window), m_monitor(window->m_monitor), m_workspace(window->m_workspace), m_target(target),
    m_windowBox(window->geometricBox(Desktop::View::IGeometric::GEOMETRIC_CURRENT)), m_snapshot(snapshot) {
    const auto MONITOR = monitor();
    m_source = window->getFullWindowBoundingBox().translate(-MONITOR->m_position).intersection({0, 0, MONITOR->m_size.x, MONITOR->m_size.y});
    m_frame = window->getWindowBoxUnified(Desktop::View::RESERVED_EXTENTS).translate(-MONITOR->m_position);
    Animation::mgr()->createAnimation(from, m_progress, Style::minimize(), AVARDAMAGE_NONE);
    const PHLMONITORREF WEAK = MONITOR;
    m_progress->setUpdateCallback([WEAK](auto) {
        if (const auto M = WEAK.lock()) g_pHyprRenderer->damageMonitor(M);
    });
}

CGenie::~CGenie() {
    m_progress->resetAllCallbacks();
    damage();
}

void CGenie::toward(bool minimized) {
    m_config = makeShared<Style::Config>(*Style::minimize());
    m_config->pValues = m_config;
    const float GOAL = minimized ? 1.F : 0.F;
    m_config->internalSpeed *= std::abs(GOAL - m_progress->value());
    m_config->internalSpeed = std::max(0.1F, m_config->internalSpeed);
    m_progress->setConfig(m_config);
    *m_progress = GOAL;
    damage();
}

void CGenie::paint(Render::CRenderContext& ctx) const {
    const auto W = m_window.lock();
    const auto MONITOR = monitor();
    if (W && MONITOR)
        Render::IHyprRenderer::addPassElement(ctx, makeUnique<CGeniePass>(m_snapshot, m_source, m_frame, m_target, MONITOR->m_size, m_progress->value(),
            W->m_ruleApplicator->noScreenShare().valueOrDefault()));
}

bool CGenie::finished() const { return !m_progress->isBeingAnimated(); }
bool CGenie::valid() const {
    const auto W = m_window.lock();
    const auto WORKSPACE = m_workspace.lock();
    return validMapped(W) && monitor() && WORKSPACE && WORKSPACE->visible();
}
bool CGenie::sameDestination(PHLWINDOW window) const {
    return window->m_monitor == m_monitor && window->m_workspace == m_workspace &&
        window->geometricBox(Desktop::View::IGeometric::GEOMETRIC_GOAL) == m_windowBox;
}
PHLMONITOR CGenie::monitor() const { return m_monitor.lock(); }
void CGenie::damage() const { if (const auto M = monitor()) g_pHyprRenderer->damageMonitor(M); }

void CGenie::clearPass() {
    auto& ctx = g_pHyprRenderer->context();
    ctx.m_pass.removeAllOfType("CGeniePass");
    if (ctx.m_currentPass && ctx.m_currentPass != &ctx.m_pass)
        ctx.m_currentPass->removeAllOfType("CGeniePass");
}
