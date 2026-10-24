#include "Placement.hpp"
#include "TitleBar.hpp"

#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/rule/Engine.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRule.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/managers/XWaylandManager.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/output/Monitor.hpp>

#include <algorithm>
#include <array>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <unordered_map>

using namespace Desktop::Rule;

namespace {
    struct SRemembered {
        bool     floating = true;
        Vector2D size;
    };

    // By application id; read once, written whenever it changes.
    std::unordered_map<std::string, SRemembered> g_remembered;

    // The share of the work area a window opens at, at most, until it has a
    // size of its own here: the title bar counts towards the height.
    constexpr double MAX_WIDTH = 0.7, MAX_HEIGHT = 0.8;

    std::filesystem::path file() {
        const char* STATE = getenv("XDG_STATE_HOME");
        const char* HOME  = getenv("HOME");
        const auto  DIR   = STATE && *STATE ? std::filesystem::path{STATE} : std::filesystem::path{HOME ? HOME : "/tmp"} / ".local/state";
        return DIR / "hypr-windows" / "remembered";
    }

    // One line per application: floating (1) or tiled (0), width, height, id.
    void save() {
        const auto PATH = file();
        const auto TEMP = std::filesystem::path{PATH}.concat(".new");
        std::error_code ec;
        std::filesystem::create_directories(PATH.parent_path(), ec);
        {
            std::ofstream out(TEMP, std::ios::trunc);
            for (const auto& [APP, R] : g_remembered)
                out << R.floating << ' ' << sc<int>(R.size.x) << ' ' << sc<int>(R.size.y) << ' ' << APP << '\n';
            if (!out)
                return;
        }
        // Whole or not at all: a crash mid-write leaves the last good file.
        std::filesystem::rename(TEMP, PATH, ec);
    }

    /*
        Whether this is a window to place and remember: the default rule
        floats it, no rule of the user's decides its mode or place, and it is
        an application's own window rather than a dialog, a fixed-size panel,
        or one that opens fullscreen.
    */
    bool managed(PHLWINDOW window) {
        if (window->m_initialClass.empty() || window->isX11OverrideRedirect() || window->parent() || window->m_wantsInitialFullscreen ||
            g_pXWaylandManager->shouldBeFloated(window))
            return false;

        static constexpr std::array DECIDING = {WINDOW_RULE_EFFECT_FLOAT,  WINDOW_RULE_EFFECT_TILE,       WINDOW_RULE_EFFECT_SIZE,
                                                WINDOW_RULE_EFFECT_MOVE,   WINDOW_RULE_EFFECT_CENTER,     WINDOW_RULE_EFFECT_FULLSCREEN,
                                                WINDOW_RULE_EFFECT_MAXIMIZE, WINDOW_RULE_EFFECT_FULLSCREENSTATE};
        bool byDefault = false;
        for (const auto& r : ruleEngine()->rules()) {
            if (r->type() != RULE_TYPE_WINDOW)
                continue;
            const auto RULE = reinterpretPointerCast<CWindowRule>(r);
            // Exec rules too (`exec [float; size …] app`): they are the user's.
            if (!RULE->matches(window, true))
                continue;
            if (RULE->name() == Placement::DEFAULT_RULE)
                byDefault = true;
            else if (std::ranges::any_of(DECIDING, [&](auto e) { return RULE->effectsSet().contains(e); }))
                return false;
        }
        return byDefault;
    }
}

void Placement::load() {
    std::ifstream in(file());
    std::string   line;
    while (std::getline(in, line)) {
        std::istringstream fields(line);
        SRemembered        r;
        std::string        app;
        if (fields >> r.floating >> r.size.x >> r.size.y && std::getline(fields >> std::ws, app) && !app.empty())
            g_remembered[app] = r;
    }
}

/*
    Where a floating window goes: at the size it was last left at, or else at
    its own (what the application asks for, or has now) cut down to a share of
    the work area; centred, with its title bar, in the work area.
*/
static std::optional<CBox> floatingBox(PHLWINDOW window) {
    if (!window->m_workspace || !window->m_workspace->m_space)
        return std::nullopt;

    // The work area is a cache the space refreshes on its own schedule; a
    // window opened just after the screen changed was placed by the old one.
    const auto SPACE = window->m_workspace->m_space;
    SPACE->recheckWorkArea();
    const auto AREA = SPACE->workArea(true);
    const auto BAR  = CTitleBar::wanted(window) && !CTitleBar::hiddenFor(window) ? CTitleBar::HEIGHT : 0.0;

    Vector2D   size;
    const auto IT = g_remembered.find(window->m_initialClass);
    // Remembered floating but never at a size of its own (it was fullscreen
    // when it closed, or only ever tiled): as for a first launch.
    if (IT != g_remembered.end() && IT->second.size.x > 0 && IT->second.size.y > 0)
        size = IT->second.size;
    else {
        const Vector2D MOST = {AREA.w * MAX_WIDTH, AREA.h * MAX_HEIGHT - BAR};
        const auto     OWN  = window->layoutTarget()->desiredGeometry();
        size                = OWN ? OWN->size.clamp({}, MOST) : MOST;
    }
    size = size.clamp({}, {AREA.w, AREA.h - BAR}).round();

    return CBox{Vector2D{AREA.x + (AREA.w - size.x) / 2, AREA.y + BAR + (AREA.h - BAR - size.y) / 2}.round(), size};
}

void Placement::place(PHLWINDOW window) {
    if (!managed(window))
        return;

    const auto IT = g_remembered.find(window->m_initialClass);
    if (IT != g_remembered.end() && !IT->second.floating) {
        window->m_isFloating = false;
        return;
    }

    const auto BOX     = floatingBox(window);
    const auto MONITOR = window->m_workspace ? window->m_workspace->m_monitor.lock() : nullptr;
    if (!BOX || !MONITOR)
        return;

    // What a `size` and a `move` rule would set: Hyprland places the window
    // with them as it maps. A rule's position is the monitor's.
    const auto POS   = BOX->pos() - MONITOR->logicalBox().pos();
    auto&      rules = window->m_ruleApplicator->static_;
    rules.size       = Math::SExpressionVec2{std::to_string(sc<int>(BOX->w)), std::to_string(sc<int>(BOX->h))};
    rules.position   = Math::SExpressionVec2{std::to_string(sc<int>(POS.x)), std::to_string(sc<int>(POS.y))};
}

void Placement::floatingChanged(PHLWINDOW window) {
    // Floated from a tile, it takes the size it would open at, rather than
    // whatever Hyprland makes of the tile or of what the application asks.
    // Through the floating layout, which keeps the box: un-maximized or out of
    // fullscreen, the window goes back to it, and set past the layout it went
    // back to Hyprland's own pick, centred without its title bar.
    if (window->m_isFloating && managed(window) && !Fullscreen::controller()->isFullscreen(window)) {
        if (const auto BOX = floatingBox(window))
            g_layoutManager->setTargetGeom(*BOX, window->layoutTarget());
    }
    // Tiled from floating, the size it had floating is no longer the window's
    // own: Hyprland keeps it on the layout target. Not a tile dropped after a
    // drag, whose floating size was the drag's.
    else if (!window->m_isFloating && managed(window) && !g_layoutManager->dragController()->wasDraggingWindow()) {
        const auto LAST = window->layoutTarget()->lastFloatingSize();
        if (LAST.x > 0 && LAST.y > 0)
            g_remembered[window->m_initialClass].size = LAST;
    }
    remember(window);
}

static bool record(PHLWINDOW window) {
    if (!window->m_isMapped || !managed(window))
        return false;

    auto& r    = g_remembered[window->m_initialClass];
    r.floating = window->m_isFloating;
    // The size it was left at: not a maximized or fullscreen one, which is
    // not a size of its own, nor a tile's.
    if (window->m_isFloating && !Fullscreen::controller()->isFullscreen(window))
        r.size = window->size(Desktop::View::IGeometric::GEOMETRIC_GOAL);
    return true;
}

void Placement::remember(PHLWINDOW window) {
    if (record(window))
        save();
}

void Placement::rememberAll() {
    bool any = false;
    for (const auto& w : Desktop::windowState()->windows())
        any = record(w) || any;
    if (any)
        save();
}
