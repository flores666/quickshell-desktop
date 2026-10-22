#include "TitleBar.hpp"

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
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/pass/RectPassElement.hpp>
#include <hyprland/src/render/pass/TexPassElement.hpp>

#include <linux/input-event-codes.h>

namespace {
    // macOS's proportions, in logical pixels.
    constexpr double HEIGHT = CTitleBar::HEIGHT, BUTTON = 12, GAP = 8, INSET = 12;
    // How far into a tiled window's top the pointer has to come to bring its
    // bar out: thin, since what is under it there is the application's.
    constexpr double EDGE = 4;
    constexpr int    TITLE_PT = 10, TITLE_WEIGHT = 600, GLYPH_PT = 8;

    // Close, minimize, zoom.
    const std::array<CHyprColor, 3>   LIGHTS = {CHyprColor{0xFFFF5F57}, CHyprColor{0xFFFEBC2E}, CHyprColor{0xFF28C840}};
    const std::array<std::string, 3>  GLYPHS = {"×", "−", "+"};
    const CHyprColor                  GLYPH_COLOR{0x99000000};

    CHyprColor                        withAlpha(CHyprColor color, float a) {
        color.a *= a;
        return color;
    }
}

CTitleBar::CTitleBar(PHLWINDOW window) : IHyprWindowDecoration(window), m_window(window) {}

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

bool CTitleBar::shown() const {
    const auto W = m_window.lock();
    return decorated() && Fullscreen::controller()->getFullscreenModes(W).internal != Fullscreen::FSMODE_FULLSCREEN &&
        (m_above || g_state->hovered.lock() == W);
}

SDecorationPositioningInfo CTitleBar::getPositioningInfo() {
    const auto W = m_window.lock();
    m_above      = W && W->m_isFloating && decorated();

    SDecorationPositioningInfo info;
    info.policy = DECORATION_POSITION_STICKY;
    // Inside the border: the bar is part of the window.
    info.priority = 10005;
    if (m_above) {
        info.edges          = DECORATION_EDGE_TOP;
        info.reserved       = true;
        info.desiredExtents = {{0.0, HEIGHT}, {0.0, 0.0}};
    } else
        // The window's own box, nothing reserved: the bar is drawn over its
        // top, and input there is offered to it.
        info.edges = DECORATION_EDGE_TOP | DECORATION_EDGE_BOTTOM | DECORATION_EDGE_LEFT | DECORATION_EDGE_RIGHT;
    return info;
}

void CTitleBar::onPositioningReply(const SDecorationPositioningReply& reply) {
    m_assigned = reply.assignedGeometry;
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

CBox CTitleBar::barBox() const {
    const auto W = m_window.lock();
    if (!validMapped(W))
        return {};

    CBox box;
    if (m_above)
        box = m_assigned.copy().translate(g_pDecorationPositioner->getEdgeDefinedPoint(DECORATION_EDGE_TOP, W));
    else {
        const auto WINDOW = W->getWindowMainSurfaceBox();
        box               = {WINDOW.x, WINDOW.y, WINDOW.w, HEIGHT};
    }

    if (W->m_workspace && !W->m_pinned)
        box.translate(W->m_workspace->m_renderOffset->value());
    return box;
}

CBox CTitleBar::buttonBox(int button) const {
    const auto BAR = barBox();
    return {BAR.x + INSET + button * (BUTTON + GAP), BAR.y + (HEIGHT - BUTTON) / 2, BUTTON, BUTTON};
}

bool CTitleBar::hoverableAt(const Vector2D& pos, bool hovered) const {
    if (!decorated() || Fullscreen::controller()->getFullscreenModes(m_window.lock()).internal == Fullscreen::FSMODE_FULLSCREEN)
        return false;
    auto box = barBox();
    if (!m_above && !hovered)
        box.h = EDGE;
    return box.containsPoint(pos);
}

int CTitleBar::buttonAt(const Vector2D& pos) const {
    for (int i = 0; i < 3; ++i)
        // Up to halfway into each gap, so the row has no dead spots.
        if (buttonBox(i).expand(GAP / 2).containsPoint(pos))
            return i;
    return -1;
}

void CTitleBar::draw(PHLMONITOR monitor, float const& a) {
    if (!shown())
        return;

    const auto  W       = m_window.lock();
    const float SCALE   = monitor->m_scale;
    const auto  BAR     = barBox();
    const auto  ROUND   = W->rounding();
    const auto  toLocal = [&](CBox box) { return box.translate(-monitor->m_position + W->m_floatingOffset).scale(SCALE).round(); };

    // The window's rounding at the top. A shape taller than the bar by twice
    // the rounding has its lower corners well out of the way, and is cut down
    // to what is drawn: the bar and, under a bar above the window, the two
    // corners the window's own rounding would leave open.
    const auto SHAPE = toLocal({BAR.x, BAR.y, BAR.w, HEIGHT + 2 * ROUND});
    std::vector<CBox> parts = {toLocal(BAR)};
    if (m_above) {
        parts.push_back(toLocal({BAR.x, BAR.y + HEIGHT, ROUND, ROUND}));
        parts.push_back(toLocal({BAR.x + BAR.w - ROUND, BAR.y + HEIGHT, ROUND, ROUND}));
    }
    for (const auto& clip : parts) {
        CRectPassElement::SRectData data;
        data.box           = SHAPE;
        data.clipBox       = clip;
        data.color         = withAlpha(CHyprColor{sc<uint64_t>(g_state->barColor->value())}, a);
        data.round         = std::round(ROUND * SCALE);
        data.roundingPower = W->roundingPower();
        g_pHyprRenderer->addPassElement(makeUnique<CRectPassElement>(data));
    }

    const auto TEXT    = CHyprColor{sc<uint64_t>(g_state->textColor->value())};
    const bool ACTIVE  = Desktop::focusState()->window() == W;
    const bool POINTED = g_state->hovered.lock() == W && g_state->overButtons;

    // Grey in a window without focus, as on macOS, until the pointer is on
    // them; their glyphs show only then.
    auto& glyphs = g_state->glyphs[SCALE];
    for (int i = 0; i < 3; ++i) {
        CRectPassElement::SRectData data;
        data.box   = toLocal(buttonBox(i));
        data.color = withAlpha(ACTIVE || POINTED ? LIGHTS[i] : withAlpha(TEXT, 0.2F), a);
        data.round = std::round(BUTTON * SCALE / 2);
        g_pHyprRenderer->addPassElement(makeUnique<CRectPassElement>(data));

        if (!POINTED)
            continue;
        if (!glyphs[i])
            glyphs[i] = g_pHyprRenderer->renderText(GLYPHS[i], GLYPH_COLOR, std::round(GLYPH_PT * SCALE), false, "sans-serif");
        CTexPassElement::SRenderData glyph;
        glyph.tex = glyphs[i];
        glyph.box = CBox{data.box.middle() - glyphs[i]->m_size / 2, glyphs[i]->m_size}.round();
        glyph.a   = a;
        g_pHyprRenderer->addPassElement(makeUnique<CTexPassElement>(std::move(glyph)));
    }

    // Centred on the window, and kept clear of the buttons on both sides.
    const int ROOM = std::floor((BAR.w - 2 * (INSET + 3 * BUTTON + 3 * GAP)) * SCALE);
    if (W->m_title.empty() || ROOM <= 0)
        return;
    const auto KEY = std::format("{}\n{}\n{}\n{:x}", W->m_title, SCALE, ROOM, g_state->textColor->value());
    if (!m_title || KEY != m_titleKey) {
        m_title    = g_pHyprRenderer->renderText(W->m_title, TEXT, std::round(TITLE_PT * SCALE), false, "sans-serif", ROOM, TITLE_WEIGHT);
        m_titleKey = KEY;
    }
    const auto                   LOCAL = toLocal(BAR);
    CTexPassElement::SRenderData title;
    title.tex = m_title;
    title.box = CBox{LOCAL.middle() - m_title->m_size / 2, m_title->m_size}.round();
    title.a   = ACTIVE ? a : a * 0.5F;
    g_pHyprRenderer->addPassElement(makeUnique<CTexPassElement>(std::move(title)));
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
    // The corners under a bar above the window included.
    auto box = barBox();
    box.h += W->rounding();
    g_pHyprRenderer->damageBox(box);
}

eDecorationLayer CTitleBar::getDecorationLayer() {
    // Above the window it is under the surface, so that the window covers the
    // corners drawn beneath it; over a tiled window it is over the surface.
    return m_above ? DECORATION_LAYER_UNDER : DECORATION_LAYER_OVER;
}

uint64_t CTitleBar::getDecorationFlags() {
    // Over a tiled window the bar's box is the whole window, so it takes input
    // only while it is shown: a hidden one must not stand in for the window
    // where Hyprland asks whether the pointer is on a decoration.
    return DECORATION_PART_OF_MAIN_WINDOW | (m_above || shown() ? DECORATION_ALLOWS_MOUSE_INPUT : 0);
}

std::string CTitleBar::getDisplayName() {
    return "TitleBar";
}
