#include "TitleBar.hpp"
#include "Style.hpp"

#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/config/shared/actions/ConfigActions.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
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
    pointer has rested at the window's top edge for the shell's reveal time,
    as macOS's menu bar does over a full-screen window: the top few pixels,
    or the gap above them, never the rest of where the bar would be, which
    is the application's (a browser's tabs). A pointer on its way past — up
    to the shell's bar, over a window that fills the screen — brings nothing
    out. Once out it stays while the pointer is on it or that edge, and a
    moment (the linger) after it leaves, so a path that strays off it does
    not take it away.
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
    // over it; where there is none, the window just below, whose top edge the
    // gap the point is in may be (CTitleBar::revealsAt says).
    PHLWINDOW windowAt(const Vector2D& pos) {
        if (underShell(pos))
            return nullptr;
        const auto PROPERTIES = Desktop::View::RESERVED_EXTENTS | Desktop::View::INPUT_EXTENTS | Desktop::View::ALLOW_FLOATING;
        auto       window     = Desktop::viewState()->hitTest().windowAt(pos, PROPERTIES);
        if (!window)
            window = Desktop::viewState()->hitTest().windowAt({pos.x, pos.y + Style::height()}, PROPERTIES);
        return window && CTitleBar::of(window) ? window : nullptr;
    }

    // The pointer rests at a tiled or fullscreen window's top edge, or
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
        if (std::ranges::contains(g_state->held, BTN_LEFT) && validMapped(W)) {
            if (const auto BAR = CTitleBar::of(W))
                BAR->placeUnderGrab(pos);
            g_layoutManager->beginDragTarget(W->layoutTarget(), MBIND_MOVE);
        }
        g_state->dragging.reset();
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

std::optional<Vector2D> Pointer::dragPress(PHLWINDOW window) {
    if (g_state->dragging.lock() == window) return g_state->pressed;
    return std::nullopt;
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

bool CTitleBar::onInputOnDeco(const eInputType type, const Vector2D& pos, std::any data) {
    if (type != INPUT_TYPE_BUTTON || !shown() || !barBox().containsPoint(pos))
        return false;

    // Every button on the bar is the bar's; only the left one does anything.
    const auto& E = std::any_cast<const IPointer::SButtonEvent&>(data);
    if (E.button != BTN_LEFT)
        return true;

    const auto W = m_window.lock();
    if (E.state == WL_POINTER_BUTTON_STATE_PRESSED) {
        if (!Desktop::focusState()->isWindowActive(W))
            Desktop::focusState()->rawWindowFocus(W, Desktop::FOCUS_REASON_CLICK);
        if (W->isFloating())
            Desktop::windowState()->raise(W);

        g_state->hover(W, buttonAt(pos) != -1);
        g_state->armed = buttonAt(pos);
        if (g_state->armed == -1) {
            g_state->dragging = W;
            g_state->pressed = pos;
            // Where along the bar it was taken, and how far down it.
            const auto BAR = barBox();
            g_state->grab  = {(pos.x - BAR.x) / BAR.w, pos.y - BAR.y};
        }
        return true;
    }

    const int ARMED = g_state->armed;
    g_state->armed  = -1;
    g_state->dragging.reset();
    if (ARMED != -1 && ARMED == buttonAt(pos))
        act(ARMED);
    return true;
}

void CTitleBar::act(int button) {
    const auto W = m_window.lock();
    switch (button) {
        case 0: (void)Config::Actions::closeWindow(W); break;
        case 1: {
            // Hyprland has no minimized state; a special workspace is the
            // idiom, and the dock brings a window back from it.
            (void)Config::Actions::moveToWorkspace("special:minimized", true, W);
            break;
        }
        case 2: (void)Config::Actions::fullscreenWindow(Fullscreen::FSMODE_MAXIMIZED, true, W); break;
        // Placed as it would open (Placement), and remembered so.
        case 3: (void)Config::Actions::floatWindow(Config::Actions::TOGGLE_ACTION_TOGGLE, W); break;
    }
}
