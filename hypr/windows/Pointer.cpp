#include "TitleBar.hpp"
#include "Style.hpp"

#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/desktop/state/ViewHitTester.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopManager.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/protocols/LayerShell.hpp>
#include <hyprland/src/state/MonitorState.hpp>

#include <linux/input-event-codes.h>

#include <ranges>

/*
    Which bar the pointer is on, and which tiled window's bar is out.

    A bar above a floating window is always there and answers the pointer at
    once. One over a tiled or fullscreen window comes out only once the
    pointer has rested where it would be for the shell's reveal time: a
    pointer on its way past — up to the shell's bar, over a window that fills
    the screen — brings nothing out. Once out it stays while the pointer is on
    it, and a moment (the linger) after it leaves, so a path that strays off
    it does not take it away.
*/
namespace {
    void animate(PHLWINDOW window) {
        if (const auto BAR = window ? CTitleBar::of(window) : nullptr)
            BAR->animate();
    }

    std::optional<Time::steady_dur> after(int ms) {
        return std::chrono::milliseconds(ms);
    }

    bool underShell(const Vector2D& pos) {
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

    // The topmost window at a point if it has a bar, with no shell surface
    // over it.
    PHLWINDOW windowAt(const Vector2D& pos) {
        const auto WINDOW = Desktop::viewState()->hitTest().windowAt(pos, Desktop::View::RESERVED_EXTENTS | Desktop::View::INPUT_EXTENTS | Desktop::View::ALLOW_FLOATING);
        return WINDOW && CTitleBar::of(WINDOW) && !underShell(pos) ? WINDOW : nullptr;
    }

    // The pointer rests where a tiled or fullscreen window's bar would be, or
    // nowhere such.
    void wait(PHLWINDOW window) {
        if (g_state->waiting.lock() == window)
            return;
        g_state->waiting = window;
        g_state->dwell->updateTimeout(window ? after(Style::dwell()) : std::nullopt);
    }

    // A bar that is out goes once the pointer has been off it a moment.
    void settle() {
        const auto OUT = g_state->revealed.lock();
        if (!OUT || g_state->hovered.lock() == OUT)
            g_state->linger->updateTimeout(std::nullopt);
        else if (!g_state->linger->armed())
            g_state->linger->updateTimeout(after(Style::linger()));
    }

    void onDwell() {
        const auto W   = g_state->waiting.lock();
        const auto BAR = W ? CTitleBar::of(W) : nullptr;
        g_state->waiting.reset();
        if (!BAR || !BAR->revealsAt(g_state->pointer) || !g_state->held.empty())
            return;
        g_state->reveal(W);
        g_state->hover(W, BAR->buttonAt(g_state->pointer) != -1);
    }

    void onLinger() {
        const auto OUT = g_state->revealed.lock();
        if (OUT && g_state->hovered.lock() != OUT)
            g_state->reveal(nullptr);
    }

    SP<CEventLoopTimer> timer(void (*fire)()) {
        auto t = makeShared<CEventLoopTimer>(std::nullopt, [fire](SP<CEventLoopTimer>, void*) { fire(); }, nullptr);
        g_pEventLoopManager->addTimer(t);
        return t;
    }
}

void SState::hover(PHLWINDOW window, bool buttons) {
    const auto OLD = hovered.lock();
    if (OLD == window && overButtons == buttons)
        return;
    if (OLD != window)
        armed = -1;
    hovered     = window;
    overButtons = buttons;
    animate(OLD);
    animate(window);
}

void SState::reveal(PHLWINDOW window) {
    const auto OLD = revealed.lock();
    linger->updateTimeout(std::nullopt);
    if (OLD == window)
        return;
    revealed = window;
    animate(OLD);
    animate(window);
}

void Pointer::init() {
    g_state->dwell  = timer(onDwell);
    g_state->linger = timer(onLinger);
}

void Pointer::exit() {
    // Their callbacks are this library's code.
    for (const auto& t : {g_state->dwell, g_state->linger})
        if (t)
            g_pEventLoopManager->removeTimer(t);
}

void Pointer::move(const Vector2D& pos, Event::SCallbackInfo& info) {
    g_state->pointer = pos;
    // Taken by something above the windows (the overview): no bar has it.
    if (info.cancelled) {
        g_state->hover(nullptr, false);
        wait(nullptr);
        settle();
        return;
    }

    if (const auto W = g_state->dragging.lock()) {
        g_state->dragging.reset();
        if (std::ranges::contains(g_state->held, BTN_LEFT) && validMapped(W))
            g_layoutManager->beginDragTarget(W->layoutTarget(), MBIND_MOVE);
    }

    const auto WINDOW = windowAt(pos);
    const auto BAR    = WINDOW ? CTitleBar::of(WINDOW) : nullptr;
    const bool OUT    = BAR && (BAR->above() || g_state->revealed.lock() == WINDOW);
    auto       on     = OUT && BAR->onBar(pos) ? WINDOW : nullptr;
    // While a button is held no bar newly takes the pointer: a selection
    // dragged up to a window's top must not bring out a bar, or move onto
    // one, that would take the release.
    const bool HOLDING = !g_state->held.empty();
    if (HOLDING && on != g_state->hovered.lock())
        on = nullptr;

    g_state->hover(on, on && BAR->buttonAt(pos) != -1);
    wait(!on && !HOLDING && BAR && BAR->revealsAt(pos) ? WINDOW : nullptr);
    settle();
    // A press acts only if released on the button it began on.
    if (g_state->armed != -1 && (!on || BAR->buttonAt(pos) != g_state->armed))
        g_state->armed = -1;
}

void Pointer::button(const IPointer::SButtonEvent& e) {
    if (e.state == WL_POINTER_BUTTON_STATE_PRESSED)
        g_state->held.push_back(e.button);
    else
        std::erase(g_state->held, e.button);
}

void Pointer::modeChanged(PHLWINDOW window, bool floated) {
    const auto BAR = CTitleBar::of(window);
    if (!BAR)
        return;
    if (g_state->hovered.lock() == window)
        g_state->hover(nullptr, false);
    if (g_state->revealed.lock() == window)
        g_state->reveal(nullptr);
    if (g_state->waiting.lock() == window)
        wait(nullptr);
    BAR->reposition();
    if (floated)
        BAR->keepOnScreen();
    BAR->animate();
}
