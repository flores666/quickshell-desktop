#include "TitleBar.hpp"
#include "Style.hpp"

#include <hyprland/src/animation/AnimationManager.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>
#include <hyprland/src/managers/KeybindManager.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/config/shared/actions/ConfigActions.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <hyprland/src/render/Renderer.hpp>

#include <linux/input-event-codes.h>

CTitleBar::CTitleBar(PHLWINDOW window) : IHyprWindowDecoration(window), m_window(window) {
    // A new window's bar is at once what it is: the window's own fade brings
    // it in.
    m_above = goesAbove();
    Animation::mgr()->createAnimation(m_above ? 1.F : 0.F, m_roll, Style::rollOut(), AVARDAMAGE_NONE);
    Animation::mgr()->createAnimation(0.F, m_reveal, Style::fade(), AVARDAMAGE_NONE);
    Animation::mgr()->createAnimation(0.F, m_hover, Style::hover(), AVARDAMAGE_NONE);
    Animation::mgr()->createAnimation(0.F, m_focus, Style::fade(), AVARDAMAGE_NONE);
    Animation::mgr()->createAnimation(Style::system(), m_color, Style::fade(), AVARDAMAGE_NONE);
    const auto DAMAGE = [this](auto) { damageEntire(); };
    // Rolling, the room it takes above the window changes with it, and the
    // window's shadow, which is drawn under that room, follows.
    m_roll->setUpdateCallback([this](auto) { reposition(); });
    m_reveal->setUpdateCallback(DAMAGE);
    m_hover->setUpdateCallback(DAMAGE);
    m_focus->setUpdateCallback(DAMAGE);
    m_color->setUpdateCallback(DAMAGE);

    if (const auto SURFACE = window->resource())
        m_commit = SURFACE->m_events.commit.listen([this] { resample(); });
}

CTitleBar* CTitleBar::of(PHLWINDOW window) {
    for (const auto& deco : window->m_windowDecorations)
        if (const auto BAR = dynamic_cast<CTitleBar*>(deco.get()))
            return BAR;
    return nullptr;
}

// The `decorate` window rule leaves one window without a bar, the dock's
// menu an application.
bool CTitleBar::decorated() const {
    const auto W = m_window.lock();
    return validMapped(W) && W->m_ruleApplicator->decorate().valueOrDefault() && !hiddenFor(W);
}

bool CTitleBar::usable() const {
    return decorated();
}

static bool fullscreen(PHLWINDOW window) {
    return window && Fullscreen::controller()->getFullscreenModes(window).internal == Fullscreen::FSMODE_FULLSCREEN;
}

bool CTitleBar::goesAbove() const {
    // Fullscreen, a floating window's bar is over it as a tiled one's is.
    const auto W = m_window.lock();
    return W && W->m_isFloating && decorated() && !fullscreen(W);
}

bool CTitleBar::above() const {
    return m_roll->value() > 0;
}

bool CTitleBar::shown() const {
    return usable() && (above() || g_state->revealed.lock() == m_window.lock());
}

SDecorationPositioningInfo CTitleBar::getPositioningInfo() {
    // Only where it goes: whoever changed that rolls it there (animate), and
    // a roll started from here would place the bar again while it is being
    // placed.
    m_above = goesAbove();

    SDecorationPositioningInfo info;
    info.policy = DECORATION_POSITION_STICKY;
    // Inside the border: the bar is part of the window.
    info.priority = 10005;
    if (m_above || above()) {
        // As much room above the window as the bar is out, so the window's
        // shadow is under the bar and nowhere else. Reserved only once it is
        // all the way out above a floating window: what is reserved is taken
        // from a tile, or a maximized window, and a roll must not resize one.
        info.edges          = DECORATION_EDGE_TOP;
        info.reserved       = m_above && m_roll->value() >= 1;
        info.desiredExtents = {{0.0, HEIGHT * m_roll->value()}, {0.0, 0.0}};
    } else
        // The window's own box, nothing reserved: the bar is drawn over its
        // top, and input there is offered to it.
        info.edges = DECORATION_EDGE_TOP | DECORATION_EDGE_BOTTOM | DECORATION_EDGE_LEFT | DECORATION_EDGE_RIGHT;
    return info;
}

void CTitleBar::onPositioningReply(const SDecorationPositioningReply&) {
    // Drawn from the window's own box (barBox), which moves with every frame.
}

void CTitleBar::reposition() {
    g_pDecorationPositioner->repositionDeco(this);
    damageEntire();
}

void CTitleBar::keepOnScreen() {
    const auto W      = m_window.lock();
    const auto TARGET = W ? W->layoutTarget() : nullptr;
    // A tiled window being dragged is floated too, and follows the pointer.
    if (!m_above || !TARGET || !TARGET->space() || Fullscreen::controller()->isFullscreen(W) || g_layoutManager->dragController()->target() == TARGET)
        return;

    const auto AREA = TARGET->space()->workArea(true);
    auto       box  = TARGET->position();
    const auto TOP  = AREA.y + HEIGHT;
    if (box.y >= TOP)
        return;
    box.h = std::min(box.h, AREA.y + AREA.h - TOP);
    box.y = TOP;
    TARGET->setPositionGlobal(box);
}

CBox CTitleBar::windowBox() const {
    const auto W = m_window.lock();
    if (!validMapped(W))
        return {};
    auto box = W->getWindowMainSurfaceBox();
    if (W->m_workspace && !W->m_pinned)
        box.translate(W->m_workspace->m_renderOffset->value());
    return box;
}

CBox CTitleBar::barBox() const {
    // Above the window as far as it has rolled out of its top edge, or over
    // its top. What is on it rides the bar's upper edge (buttonBox), so
    // rolling, the far side of it shows first, as a popup's contents do in
    // its door.
    if (!validMapped(m_window.lock()))
        return {};
    const auto WINDOW = windowBox();
    if (above()) {
        const double OUT = HEIGHT * m_roll->value();
        return {WINDOW.x, WINDOW.y - OUT, WINDOW.w, OUT};
    }
    return {WINDOW.x, WINDOW.y, WINDOW.w, HEIGHT};
}

CBox CTitleBar::buttonBox(int button) const {
    const auto BAR = barBox();
    return {BAR.x + INSET + button * (BUTTON + GAP), BAR.y + (HEIGHT - BUTTON) / 2, BUTTON, BUTTON};
}

CBox CTitleBar::edgeBox() const {
    // The window's top EDGE px, and as far above them as a bar above the
    // window would reach: what is there is the gap the layout leaves, and
    // Pointer finds the window there only where nothing else is.
    const auto WINDOW = windowBox();
    return {WINDOW.x, WINDOW.y - HEIGHT, WINDOW.w, HEIGHT + EDGE};
}

bool CTitleBar::onBar(const Vector2D& pos) const {
    // Over its window, the edge that brought it out is still the bar's.
    return usable() && (barBox().containsPoint(pos) || revealsAt(pos));
}

bool CTitleBar::revealsAt(const Vector2D& pos) const {
    return usable() && !m_above && edgeBox().containsPoint(pos);
}

int CTitleBar::buttonAt(const Vector2D& pos) const {
    for (int i = 0; i < Style::BUTTONS; ++i)
        // Up to halfway into each gap, so the row has no dead spots.
        if (buttonBox(i).expand(GAP / 2).containsPoint(pos))
            return i;
    return -1;
}

void CTitleBar::animate() {
    const auto W = m_window.lock();
    if (!W)
        return;
    const auto EASE = [](PHLANIMVAR<float>& var, float to, const SP<Style::Config>& config) {
        if (var->goal() == to)
            return;
        var->setConfig(config);
        *var = to;
    };
    EASE(m_roll, m_above ? 1.F : 0.F, m_above ? Style::rollOut() : Style::rollIn());
    EASE(m_reveal, usable() && !m_above && g_state->revealed.lock() == W ? 1.F : 0.F, Style::fade());
    EASE(m_hover, g_state->hovered.lock() == W && g_state->overButtons ? 1.F : 0.F, Style::hover());
    EASE(m_focus, Desktop::focusState()->window() == W ? 1.F : 0.F, Style::fade());
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
        if (W->m_isFloating)
            Desktop::windowState()->raise(W);

        g_state->hover(W, buttonAt(pos) != -1);
        g_state->armed = buttonAt(pos);
        if (g_state->armed == -1)
            g_state->dragging = W;
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
            const auto MOVE = g_pKeybindManager->m_dispatchers.find("movetoworkspacesilent");
            if (MOVE != g_pKeybindManager->m_dispatchers.end())
                MOVE->second(std::format("special:minimized,address:0x{:x}", rc<uintptr_t>(W.get())));
            break;
        }
        case 2: (void)Config::Actions::fullscreenWindow(Fullscreen::FSMODE_MAXIMIZED, true, W); break;
        // Placed as it would open (Placement), and remembered so.
        case 3: (void)Config::Actions::floatWindow(Config::Actions::TOGGLE_ACTION_TOGGLE, W); break;
    }
}

eDecorationType CTitleBar::getDecorationType() {
    return DECORATION_CUSTOM;
}

void CTitleBar::updateWindow(PHLWINDOW) {
    damageEntire();
}

void CTitleBar::damageEntire() {
    const auto W = m_window.lock();
    if (!validMapped(W))
        return;
    // Above the window and over its top, and the corners under a bar above.
    const auto WINDOW = windowBox();
    g_pHyprRenderer->damageBox({WINDOW.x, WINDOW.y - HEIGHT, WINDOW.w, 2 * HEIGHT + W->rounding()});
}

eDecorationLayer CTitleBar::getDecorationLayer() {
    // Above the window it is under the surface, so that the window covers the
    // corners drawn beneath it. Over a tiled or fullscreen window it is on the
    // overlay layer, the one Hyprland still draws on a fullscreen window
    // (renderWindow skips the others there).
    return above() ? DECORATION_LAYER_UNDER : DECORATION_LAYER_OVERLAY;
}

uint64_t CTitleBar::getDecorationFlags() {
    // Over a tiled or fullscreen window the bar's box is the whole window, so
    // it takes input only while it is out: a hidden one must not stand in for the window
    // where Hyprland asks whether the pointer is on a decoration.
    return DECORATION_PART_OF_MAIN_WINDOW | (shown() ? DECORATION_ALLOWS_MOUSE_INPUT : 0);
}

std::string CTitleBar::getDisplayName() {
    return "TitleBar";
}
