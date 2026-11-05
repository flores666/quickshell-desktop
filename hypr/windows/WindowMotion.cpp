#include "WindowMotion.hpp"
#include "Genie.hpp"

#include <hyprland/src/config/shared/actions/ConfigActions.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/plugins/HookSystem.hpp>
#include <hyprland/src/render/Renderer.hpp>

#include <lua.hpp>
#include <charconv>
#include <cmath>
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
    using Targets = std::unordered_map<uintptr_t, CBox>;
    std::unordered_map<std::string, Targets> g_targets;
    std::unordered_map<Desktop::View::CWindow*, UP<CGenie>> g_effects;

    std::optional<CBox> target(PHLWINDOW window) {
        const auto MONITOR = window->m_monitor.lock();
        if (!MONITOR) return std::nullopt;
        const auto SCREEN = g_targets.find(MONITOR->m_name);
        if (SCREEN == g_targets.end()) return std::nullopt;
        const auto RECT = SCREEN->second.find(rc<uintptr_t>(window.get()));
        return RECT == SCREEN->second.end() ? std::nullopt : std::make_optional(RECT->second);
    }

    bool minimized(PHLWORKSPACE workspace) {
        return workspace && workspace->addressableName() == "special:minimized";
    }

    Config::Actions::ActionResult move(PHLWORKSPACE workspace, bool silent, std::optional<PHLWINDOW> selected) {
        const auto W = selected.value_or(Desktop::focusState()->window());
        const bool MIN = validMapped(W) && minimized(workspace) && !minimized(W->m_workspace);
        const bool RESTORE = validMapped(W) && !minimized(workspace) && minimized(W->m_workspace);
        const bool MOTION = (MIN || RESTORE) && Style::motionEnabled();
        UP<CGenie> captured;
        if (MOTION && MIN && !g_effects.contains(W.get()))
            if (const auto TARGET = target(W)) captured = CGenie::capture(W, *TARGET, 0.F);

        // Focus, mode, workspace and the client's real box are changed by the
        // original action exactly once. Failure never leaves a hidden client.
        auto result = ((Move)g_move->m_original)(workspace, silent, selected);
        if (!result || !MOTION || !validMapped(W) || W->m_workspace != workspace) return result;

        auto existing = g_effects.find(W.get());
        if (existing != g_effects.end() && (!RESTORE || existing->second->sameDestination(W))) {
            existing->second->toward(MIN);
        } else {
            if (existing != g_effects.end()) g_effects.erase(existing);
            if (RESTORE && target(W)) {
                // The action has completed the layout, including fullscreen
                // restoration. Capture its final box rather than its travel
                // from a hidden workspace; the client is never dock-sized.
                W->finishAnimation();
                W->presentation().alpha(Desktop::View::WINDOW_ALPHA_MOVE_TO_WORKSPACE)->setValueAndWarp(1.F);
                W->presentation().alpha(Desktop::View::WINDOW_ALPHA_MOVE_FROM_WORKSPACE)->setValueAndWarp(1.F);
                W->presentation().resetMonitorMovedFrom();
                if (const auto TARGET = target(W)) captured = CGenie::capture(W, *TARGET, 1.F);
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

    bool normal(const Render::CRenderContext& ctx) {
        return !ctx.m_renderingSnapshot && !ctx.m_renderingCapture && ctx.m_mode == Render::RENDER_MODE_NORMAL;
    }

    void draw(void* renderer, Render::CRenderContext& ctx, PHLWINDOW window, PHLMONITOR monitor,
        const Render::SWindowRenderPresentation& presentation, const Time::steady_tp& time, bool decorate,
        Render::eRenderPassMode mode, bool ignorePosition, bool standalone) {
        if (normal(ctx) && WindowMotion::suppressed(window)) return;
        ((Draw)g_draw->m_original)(renderer, ctx, window, monitor, presentation, time, decorate, mode, ignorePosition, standalone);
    }

    // Whole-map replacement is atomic. A late shell update cannot preserve an
    // old monitor/address from an earlier snapshot. Malformed inputs never
    // reach the render mesh or replace the last valid map.
    int targets(lua_State* L) {
        luaL_checktype(L, 1, LUA_TTABLE);
        decltype(g_targets) next;
        lua_pushnil(L);
        while (lua_next(L, 1)) {
            // Return normally on malformed nested data: Lua's longjmp error
            // path must not bypass the C++ containers' destructors.
            if (lua_type(L, -2) != LUA_TSTRING || !lua_istable(L, -1)) return 0;
            const std::string SCREEN = lua_tostring(L, -2);
            auto& entries = next[SCREEN];
            for (size_t i = 1; i <= lua_rawlen(L, -1); ++i) {
                lua_rawgeti(L, -1, i);
                if (!lua_istable(L, -1)) return 0;
                lua_getfield(L, -1, "address");
                if (lua_type(L, -1) != LUA_TSTRING) return 0;
                std::string_view address = lua_tostring(L, -1);
                if (address.starts_with("0x")) address.remove_prefix(2);
                uintptr_t key = 0;
                const auto READ = std::from_chars(address.data(), address.data() + address.size(), key, 16);
                const bool VALID_ADDRESS = key && READ.ec == std::errc{} && READ.ptr == address.data() + address.size();
                lua_pop(L, 1);
                CBox box;
                double* values[] = {&box.x, &box.y, &box.w, &box.h};
                const char* names[] = {"x", "y", "width", "height"};
                bool valid = VALID_ADDRESS;
                for (int j = 0; j < 4; ++j) {
                    lua_getfield(L, -1, names[j]);
                    valid = valid && lua_isnumber(L, -1);
                    *values[j] = lua_tonumber(L, -1);
                    valid = valid && std::isfinite(*values[j]);
                    lua_pop(L, 1);
                }
                if (!valid || box.w <= 0 || box.h <= 0) return 0;
                entries.emplace(key, box);
                lua_pop(L, 1);
            }
            lua_pop(L, 1);
        }
        g_targets = std::move(next);
        return 0;
    }

    void beforeFrame(PHLMONITOR monitor) {
        const bool ENABLED = Style::motionEnabled();
        std::erase_if(g_effects, [ENABLED](const auto& entry) {
            return !ENABLED || !entry.second->valid() || entry.second->finished();
        });
        for (const auto& [_, effect] : g_effects)
            if (effect->monitor() == monitor) monitor->m_solitaryClient.reset();
    }

    void paint(const Event::SRenderStageEvent& event) {
        if (event.stage != RENDER_POST_WINDOWS || !event.context || !normal(event.context->get())) return;
        for (const auto& [_, effect] : g_effects)
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
    if (!HyprlandAPI::addLuaFunction(handle, "windows", "dock_targets", targets))
        throw std::runtime_error("[windows] could not register dock_targets");
    auto& events = Event::bus()->m_events;
    g_listeners.emplace_back(events.render.preChecks.listen(beforeFrame));
    g_listeners.emplace_back(events.render.stage.listen(paint));
    g_listeners.emplace_back(events.window.close.listen([](PHLWINDOW w) {
        g_effects.erase(w.get());
        for (auto& [_, entries] : g_targets) entries.erase(rc<uintptr_t>(w.get()));
    }));
    g_listeners.emplace_back(events.monitor.removed.listen([](PHLMONITOR m) {
        g_targets.erase(m->m_name);
        std::erase_if(g_effects, [&](const auto& entry) { return entry.second->monitor() == m; });
    }));
    g_listeners.emplace_back(events.config.reloaded.listen([] { g_effects.clear(); }));
}

bool WindowMotion::suppressed(PHLWINDOW window) {
    return window && g_effects.contains(window.get()) && Style::motionEnabled();
}

void WindowMotion::exit() {
    g_listeners.clear();
    g_effects.clear();
    g_targets.clear();
    CGenie::clearPass();
    if (g_move) HyprlandAPI::removeFunctionHook(g_handle, g_move);
    if (g_draw) HyprlandAPI::removeFunctionHook(g_handle, g_draw);
    g_move = g_draw = nullptr;
}
