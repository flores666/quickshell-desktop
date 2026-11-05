#include "DockTargets.hpp"

#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowMetadata.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <lua.hpp>
#include <charconv>
#include <cctype>
#include <cmath>
#include <unordered_map>

namespace {
    struct STargets {
        std::unordered_map<uintptr_t, CBox> windows;
        std::unordered_map<std::string, CBox> apps;
    };
    std::unordered_map<std::string, STargets> g_targets;

    std::string identity(std::string value) {
        for (auto& c : value) c = std::tolower(sc<unsigned char>(c));
        return value;
    }

    // Malformed nested data returns normally: Lua's longjmp must not skip
    // container destructors. Replace the entire map only after validation.
    int publish(lua_State* L) {
        luaL_checktype(L, 1, LUA_TTABLE);
        decltype(g_targets) next;
        lua_pushnil(L);
        while (lua_next(L, 1)) {
            if (lua_type(L, -2) != LUA_TSTRING || !lua_istable(L, -1)) return 0;
            auto& entries = next[lua_tostring(L, -2)];
            for (size_t i = 1; i <= lua_rawlen(L, -1); ++i) {
                lua_rawgeti(L, -1, i);
                if (!lua_istable(L, -1)) return 0;
                lua_getfield(L, -1, "address");
                uintptr_t key = 0;
                const bool ADDRESS = !lua_isnil(L, -1);
                if (ADDRESS) {
                    if (lua_type(L, -1) != LUA_TSTRING) return 0;
                    std::string_view address = lua_tostring(L, -1);
                    if (address.starts_with("0x")) address.remove_prefix(2);
                    const auto READ = std::from_chars(address.data(), address.data() + address.size(), key, 16);
                    if (!key || READ.ec != std::errc{} || READ.ptr != address.data() + address.size()) return 0;
                }
                lua_pop(L, 1);
                std::string app;
                if (!ADDRESS) {
                    lua_getfield(L, -1, "appId");
                    if (lua_type(L, -1) != LUA_TSTRING) return 0;
                    app = identity(lua_tostring(L, -1));
                    lua_pop(L, 1);
                    if (app.empty()) return 0;
                }
                CBox box;
                double* values[] = {&box.x, &box.y, &box.w, &box.h};
                const char* names[] = {"x", "y", "width", "height"};
                for (int j = 0; j < 4; ++j) {
                    lua_getfield(L, -1, names[j]);
                    const bool NUMBER = lua_isnumber(L, -1);
                    *values[j] = lua_tonumber(L, -1);
                    lua_pop(L, 1);
                    if (!NUMBER || !std::isfinite(*values[j])) return 0;
                }
                if (box.w <= 0 || box.h <= 0) return 0;
                if (ADDRESS) entries.windows.emplace(key, box);
                else entries.apps.emplace(app, box);
                lua_pop(L, 1);
            }
            lua_pop(L, 1);
        }
        g_targets = std::move(next);
        return 0;
    }
}

void DockTargets::init(HANDLE handle) {
    if (!HyprlandAPI::addLuaFunction(handle, "windows", "dock_targets", publish))
        throw std::runtime_error("[windows] could not register dock_targets");
}

std::optional<CBox> DockTargets::find(PHLWINDOW window) {
    const auto MONITOR = window->m_monitor.lock();
    if (!MONITOR) return std::nullopt;
    const auto SCREEN = g_targets.find(MONITOR->m_name);
    if (SCREEN == g_targets.end()) return std::nullopt;
    const auto& ENTRIES = SCREEN->second;
    if (const auto RECT = ENTRIES.windows.find(rc<uintptr_t>(window.get())); RECT != ENTRIES.windows.end()) return RECT->second;
    const auto APP = ENTRIES.apps.find(identity(window->metadata().appID()));
    return APP == ENTRIES.apps.end() ? std::nullopt : std::make_optional(APP->second);
}

void DockTargets::forget(PHLWINDOW window) {
    for (auto& [_, entries] : g_targets) entries.windows.erase(rc<uintptr_t>(window.get()));
}

void DockTargets::forget(PHLMONITOR monitor) { g_targets.erase(monitor->m_name); }
void DockTargets::clear() { g_targets.clear(); }
