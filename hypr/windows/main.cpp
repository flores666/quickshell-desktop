#include "Placement.hpp"
#include "TitleBar.hpp"

#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/desktop/state/ViewHitTester.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/protocols/LayerShell.hpp>
#include <hyprland/src/state/MonitorState.hpp>

#include <linux/input-event-codes.h>

#include <ranges>

/*
    The desktop's own window behaviour, on the compositor's side: the title
    bars (TitleBar), and where a window opens and what it is remembered as
    (Placement).
*/

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

static void onOpen(PHLWINDOW window) {
    if (CTitleBar::of(window) || !CTitleBar::wanted(window))
        return;
    auto       bar = makeUnique<CTitleBar>(window);
    const auto BAR = bar.get();
    HyprlandAPI::addWindowDecoration(PHANDLE, window, std::move(bar));
    std::erase_if(g_state->decorated, [](const auto& w) { return w.expired(); });
    g_state->decorated.emplace_back(window);
    BAR->keepOnScreen();
}

static void damage(PHLWINDOW window) {
    if (const auto BAR = window ? CTitleBar::of(window) : nullptr)
        BAR->damageEntire();
}

void SState::hover(PHLWINDOW window, bool buttons) {
    const auto OLD = hovered.lock();
    if (OLD == window && overButtons == buttons)
        return;
    if (OLD != window)
        armed = -1;
    hovered     = window;
    overButtons = buttons;
    damage(OLD);
    damage(window);
}

static bool underShell(const Vector2D& pos) {
    const auto MONITOR = State::monitorState()->query().vec(pos).run();
    if (!MONITOR)
        return true;
    Vector2D local;
    PHLLS    layer;
    for (const auto LEVEL : {ZWLR_LAYER_SHELL_V1_LAYER_TOP, ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY})
        if (Desktop::viewState()->hitTest().layerSurfaceAt(pos, &MONITOR->m_layerSurfaceLayers[LEVEL], &local, &layer))
            return true;
    return false;
}

/*
    The window whose bar the pointer is on: the topmost window there, with no
    shell surface over it. While a button is held no bar newly takes the
    pointer — a selection dragged up to a tiled window's edge must not bring a
    bar over it that would take the release.
*/
static PHLWINDOW barAt(const Vector2D& pos) {
    const auto WINDOW = Desktop::viewState()->hitTest().windowAt(pos, Desktop::View::RESERVED_EXTENTS | Desktop::View::INPUT_EXTENTS | Desktop::View::ALLOW_FLOATING);
    const auto BAR    = WINDOW ? CTitleBar::of(WINDOW) : nullptr;
    if (!BAR || underShell(pos))
        return nullptr;
    const bool HOVERED = g_state->hovered.lock() == WINDOW;
    if (!HOVERED && !g_state->held.empty())
        return nullptr;
    return BAR->hoverableAt(pos, HOVERED) ? WINDOW : nullptr;
}

static void onMouseMove(const Vector2D& pos, Event::SCallbackInfo& info) {
    // Taken by something above the windows (the overview): no bar has it.
    if (info.cancelled) {
        g_state->hover(nullptr, false);
        return;
    }

    if (const auto W = g_state->dragging.lock()) {
        g_state->dragging.reset();
        if (std::ranges::contains(g_state->held, BTN_LEFT) && validMapped(W))
            g_layoutManager->beginDragTarget(W->layoutTarget(), MBIND_MOVE);
    }

    const auto WINDOW = barAt(pos);
    const auto BAR    = WINDOW ? CTitleBar::of(WINDOW) : nullptr;
    g_state->hover(WINDOW, BAR && BAR->buttonAt(pos) != -1);
    // A press acts only if released on the button it began on.
    if (g_state->armed != -1 && (!BAR || BAR->buttonAt(pos) != g_state->armed))
        g_state->armed = -1;
}

static void onMouseButton(const IPointer::SButtonEvent& e) {
    if (e.state == WL_POINTER_BUTTON_STATE_PRESSED)
        g_state->held.push_back(e.button);
    else
        std::erase(g_state->held, e.button);
}

// Floating or tiled, fullscreen or not: the pointer is placed afresh by its
// next move, and only floating moves the bar.
static void onModeChange(PHLWINDOW window, bool floatingChanged) {
    const auto BAR = CTitleBar::of(window);
    if (!BAR)
        return;
    if (g_state->hovered.lock() == window)
        g_state->hover(nullptr, false);
    if (floatingChanged) {
        BAR->reposition();
        BAR->keepOnScreen();
    } else
        BAR->damageEntire();
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    if (std::string{__hyprland_api_get_hash()} != __hyprland_api_get_client_hash()) {
        HyprlandAPI::addNotification(PHANDLE, "[windows] Built for another Hyprland; rebuild it with tools/build-windows-plugin.sh", CHyprColor{1.0, 0.2, 0.2, 1.0},
                                     5000);
        throw std::runtime_error("[windows] version mismatch");
    }

    g_state = makeUnique<SState>();
    Placement::load();

    // Pushed by the shell from the design system (CompositorTheme.qml). A
    // change redraws every window's decorations.
    using Config::Values::CColorValue;
    const auto REDRAW  = Config::Supplementary::REFRESH_WINDOW_STATES;
    g_state->barColor  = makeShared<CColorValue>("plugin:windows:bar_color", "The title bar's colour", 0xFFFFFFFF, Config::Values::SColorValueOptions{.refresh = REDRAW});
    g_state->textColor = makeShared<CColorValue>("plugin:windows:text_color", "The title's colour", 0xFF1C1B18, Config::Values::SColorValueOptions{.refresh = REDRAW});
    HyprlandAPI::addConfigValueV2(PHANDLE, g_state->barColor);
    HyprlandAPI::addConfigValueV2(PHANDLE, g_state->textColor);
    // The applications the bar is hidden for, comma-separated, from the
    // dock's menu (services/TitleBars.qml). A dispatcher rather than an
    // option: a `hyprctl keyword` tells no plugin its option changed, and
    // every bar has to be placed again — one hidden above a floating window
    // still held the room it reserved, under the window's shadow.
    HyprlandAPI::addDispatcherV2(PHANDLE, "windows:hidden_for", [](std::string ids) {
        g_state->hiddenFor.clear();
        for (const auto ID : std::views::split(ids, ','))
            if (!std::ranges::empty(ID))
                g_state->hiddenFor.emplace_back(std::string_view{ID});
        for (const auto& ref : g_state->decorated)
            if (const auto W = ref.lock(); W && W->m_isMapped)
                if (const auto BAR = CTitleBar::of(W))
                    BAR->reposition();
        return SDispatchResult{};
    });

    auto& events = Event::bus()->m_events;
    g_state->listeners = {
        // After the rules, before the layout places the window.
        events.window.openEarly.listen([](PHLWINDOW w) { Placement::place(w); }),
        events.window.close.listen([](PHLWINDOW w) { Placement::remember(w); }),
        events.exit.listen([] { Placement::rememberAll(); }),
        events.window.open.listen([](PHLWINDOW w) { onOpen(w); }),
        events.window.title.listen([](PHLWINDOW w) { damage(w); }),
        events.window.active.listen([](PHLWINDOW w, Desktop::eFocusReason) {
            damage(g_state->active.lock());
            damage(w);
            g_state->active = w;
        }),
        events.window.floating.listen([](PHLWINDOW w) {
            // Not the float a tile is dragged in, which follows the pointer
            // and which the drop undoes. Remembered as it changes, not only on
            // close, which a logout may skip.
            if (g_layoutManager->dragController()->target() != w->layoutTarget())
                Placement::floatingChanged(w);
            onModeChange(w, true);
        }),
        events.window.fullscreen.listen([](PHLWINDOW w) { onModeChange(w, false); }),
        // The `decorate` rule may have changed.
        events.window.updateRules.listen([](PHLWINDOW w) {
            if (const auto BAR = CTitleBar::of(w))
                BAR->reposition();
        }),
        events.input.mouse.move.listen([](Vector2D pos, Event::SCallbackInfo& info) { onMouseMove(pos, info); }),
        events.input.mouse.button.listen([](IPointer::SButtonEvent e, Event::SCallbackInfo&) { onMouseButton(e); }),
    };

    for (const auto& w : Desktop::windowState()->windows())
        if (w->m_isMapped && !w->isHidden())
            onOpen(w);

    // Hyprland reads the plugin's options from the config only on a reload,
    // and the shell pushes its colours again on one.
    HyprlandAPI::reloadConfig();

    return {"windows", "macOS-style title bars, and windows that open floating where they were left", "quickshell-desktop", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_state->listeners.clear();

    // Every bar goes now, while its code is still loaded. Hyprland removes a
    // plugin's decorations after this returns, but only from the windows it
    // lists, and from a closing or hidden one only queues the removal
    // (updateWindowDecos skips it): such a bar was destroyed later, through a
    // vtable into the unloaded library, and took the compositor with it.
    for (const auto& ref : g_state->decorated) {
        const auto W   = ref.lock();
        const auto BAR = W ? CTitleBar::of(W) : nullptr;
        if (!BAR)
            continue;
        g_pDecorationPositioner->uncacheDecoration(BAR);
        std::erase_if(W->m_windowDecorations, [BAR](const auto& d) { return d.get() == BAR; });
        if (!W->m_isMapped)
            continue;
        g_pDecorationPositioner->forceRecalcFor(W);
        W->updateWindowDecos();
        if (W->layoutTarget())
            W->layoutTarget()->recalc();
    }
}
