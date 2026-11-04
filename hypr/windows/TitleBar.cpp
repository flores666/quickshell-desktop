#include "TitleBar.hpp"
#include "Style.hpp"

#include <hyprland/src/animation/AnimationManager.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <hyprland/src/render/Renderer.hpp>

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

    listen();
}

CTitleBar* CTitleBar::of(PHLWINDOW window) {
    for (const auto& deco : window->presentation().decorations())
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

static bool maximized(PHLWINDOW window) {
    return window && Fullscreen::controller()->getFullscreenModes(window).internal == Fullscreen::FSMODE_MAXIMIZED;
}

bool CTitleBar::goesAbove() const {
    // Fullscreen, a floating window's bar is over it as a tiled one's is.
    const auto W = m_window.lock();
    return W && W->isFloating() && decorated() && !fullscreen(W);
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
        info.desiredExtents = {{0.0, Style::height() * m_roll->value()}, {0.0, 0.0}};
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
    // Hyprland lays a maximized window out once, as it maximizes, and not
    // again when the room it takes from it changes; a recalculation of its
    // space checks it against the work area less that room.
    const auto W = m_window.lock();
    if (maximized(W) && W->layoutTarget() && W->layoutTarget()->space())
        W->layoutTarget()->space()->recalculate();
}

void CTitleBar::restoreUnder(const Vector2D& pointer) {
    const auto W      = m_window.lock();
    const auto TARGET = W ? W->layoutTarget() : nullptr;
    if (!TARGET || !W->isFloating() || !Fullscreen::controller()->isFullscreen(W))
        return;
    Fullscreen::controller()->setFullscreenMode(W, Fullscreen::FSMODE_NONE, Fullscreen::FSMODE_NONE);
    // The size Hyprland kept as it maximized it, the bar above the window
    // with the pointer where it took the bar. One that never had a size of
    // its own floating (it opened fullscreen) is left to Hyprland's drag.
    const auto SIZE = TARGET->lastFloatingSize();
    if (SIZE.x <= 0 || SIZE.y <= 0)
        return;
    const auto GRAB = g_state->grab;
    g_layoutManager->setTargetGeom({pointer.x - GRAB.x * SIZE.x, pointer.y - GRAB.y + Style::height(), SIZE.x, SIZE.y}, TARGET);
}

void CTitleBar::keepOnScreen() {
    const auto W      = m_window.lock();
    const auto TARGET = W ? W->layoutTarget() : nullptr;
    // A tiled window being dragged is floated too, and follows the pointer.
    if (!m_above || !TARGET || !TARGET->space() || Fullscreen::controller()->isFullscreen(W) || g_layoutManager->dragController()->target() == TARGET)
        return;

    const auto AREA = TARGET->space()->workArea(true);
    auto       box  = TARGET->position();
    const auto TOP  = AREA.y + Style::height();
    if (box.y >= TOP)
        return;
    box.h = std::min(box.h, AREA.y + AREA.h - TOP);
    box.y = TOP;
    g_layoutManager->setTargetGeom(box, TARGET);
}

CBox CTitleBar::windowBox() const {
    const auto W = m_window.lock();
    if (!validMapped(W))
        return {};
    auto box = W->getWindowMainSurfaceBox();
    if (W->m_workspace && !(W->m_state & Desktop::View::WINDOW_STATE_PINNED))
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
        const double OUT = Style::height() * m_roll->value();
        return {WINDOW.x, WINDOW.y - OUT, WINDOW.w, OUT};
    }
    return {WINDOW.x, WINDOW.y, WINDOW.w, Style::height()};
}

CBox CTitleBar::buttonBox(int button) const {
    const auto BAR = barBox();
    return {BAR.x + Style::inset() + button * (Style::button() + Style::gap()), BAR.y + (Style::height() - Style::button()) / 2, Style::button(), Style::button()};
}

CBox CTitleBar::edgeBox() const {
    // The window's reveal edge, and as far above it as a bar above the
    // window would reach: what is there is the gap the layout leaves, and
    // Pointer finds the window there only where nothing else is.
    const auto WINDOW = windowBox();
    return {WINDOW.x, WINDOW.y - Style::height(), WINDOW.w, Style::height() + Style::edge()};
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
        if (buttonBox(i).expand(Style::gap() / 2).containsPoint(pos))
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
    // Over a maximized window the bar is at once what it is: its room is
    // taken from the window, which is laid out with all of it or none.
    if (const float OUT = m_above ? 1.F : 0.F; maximized(W)) {
        if (m_roll->value() != OUT || m_roll->goal() != OUT)
            m_roll->setValueAndWarp(OUT);
    } else
        EASE(m_roll, m_above ? 1.F : 0.F, m_above ? Style::rollOut() : Style::rollIn());
    EASE(m_reveal, usable() && !m_above && g_state->revealed.lock() == W ? 1.F : 0.F, Style::fade());
    EASE(m_hover, g_state->hovered.lock() == W && g_state->overButtons ? 1.F : 0.F, Style::hover());
    EASE(m_focus, Desktop::focusState()->window() == W ? 1.F : 0.F, Style::fade());
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
    g_pHyprRenderer->damageBox({WINDOW.x, WINDOW.y - Style::height(), WINDOW.w, 2 * Style::height() + W->presentation().rounding()});
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
