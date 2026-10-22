#include "TitleBar.hpp"
#include "AppColor.hpp"
#include "Style.hpp"

#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/Workspace.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/pass/RectPassElement.hpp>
#include <hyprland/src/render/pass/TexPassElement.hpp>

#include <cairo/cairo.h>

namespace {
    constexpr int TITLE_PT = 10, TITLE_WEIGHT = 600;
    // How often a window's colour is read at most: each read waits on the
    // GPU, and a terminal printing commits every frame.
    constexpr auto SAMPLE_EVERY = std::chrono::milliseconds(250);

    CHyprColor     withAlpha(CHyprColor color, float a) {
        color.a *= a;
        return color;
    }

    CHyprColor mix(const CHyprColor& from, const CHyprColor& to, float t) {
        CHyprColor out = from;
        out.r += (to.r - from.r) * t;
        out.g += (to.g - from.g) * t;
        out.b += (to.b - from.b) * t;
        out.a += (to.a - from.a) * t;
        return out;
    }

    std::string key(const CHyprColor& color) {
        return std::format("{:.3f},{:.3f},{:.3f}", color.r, color.g, color.b);
    }
}

void CTitleBar::resample() {
    m_sampleDue = true;
}

void CTitleBar::retry() {
    if (m_sampleDue)
        damageEntire();
}

// Read while a frame is drawn (see AppColor), at most every so often; one put
// off is read once the moment is up, so the last commit of a burst counts.
// While the window opens every commit is read: its first frames are the ones
// that settle what colour it is.
void CTitleBar::sample(bool opening) {
    if (!m_sampleDue)
        return;
    const auto NOW   = std::chrono::steady_clock::now();
    const auto SINCE = NOW - m_sampled;
    if (!opening && SINCE < SAMPLE_EVERY) {
        if (!g_state->resample->armed())
            g_state->resample->updateTimeout(std::chrono::duration_cast<Time::steady_dur>(SAMPLE_EVERY - SINCE));
        return;
    }
    m_sampleDue = false;
    m_sampled   = NOW;
    m_appColor  = AppColor::top(m_window.lock());
}

// Hyprland draws no decoration on a fullscreen window, the overlay layer
// included (renderWindow is told not to decorate it): its bar is painted from
// the render stage instead (paintOverFullscreen).
void CTitleBar::draw(PHLMONITOR monitor, float const& a) {
    const auto W = m_window.lock();
    if (W && Fullscreen::controller()->getFullscreenModes(W).internal != Fullscreen::FSMODE_FULLSCREEN)
        paint(monitor, a);
}

bool CTitleBar::overFullscreen(PHLMONITOR monitor) const {
    const auto W = m_window.lock();
    return validMapped(W) && Fullscreen::controller()->getFullscreenModes(W).internal == Fullscreen::FSMODE_FULLSCREEN && W->m_monitor == monitor &&
        W->m_workspace && W->m_workspace->isVisible() && (m_reveal->value() > 0 || m_reveal->goal() > 0);
}

void CTitleBar::paint(PHLMONITOR monitor, float a) {
    if (!usable())
        return;
    const auto W       = m_window.lock();
    const bool OPENING = W->m_animatingIn;
    // Read even while the bar is away, so that it comes out in its colour.
    sample(OPENING);

    // The application's colour, or the system's. A bar that is away takes it
    // at once rather than fading in from the last, and so does one whose
    // window is still opening: it comes in with the window, in the colour the
    // window settles on, rather than in the system's and then recoloured.
    const auto COLOR = m_appColor.value_or(Style::system());
    if (!(m_color->goal() == COLOR)) {
        if (m_reveal->value() <= 0 || OPENING)
            m_color->setValueAndWarp(COLOR);
        else {
            m_color->setConfig(Style::fade());
            *m_color = COLOR;
        }
    }

    const float REVEAL = m_reveal->value();
    if (REVEAL <= 0)
        return;

    const float SCALE   = monitor->m_scale;
    const float ALPHA   = a * REVEAL;
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
        data.color         = withAlpha(m_color->value(), ALPHA);
        data.round         = std::round(ROUND * SCALE);
        data.roundingPower = W->roundingPower();
        g_pHyprRenderer->addPassElement(makeUnique<CRectPassElement>(data));
    }

    // Drawn in the ink of the colour the bar is going to, so the title turns
    // light or dark once rather than partway.
    const auto INK = Style::inkOn(COLOR);

    // Grey in a window without focus, as on macOS, until the pointer is on
    // them; their glyphs show only then.
    const float LIT = std::max(m_focus->value(), m_hover->value());
    for (int i = 0; i < Style::BUTTONS; ++i) {
        CRectPassElement::SRectData data;
        data.box   = toLocal(buttonBox(i));
        data.color = withAlpha(mix(withAlpha(INK.text, 0.2F), INK.buttons[i], LIT), ALPHA);
        data.round = std::round(BUTTON * SCALE / 2);
        g_pHyprRenderer->addPassElement(makeUnique<CRectPassElement>(data));
        if (m_hover->value() > 0)
            drawGlyph(i, data.box, INK.glyph, ALPHA * m_hover->value());
    }

    // Centred on the window, and kept clear of the buttons on both sides.
    const int ROOM = std::floor((BAR.w - 2 * (INSET + Style::BUTTONS * (BUTTON + GAP))) * SCALE);
    if (W->m_title.empty() || ROOM <= 0)
        return;
    const auto KEY = std::format("{}\n{}\n{}\n{}", W->m_title, SCALE, ROOM, key(INK.text));
    if (!m_title || KEY != m_titleKey) {
        m_title    = g_pHyprRenderer->renderText(W->m_title, INK.text, std::round(TITLE_PT * SCALE), false, "sans-serif", ROOM, TITLE_WEIGHT);
        m_titleKey = KEY;
    }
    const auto                   LOCAL = toLocal(BAR);
    CTexPassElement::SRenderData title;
    title.tex = m_title;
    title.box = CBox{LOCAL.middle() - m_title->m_size / 2, m_title->m_size}.round();
    title.a   = ALPHA * (0.5F + 0.5F * m_focus->value());
    g_pHyprRenderer->addPassElement(makeUnique<CTexPassElement>(std::move(title)));
}

/*
    A button's glyph, drawn into a texture of the button's own box (pixels) so
    it is centred on the button exactly: a character set in a face sits on its
    line's baseline, not in the middle of its box, and came out off centre.
    Close is a cross, minimize a bar, zoom a plus; layout shows what it does,
    two panes side by side on a floating window, which it tiles, and one on a
    tiled one, which it floats. Every stroke is the same weight.
*/
void CTitleBar::drawGlyph(int button, const CBox& box, const CHyprColor& color, float alpha) {
    const auto W     = m_window.lock();
    const int  SHAPE = button == 3 && W && W->m_isFloating ? 4 : button;
    const int  SIZE  = std::max(1, sc<int>(std::round(box.w)));
    auto&      tex   = g_state->glyphs[std::format("{}:{}:{}", SHAPE, SIZE, key(color))];
    if (!tex) {
        const auto SURFACE = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, SIZE, SIZE);
        const auto CR      = cairo_create(SURFACE);
        const double C = SIZE / 2.0, ARM = SIZE * 0.25, LINE = std::max(1.0, SIZE * 0.11);
        cairo_set_source_rgba(CR, color.r, color.g, color.b, color.a);
        cairo_set_line_width(CR, LINE);
        cairo_set_line_cap(CR, CAIRO_LINE_CAP_ROUND);
        const auto LINE_TO = [&](double x1, double y1, double x2, double y2) {
            cairo_move_to(CR, x1, y1);
            cairo_line_to(CR, x2, y2);
        };
        const auto PANE = [&](double x, double y, double w, double h, double r) {
            const double R = std::min(r, std::min(w, h) / 2);
            cairo_new_sub_path(CR);
            cairo_arc(CR, x + w - R, y + R, R, -M_PI / 2, 0);
            cairo_arc(CR, x + w - R, y + h - R, R, 0, M_PI / 2);
            cairo_arc(CR, x + R, y + h - R, R, M_PI / 2, M_PI);
            cairo_arc(CR, x + R, y + R, R, M_PI, 3 * M_PI / 2);
            cairo_close_path(CR);
        };
        switch (SHAPE) {
            case 0: {
                const double D = ARM * 0.85;
                LINE_TO(C - D, C - D, C + D, C + D);
                LINE_TO(C - D, C + D, C + D, C - D);
                cairo_stroke(CR);
                break;
            }
            case 1:
                LINE_TO(C - ARM, C, C + ARM, C);
                cairo_stroke(CR);
                break;
            case 2:
                LINE_TO(C - ARM, C, C + ARM, C);
                LINE_TO(C, C - ARM, C, C + ARM);
                cairo_stroke(CR);
                break;
            // Rounded as the windows they stand for are.
            case 3:
                PANE(C - ARM * 0.85, C - ARM * 0.85, ARM * 1.7, ARM * 1.7, ARM * 0.55);
                cairo_fill(CR);
                break;
            case 4: {
                const double PW = ARM * 0.7, GAP = LINE * 0.9, H = ARM * 1.8;
                PANE(C - GAP / 2 - PW, C - H / 2, PW, H, PW / 2);
                PANE(C + GAP / 2, C - H / 2, PW, H, PW / 2);
                cairo_fill(CR);
                break;
            }
        }
        cairo_surface_flush(SURFACE);
        tex = g_pHyprRenderer->createTexture(SURFACE);
        cairo_destroy(CR);
        cairo_surface_destroy(SURFACE);
    }
    CTexPassElement::SRenderData glyph;
    glyph.tex = tex;
    glyph.box = CBox{box.pos(), {sc<double>(SIZE), sc<double>(SIZE)}};
    glyph.a   = alpha;
    g_pHyprRenderer->addPassElement(makeUnique<CTexPassElement>(std::move(glyph)));
}
