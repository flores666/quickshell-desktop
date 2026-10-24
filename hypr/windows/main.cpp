#include "Placement.hpp"
#include "Stacking.hpp"
#include "Style.hpp"
#include "TitleBar.hpp"

#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopManager.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/output/Monitor.hpp>

#include <ranges>

/*
    The desktop's own window behaviour, on the compositor's side: the title
    bars (TitleBar, drawn in TitleBarDraw, coloured by AppColor and Style,
    answering the pointer in Pointer), where a window opens and what it is
    remembered as (Placement), and tiled windows raised among the floating
    ones by a click (Stacking).
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
    BAR->animate();
}

static void forEachBar(const std::function<void(CTitleBar*)>& fn) {
    for (const auto& ref : g_state->decorated)
        if (const auto W = ref.lock(); W && W->m_isMapped)
            if (const auto BAR = CTitleBar::of(W))
                fn(BAR);
}

static void damage(PHLWINDOW window) {
    if (const auto BAR = window ? CTitleBar::of(window) : nullptr)
        BAR->damageEntire();
}

/*
    A fullscreen window is drawn undecorated, and on its own when nothing is
    over it — straight to the screen if its buffer allows (direct scanout),
    with no render pass at all. While its bar is out the monitor is kept off
    that path, which Hyprland settles just before these checks, and the bar is
    painted at the last stage of the frame, over everything the window has.
*/
static void keepRendered(PHLMONITOR monitor) {
    forEachBar([&](CTitleBar* bar) {
        if (bar->overFullscreen(monitor))
            monitor->m_solitaryClient.reset();
    });
}

static void paintOverFullscreen(eRenderStage stage) {
    const auto MONITOR = g_pHyprRenderer->m_renderData.pMonitor.lock();
    if (stage != RENDER_LAST_MOMENT || !MONITOR)
        return;
    forEachBar([&](CTitleBar* bar) {
        if (bar->overFullscreen(MONITOR))
            bar->paint(MONITOR, 1.F);
    });
}

static void animate(PHLWINDOW window) {
    if (const auto BAR = window ? CTitleBar::of(window) : nullptr)
        BAR->animate();
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
    Style::init(PHANDLE);
    Pointer::init();
    Stacking::init(PHANDLE);
    g_state->resample = makeShared<CEventLoopTimer>(std::nullopt, [](SP<CEventLoopTimer>, void*) { forEachBar([](CTitleBar* bar) { bar->retry(); }); }, nullptr);
    g_pEventLoopManager->addTimer(g_state->resample);

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
        forEachBar([](CTitleBar* bar) {
            bar->reposition();
            bar->animate();
        });
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
            animate(g_state->active.lock());
            animate(w);
            g_state->active = w;
        }),
        events.window.floating.listen([](PHLWINDOW w) {
            // Not the float a tile is dragged in, which follows the pointer
            // and which the drop undoes. Remembered as it changes, not only on
            // close, which a logout may skip.
            if (g_layoutManager->dragController()->target() != w->layoutTarget()) {
                // Floated or tiled, a window leaves maximize and fullscreen:
                // Hyprland puts the mode back after the toggle, and a window
                // floated again came back maximized, not at its own size.
                if (Fullscreen::controller()->isFullscreen(w))
                    Fullscreen::controller()->setFullscreenMode(w, Fullscreen::FSMODE_NONE, Fullscreen::FSMODE_NONE);
                Placement::floatingChanged(w);
            }
            Pointer::modeChanged(w, true);
        }),
        // Fullscreen, a floating window's bar moves over it.
        events.window.fullscreen.listen([](PHLWINDOW w) { Pointer::modeChanged(w, false); }),
        // The `decorate` rule may have changed: placed again, and in or out.
        events.window.updateRules.listen([](PHLWINDOW w) {
            if (const auto BAR = CTitleBar::of(w)) {
                BAR->reposition();
                BAR->animate();
            }
        }),
        events.config.reloaded.listen([] { Style::reloaded(); }),
        events.render.preChecks.listen([](PHLMONITOR m) { keepRendered(m); }),
        events.render.stage.listen([](eRenderStage s) { paintOverFullscreen(s); }),
        events.input.mouse.move.listen([](Vector2D pos, Event::SCallbackInfo& info) { Pointer::move(pos, info); }),
        events.input.mouse.button.listen([](IPointer::SButtonEvent e, Event::SCallbackInfo&) { Pointer::button(e); }),
    };

    for (const auto& w : Desktop::windowState()->windows())
        if (w->m_isMapped && !w->isHidden())
            onOpen(w);

    // Hyprland reads the plugin's options from the config only on a reload,
    // and the shell pushes its colours and timings again on one.
    HyprlandAPI::reloadConfig();

    return {"windows", "macOS-style title bars, and windows that open floating where they were left", "quickshell-desktop", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_state->listeners.clear();
    Pointer::exit();
    g_pEventLoopManager->removeTimer(g_state->resample);

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
