#include "Stacking.hpp"

#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/ViewHitTester.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/plugins/HookSystem.hpp>
#include <hyprland/src/render/Renderer.hpp>

#include <algorithm>
#include <vector>

namespace {
    using RenderWorkspaceWindows = void (*)(void*, PHLMONITOR, PHLWORKSPACE, const Time::steady_tp&);
    using RenderWindow           = void (*)(void*, PHLWINDOW, PHLMONITOR, const Time::steady_tp&, bool, Render::eRenderPassMode, bool, bool);
    using WindowAt               = PHLWINDOW (*)(const void*, const Vector2D&, uint16_t, PHLWINDOW);

    CFunctionHook* g_drawHook     = nullptr;
    CFunctionHook* g_hitHook      = nullptr;
    RenderWindow   g_renderWindow = nullptr;

    // What renderWorkspaceWindows draws of this workspace, bottom to top, as
    // it chooses them: pinned windows are drawn after every workspace, and a
    // special workspace's floating windows on another monitor with its base.
    std::vector<PHLWINDOW> drawn(void* renderer, const PHLMONITOR& monitor, const PHLWORKSPACE& workspace) {
        std::vector<PHLWINDOW> out;
        for (const auto& w : Desktop::windowState()->windows()) {
            if (w->isHidden() || !w->m_isMapped || !sc<Render::IHyprRenderer*>(renderer)->shouldRenderWindow(w, monitor))
                continue;
            const bool IGNORE_SPECIAL = w->m_monitorMovedFrom != -1 && w->m_workspace && !w->m_workspace->isVisible();
            if (!IGNORE_SPECIAL && workspace->m_isSpecialWorkspace != w->onSpecialWorkspace())
                continue;
            if (w->m_isFloating && (w->m_pinned || (workspace->m_isSpecialWorkspace && w->m_monitor != workspace->m_monitor)))
                continue;
            out.push_back(w);
        }
        return out;
    }

    /*
        Hyprland draws the tiled windows, the focused one last, then the
        closing tiled ones, then the focused one's popups, then the floating
        windows whole and the closing floating ones. Drawn in stacking order
        instead, each run of tiled windows is drawn as that tiled pass is,
        and each floating window whole where it stands; with no tiled window
        above a floating one that is exactly Hyprland's order, so Hyprland
        draws it.
    */
    void hkRenderWorkspaceWindows(void* renderer, PHLMONITOR monitor, PHLWORKSPACE workspace, const Time::steady_tp& time) {
        const auto WINDOWS = drawn(renderer, monitor, workspace);
        const auto FLOAT   = std::ranges::find_if(WINDOWS, [](const auto& w) { return w->m_isFloating; });
        if (std::none_of(FLOAT, WINDOWS.end(), [](const auto& w) { return !w->m_isFloating; })) {
            ((RenderWorkspaceWindows)g_drawHook->m_original)(renderer, monitor, workspace, time);
            return;
        }

        Event::bus()->m_events.render.stage.emit(RENDER_PRE_WINDOWS);
        const auto FOCUSED    = Desktop::focusState()->window();
        bool       fadedTiled = false;
        for (auto run = WINDOWS.begin(); run != WINDOWS.end();) {
            const bool TILED = !(*run)->m_isFloating;
            const auto END   = std::find_if(run, WINDOWS.end(), [TILED](const auto& w) { return w->m_isFloating == TILED; });
            if (!TILED) {
                for (auto it = run; it != END; ++it)
                    g_renderWindow(renderer, *it, monitor, time, true, Render::RENDER_PASS_ALL, false, false);
            } else {
                const auto LAST = std::find(run, END, FOCUSED);
                for (auto it = run; it != END; ++it)
                    if (it != LAST)
                        g_renderWindow(renderer, *it, monitor, time, true, Render::RENDER_PASS_MAIN, false, false);
                if (LAST != END)
                    g_renderWindow(renderer, *LAST, monitor, time, true, Render::RENDER_PASS_MAIN, false, false);
                // Below whatever floats above the first run, as below every floating window.
                if (!fadedTiled)
                    g_pHyprRenderer->renderFadeouts(monitor, Desktop::FADEOUT_PLANE_WINDOW_TILED, workspace);
                fadedTiled = true;
                if (LAST != END)
                    g_renderWindow(renderer, *LAST, monitor, time, true, Render::RENDER_PASS_POPUP, false, false);
            }
            run = END;
        }
        g_pHyprRenderer->renderFadeouts(monitor, Desktop::FADEOUT_PLANE_WINDOW_FLOATING, workspace);
    }

    /*
        Hyprland finds a floating window at a point before any tiled one,
        whatever it is asked: a tiled window stacked above it there is the one
        drawn, so it is the one hit. Asked again it would only find the
        floating window again, so the tiled one is looked for here, by the box
        Hyprland hits a floating window by.
    */
    PHLWINDOW hkWindowAt(const void* tester, const Vector2D& pos, uint16_t properties, PHLWINDOW ignore) {
        const auto FOUND = ((WindowAt)g_hitHook->m_original)(tester, pos, properties, ignore);
        if (!FOUND || !FOUND->m_isFloating || FOUND->m_pinned || !FOUND->m_workspace || (properties & Desktop::View::FLOATING_ONLY) ||
            Fullscreen::controller()->hasFullscreen(FOUND->m_workspace))
            return FOUND;
        const auto& ALL = Desktop::windowState()->windows();
        for (auto it = ALL.rbegin(); it != ALL.rend() && *it != FOUND; ++it) {
            const auto& W = *it;
            if (W->m_isFloating || !W->m_isMapped || W->isHidden() || W->m_workspace != FOUND->m_workspace || W == ignore || !W->acceptsInput() ||
                W->m_ruleApplicator->noFocus().valueOrDefault() || ((properties & Desktop::View::FOCUS_PRIORITY) && !W->priorityFocus()))
                continue;
            if (W->getWindowBoxUnified(properties).containsPoint(pos) || (!W->m_isX11 && W->hasPopupAt(pos)))
                return W;
        }
        return FOUND;
    }

    void* find(HANDLE handle, const std::string& name, const std::string& demangled) {
        for (const auto& fn : HyprlandAPI::findFunctionsByName(handle, name))
            if (fn.demangled.starts_with(demangled))
                return fn.address;
        return nullptr;
    }
}

void Stacking::init(HANDLE handle) {
    const auto DRAW = find(handle, "renderWorkspaceWindows", "Render::IHyprRenderer::renderWorkspaceWindows(");
    const auto HIT  = find(handle, "windowAt", "Desktop::CViewHitTester::windowAt(");
    g_renderWindow  = (RenderWindow)find(handle, "renderWindow", "Render::IHyprRenderer::renderWindow(");
    // Both or neither: drawn one way and hit the other, a covered window would take the clicks.
    if (DRAW && HIT && g_renderWindow) {
        g_drawHook = HyprlandAPI::createFunctionHook(handle, DRAW, (void*)hkRenderWorkspaceWindows);
        g_hitHook  = HyprlandAPI::createFunctionHook(handle, HIT, (void*)hkWindowAt);
        if (g_drawHook->hook() && g_hitHook->hook())
            return;
        HyprlandAPI::removeFunctionHook(handle, g_drawHook);
        HyprlandAPI::removeFunctionHook(handle, g_hitHook);
    }
    HyprlandAPI::addNotification(handle, "[windows] Hyprland's drawing could not be hooked; a clicked tiled window stays under floating ones",
                                 CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
}
