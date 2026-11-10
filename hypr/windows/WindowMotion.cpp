#include "WindowMotion.hpp"
#include "DockTargets.hpp"
#include "Genie.hpp"
#include "ElasticDrag.hpp"

#include <hyprland/src/animation/AnimationManager.hpp>
#include <hyprland/src/config/shared/animation/AnimationTree.hpp>
#include <hyprland/src/config/shared/actions/ConfigActions.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/plugins/HookSystem.hpp>
#include <hyprland/src/render/Renderer.hpp>

#include <iostream>
#include <unordered_map>

namespace {
    using Move = Config::Actions::ActionResult (*)(PHLWORKSPACE, bool, std::optional<PHLWINDOW>);
    using Draw = void (*)(void*, Render::CRenderContext&, PHLWINDOW, PHLMONITOR, const Render::SWindowRenderPresentation&,
        const Time::steady_tp&, bool, Render::eRenderPassMode, bool, bool);
    CFunctionHook* g_move = nullptr;
    CFunctionHook* g_draw = nullptr;
    HANDLE g_handle;
    std::vector<CHyprSignalListener> g_listeners;
    std::unordered_map<Desktop::View::CWindow*, UP<CGenie>> g_effects;
    std::vector<UP<CGenie>> g_closing;
    struct SOpening {
        PHLWINDOWREF window;
        PHLMONITORREF monitor;
        PHLWORKSPACEREF workspace;
        CBox target;
    };
    std::unordered_map<Desktop::View::CWindow*, SOpening> g_opening;

    bool minimized(PHLWORKSPACE workspace) {
        return workspace && workspace->addressableName() == "special:minimized";
    }

    Config::Actions::ActionResult move(PHLWORKSPACE workspace, bool silent, std::optional<PHLWINDOW> selected) {
        const auto W = selected.value_or(Desktop::focusState()->window());
        const bool MIN = validMapped(W) && minimized(workspace) && !minimized(W->m_workspace);
        const bool RESTORE = validMapped(W) && !minimized(workspace) && minimized(W->m_workspace);
        if (MIN || RESTORE) g_opening.erase(W.get());
        const bool MOTION = (MIN || RESTORE) && Style::motionEnabled();
        UP<CGenie> captured;
        if (MOTION && MIN && !g_effects.contains(W.get()))
            if (const auto TARGET = DockTargets::find(W)) captured = CGenie::capture(W, *TARGET, 0.F);

        // Focus, mode, workspace and the client's real box are changed by the
        // original action exactly once. Failure never leaves a hidden client.
        auto result = ((Move)g_move->m_original)(workspace, silent, selected);
        if (!result || !MOTION || !validMapped(W) || W->m_workspace != workspace) return result;

        auto existing = g_effects.find(W.get());
        if (existing != g_effects.end() && (!RESTORE || existing->second->sameDestination(W))) {
            existing->second->toward(MIN);
        } else {
            if (existing != g_effects.end()) g_effects.erase(existing);
            if (RESTORE && DockTargets::find(W)) {
                // The action has completed the layout, including fullscreen
                // restoration. Capture its final box rather than its travel
                // from a hidden workspace; the client is never dock-sized.
                W->finishAnimation();
                W->presentation().alpha(Desktop::View::WINDOW_ALPHA_MOVE_TO_WORKSPACE)->setValueAndWarp(1.F);
                W->presentation().alpha(Desktop::View::WINDOW_ALPHA_MOVE_FROM_WORKSPACE)->setValueAndWarp(1.F);
                W->presentation().resetMonitorMovedFrom();
                if (const auto TARGET = DockTargets::find(W)) captured = CGenie::capture(W, *TARGET, 1.F);
            }
            if (captured) {
                captured->toward(MIN);
                g_effects.emplace(W.get(), std::move(captured));
            }
        }
        if (g_effects.contains(W.get())) {
            W->presentation().alpha(Desktop::View::WINDOW_ALPHA_MOVE_TO_WORKSPACE)->setValueAndWarp(1.F);
            W->presentation().alpha(Desktop::View::WINDOW_ALPHA_MOVE_FROM_WORKSPACE)->setValueAndWarp(1.F);
            W->presentation().resetMonitorMovedFrom();
        }
        return result;
    }

    void finishShadow(PHLWINDOW window) {
        const auto CONFIG = Config::animationTree()->getAnimationPropertyConfig("fadeShadow");
        // Like geometry and startup dimming, the shadow must be at its final
        // appearance in the retained image. Its native map fade starts at zero.
        // Warping disconnects variables, so iterate a copy of the active list.
        const auto ACTIVE = Animation::mgr()->m_vActiveAnimatedVariables;
        for (const auto& weak : ACTIVE) {
            const auto VAR = weak.get();
            if (!VAR || VAR->m_Type != AVARTYPE_FLOAT || VAR->getConfig().lock() != CONFIG) continue;
            if (sc<CAnimatedVariable<float>*>(VAR)->m_Context.pWindow == window) VAR->warp();
        }
    }

    void launch(PHLWINDOW window, const CBox& target) {
        // Capture on the first render, after map has finished mapping the
        // surface tree too. Neutralize the initial fade for the snapshot;
        // restore it if allocation fails.
        window->finishAnimation();
        const auto& FADE = window->presentation().alpha(Desktop::View::WINDOW_ALPHA_FADE);
        const float FROM = FADE->value(), GOAL = FADE->goal();
        const float DIM = window->presentation().dimPercent();
        // Native map starts dimmed even for the focused window, then eases
        // to its focused appearance. Finish that startup tint as we do its
        // geometry, so the retained image does not stay dark until hand-back.
        if (window == Desktop::focusState()->window()) window->presentation().warpDimPercent(0.F);
        FADE->setValueAndWarp(1.F);
        finishShadow(window);
        if (auto effect = CGenie::capture(window, target, 1.F)) {
            effect->toward(false);
            g_effects.insert_or_assign(window.get(), std::move(effect));
        } else {
            FADE->setValueAndWarp(FROM);
            *FADE = GOAL;
            window->presentation().warpDimPercent(DIM);
            window->presentation().refreshValues();
        }
    }

    void closed(PHLWINDOW window) {
        g_opening.erase(window.get());
        const auto TARGET = DockTargets::find(window, true);
        UP<CGenie> effect;
        if (const auto IT = g_effects.find(window.get()); IT != g_effects.end()) {
            if (TARGET) effect = std::move(IT->second);
            g_effects.erase(IT);
        } else if (TARGET) {
            effect = CGenie::capture(window, *TARGET, 0.F);
        }
        if (effect && Style::motionEnabled() && effect->valid()) {
            // close is emitted while the client can still be captured. Its
            // native fadeout reads this alpha later in the same unmap, so only
            // our detached image is drawn. The actual close is never delayed.
            window->presentation().alpha(Desktop::View::WINDOW_ALPHA_FADE)->setValueAndWarp(0.F);
            effect->close();
            g_closing.push_back(std::move(effect));
        }
        DockTargets::forget(window);
    }

    bool normal(const Render::CRenderContext& ctx) {
        return !ctx.m_renderingSnapshot && !ctx.m_renderingCapture && ctx.m_mode == Render::RENDER_MODE_NORMAL;
    }

    void draw(void* renderer, Render::CRenderContext& ctx, PHLWINDOW window, PHLMONITOR monitor,
        const Render::SWindowRenderPresentation& presentation, const Time::steady_tp& time, bool decorate,
        Render::eRenderPassMode mode, bool ignorePosition, bool standalone) {
        if ((ElasticDrag::suppressed(window) && (normal(ctx) || ElasticDrag::capturingOverview())) ||
            (normal(ctx) && WindowMotion::suppressed(window))) return;
        ((Draw)g_draw->m_original)(renderer, ctx, window, monitor, presentation, time, decorate, mode, ignorePosition, standalone);
    }

    void beforeFrame(PHLMONITOR monitor) {
        const bool ENABLED = Style::motionEnabled();
        std::erase_if(g_opening, [&](const auto& entry) {
            const auto& OPEN = entry.second;
            const auto W = OPEN.window.lock();
            if (!ENABLED || !validMapped(W) || !W->m_workspace || W->m_monitor != OPEN.monitor || W->m_workspace != OPEN.workspace || !W->m_workspace->visible()) return true;
            if (OPEN.monitor.lock() != monitor) return false;
            launch(W, OPEN.target);
            return true;
        });
        std::erase_if(g_effects, [ENABLED](const auto& entry) {
            return !ENABLED || !entry.second->valid() || entry.second->finished();
        });
        std::erase_if(g_closing, [ENABLED](const auto& effect) {
            return !ENABLED || !effect->valid() || effect->finished();
        });
        for (const auto& [_, effect] : g_effects)
            if (effect->monitor() == monitor) monitor->m_solitaryClient.reset();
        for (const auto& effect : g_closing)
            if (effect->monitor() == monitor) monitor->m_solitaryClient.reset();
    }

    void paint(const Event::SRenderStageEvent& event) {
        if (event.stage != RENDER_POST_WINDOWS || !event.context || !normal(event.context->get())) return;
        for (const auto& [_, effect] : g_effects)
            if (effect->monitor() == event.monitor) effect->paint(event.context->get());
        for (const auto& effect : g_closing)
            if (effect->monitor() == event.monitor) effect->paint(event.context->get());
    }
}

void WindowMotion::init(HANDLE handle) {
    g_handle = handle;
    void *moveAddress = nullptr, *drawAddress = nullptr;
    for (const auto& fn : HyprlandAPI::findFunctionsByName(handle, "moveToWorkspace"))
        if (fn.demangled.starts_with("Config::Actions::moveToWorkspace(Hyprutils::Memory::CSharedPointer<")) moveAddress = fn.address;
    for (const auto& fn : HyprlandAPI::findFunctionsByName(handle, "renderWindow"))
        if (fn.demangled.starts_with("Render::IHyprRenderer::renderWindow(")) drawAddress = fn.address;
    if (moveAddress && drawAddress) {
        g_move = HyprlandAPI::createFunctionHook(handle, moveAddress, (void*)move);
        g_draw = HyprlandAPI::createFunctionHook(handle, drawAddress, (void*)draw);
        if (!g_move->hook() || !g_draw->hook()) {
            HyprlandAPI::removeFunctionHook(handle, g_move);
            HyprlandAPI::removeFunctionHook(handle, g_draw);
            g_move = g_draw = nullptr;
        }
    }
    if (!g_move || !g_draw) {
        std::cerr << "[windows] Genie hooks unavailable; using ordinary window actions\n";
        return;
    }
    DockTargets::init(handle);
    auto& events = Event::bus()->m_events;
    g_listeners.emplace_back(events.render.preChecks.listen(beforeFrame));
    g_listeners.emplace_back(events.render.stage.listen(paint));
    g_listeners.emplace_back(events.window.openLate.listen([](PHLWINDOW w) {
        // A pure fade has no geometry animation to fire Hyprland's map-end
        // callbacks. Finish those callbacks now: they restore windowsMove
        // configs and end eager startup color sampling.
        if (!w->positionAnimation()->isBeingAnimated()) w->positionAnimation()->onAnimationEnd();
        if (!w->sizeAnimation()->isBeingAnimated()) w->sizeAnimation()->onAnimationEnd();
        // Decide from the dock at map time, before this new window can add
        // its own icon. Keep the identity and destination until first render.
        if (Style::motionEnabled())
            if (const auto TARGET = DockTargets::find(w)) g_opening.insert_or_assign(w.get(), SOpening{w, w->m_monitor, w->m_workspace, *TARGET});
    }));
    g_listeners.emplace_back(events.window.close.listen(closed));
    g_listeners.emplace_back(events.monitor.removed.listen([](PHLMONITOR m) {
        DockTargets::forget(m);
        std::erase_if(g_opening, [&](const auto& entry) { return entry.second.monitor.lock() == m; });
        std::erase_if(g_effects, [&](const auto& entry) { return entry.second->monitor() == m; });
        std::erase_if(g_closing, [&](const auto& effect) { return effect->monitor() == m; });
    }));
    g_listeners.emplace_back(events.config.reloaded.listen([] { g_opening.clear(); g_effects.clear(); g_closing.clear(); }));
}

bool WindowMotion::suppressed(PHLWINDOW window) {
    return window && g_effects.contains(window.get()) && Style::motionEnabled();
}

bool WindowMotion::available() { return g_draw != nullptr; }

void WindowMotion::takeForDrag(PHLWINDOW window) {
    // A drag supersedes an unfinished launch/restore. Only one presentation
    // may draw this live subject, even when it is grabbed immediately on map.
    g_opening.erase(window.get());
    g_effects.erase(window.get());
}

void WindowMotion::paintCarried(Render::CRenderContext& ctx, PHLWINDOW window, PHLMONITOR monitor) {
    if (!g_draw) return;
    auto presentation = window->presentation().renderPresentation();
    presentation.workspaceOffset = presentation.floatingOffset = {};
    presentation.workspaceAlpha = presentation.fadeAlpha = 1.F;
    presentation.alphaVisible = true;
    presentation.workspaceOffsetAnimating = presentation.workspaceScene = false;
    ((Draw)g_draw->m_original)(g_pHyprRenderer.get(), ctx, window, monitor, presentation, Time::steadyNow(), true, Render::RENDER_PASS_ALL, false, false);
}

void WindowMotion::exit() {
    g_listeners.clear();
    g_opening.clear();
    g_effects.clear();
    g_closing.clear();
    DockTargets::clear();
    CGenie::clearPass();
    if (g_move) HyprlandAPI::removeFunctionHook(g_handle, g_move);
    if (g_draw) HyprlandAPI::removeFunctionHook(g_handle, g_draw);
    g_move = g_draw = nullptr;
}
