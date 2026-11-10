#include "ElasticState.hpp"

#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>
#include <hyprland/src/desktop/view/window/WindowEffectsController.hpp>
#include <hyprland/src/render/transformer/TransformerList.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/config/shared/complex/ComplexDataTypes.hpp>
#include <hyprland/src/output/Monitor.hpp>

namespace {
    double ms(Time::steady_tp from, Time::steady_tp to) {
        return std::chrono::duration<double, std::milli>(to - from).count();
    }

    class CElasticTransform : public Render::IWindowTransformer {
      public:
        explicit CElasticTransform(SP<ElasticDrag::Session> state) : m_state(state) {}
        bool active() const override { return m_state->alive; }
        int priority() const override { return 100; }
        void preWindowRender(Render::CRenderContext& ctx, CSurfacePassElement::SRenderData*) override {
            if (const auto M = ctx.m_data.pMonitor.lock()) m_origin = M->m_position;
            m_time = ctx.effectTime();
        }

        ElasticMath::Point map(Vector2D p, Vector2D origin, Time::steady_tp now) const {
            const auto W = m_state->window.lock();
            if (!W) return {p.x, p.y};
            const auto SIZE = W->size(Desktop::View::IGeometric::GEOMETRIC_CURRENT);
            const auto BOX = m_state->box(now);
            const auto LOCAL = p + origin - W->position(Desktop::View::IGeometric::GEOMETRIC_CURRENT);
            // Map from the current client geometry, including padding, into
            // the carried frame. No layout geometry is changed for the lift.
            const auto OUT = m_state->pose(now).map({LOCAL.x * BOX.w / SIZE.x, LOCAL.y * BOX.h / SIZE.y});
            return {OUT.x - origin.x, OUT.y - origin.y};
        }

        CBox extents(const CBox& source, Vector2D origin, Time::steady_tp now) const {
            double x1 = INFINITY, y1 = INFINITY, x2 = -INFINITY, y2 = -INFINITY;
            for (const auto& p : {source.pos(), source.pos() + Vector2D{source.w, 0.0}, source.pos() + source.size(), source.pos() + Vector2D{0.0, source.h}}) {
                const auto P = map(p, origin, now);
                x1 = std::min(x1, P.x); y1 = std::min(y1, P.y);
                x2 = std::max(x2, P.x); y2 = std::max(y2, P.y);
            }
            return CBox{x1, y1, x2 - x1, y2 - y1}.expand(ElasticDrag::Style::value("shadow_range") + ElasticDrag::Style::value("shadow_drop"));
        }
        CBox transformedExtents(const CBox& source) const override { return extents(source, m_origin, m_time); }
        CBox transformBoxForDamage(const CBox& source) const override { return extents(source, {}, Time::steadyNow()); }

        void amendTransformedRenderData(Render::CRenderContext&, const CBox&, SMotionBlurData* blur,
            const Render::SWindowRenderPresentation&) override { *blur = {}; }

        Render::SWindowTransformBuffer transform(Render::CRenderContext& ctx, const Render::SWindowTransformBuffer& in,
            const Render::SWindowTransformContext& context) override {
            const auto GL = g_pHyprRenderer->glBackend();
            const auto M = context.monitor.lock();
            if (!GL || !M || !in.framebuffer || context.renderingSnapshot || context.standalone) return in;
            const double SCALE = M->m_scale;
            const auto CANVAS = Render::pixelBoxForLogical(context.outputBox.copy().expand(1 / SCALE), SCALE);
            const auto OUT = g_pHyprRenderer->getWorkBuffer(ctx, CANVAS.size());
            if (!OUT) return {.framebuffer = in.framebuffer, .box = in.box, .success = false};
            std::vector<SMeshRenderVertex> vertices;
            vertices.reserve(6);
            for (const auto& uv : {Vector2D{0, 0}, Vector2D{0, 1}, Vector2D{1, 0}, Vector2D{1, 0}, Vector2D{0, 1}, Vector2D{1, 1}}) {
                const auto P = map((in.box.pos() + uv * in.box.size()) / SCALE, M->m_position, m_time);
                vertices.push_back({sc<float>((P.x * SCALE - CANVAS.x) / CANVAS.w), sc<float>((P.y * SCALE - CANVAS.y) / CANVAS.h),
                    sc<float>(uv.x), sc<float>(uv.y)});
            }
            auto state = ctx.saveDrawState();
            auto framebuffer = g_pHyprRenderer->bindTempFB(ctx, OUT);
            ctx.m_data.fbSize = CANVAS.size();
            ctx.m_data.damage = CRegion{0, 0, CANVAS.w, CANVAS.h};
            ctx.m_data.renderModif = {};
            ctx.m_data.clipBox = {};
            g_pHyprRenderer->setProjectionType(ctx, Render::RPT_EXPORT);
            g_pHyprRenderer->draw(ctx, CClearPassElement::SClearData{CHyprColor{0, 0, 0, 0}});
            // A second soft shadow adds lift while the ordinary shadow stays
            // in the live window image and returns unchanged on hand-back.
            const auto BOX = m_state->box(m_time);
            const auto POSE = m_state->pose(m_time);
            const auto TOP = POSE.map({0, 0});
            const double LIFT = std::max(0.0, m_state->lift(m_time));
            const double RANGE = ElasticDrag::Style::value("shadow_range") * SCALE;
            CBox shadow{(TOP.x - M->m_position.x) * SCALE - CANVAS.x,
                (TOP.y - M->m_position.y + ElasticDrag::Style::value("shadow_drop") * LIFT) * SCALE - CANVAS.y,
                BOX.w * POSE.scaleX * SCALE, BOX.h * POSE.scaleY * SCALE};
            const auto W = m_state->window.lock();
            GL->renderRoundedShadow(ctx, shadow.expand(RANGE), W ? W->presentation().rounding() * SCALE : 0, W ? W->presentation().roundingPower() : 2,
                RANGE, Config::CGradientValueData{ElasticDrag::Style::shadow()}, LIFT, {});
            GL->renderTextureMesh(ctx, in.framebuffer->getTexture(), {0, 0, CANVAS.w, CANVAS.h}, vertices,
                {.damage = &ctx.m_data.damage, .allowDim = false});
            return {.framebuffer = OUT, .box = CANVAS};
        }

      private:
        SP<ElasticDrag::Session> m_state;
        Vector2D m_origin;
        Time::steady_tp m_time;
    };
}

CBox ElasticDrag::Session::box(Time::steady_tp now) const {
    if (held) return {cursor - grab * displayed.size(), displayed.size()};
    const double P = ElasticMath::landing(ms(dropped, now) / std::max(1.0, Style::value("landing")));
    return {displayed.pos() + (released.pos() - displayed.pos()) * P, displayed.size() + (released.size() - displayed.size()) * P};
}

double ElasticDrag::Session::lift(Time::steady_tp now) const {
    if (held) return ElasticMath::smooth(ms(started, now) / std::max(1.0, Style::value("lift")));
    return dropLift * (1 - ElasticMath::landing(ms(dropped, now) / std::max(1.0, Style::value("landing"))));
}

ElasticMath::Pose ElasticDrag::Session::pose(Time::steady_tp now) const {
    const auto BOX = box(now);
    const auto V = (held ? velocity : dropVelocity) * ElasticMath::decay(ms(held ? lastMotion : dropped, now), Style::value("settle"));
    const double LIFT = lift(now);
    const double SCALE = 1 + (Style::value("scale") - 1) * LIFT;
    const double DEFORM = Style::value("deformation") * std::min(1.0, V.size());
    const auto PIN = BOX.pos() + grab * BOX.size();
    return {{grab.x * BOX.w, grab.y * BOX.h}, {PIN.x, PIN.y},
        SCALE * (1 + DEFORM * std::abs(V.x)), SCALE * (1 + DEFORM * std::abs(V.y)),
        V.x * Style::value("rotation") * std::numbers::pi / 180};
}

void ElasticDrag::Session::motion(Vector2D point) {
    const auto NOW = Time::steadyNow();
    const double DT = std::max(1.0, ms(lastMotion, NOW));
    const auto V = (point - lastCursor) * (1000 / DT / std::max(1.0, Style::value("velocity")));
    // Bounded velocity, with an input-rate-independent short smoothing ramp.
    const double MIX = 1 - std::exp(-DT / std::max(1.0, Style::value("settle") / 9));
    velocity = velocity * ElasticMath::decay(DT, Style::value("settle")) * (1 - MIX) + V.clamp({-1, -1}, {1, 1}) * MIX;
    if (velocity.size() > 1) velocity = velocity / velocity.size();
    cursor = lastCursor = point;
    lastMotion = NOW;
}

void ElasticDrag::attach(const SP<Session>& state) {
    if (const auto W = state->window.lock()) {
        W->effects().reset();
        W->effects().transformers()->emplace<CElasticTransform>(state);
    }
}
