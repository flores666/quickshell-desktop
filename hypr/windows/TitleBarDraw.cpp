#include "TitleBar.hpp"
#include "AppColor.hpp"
#include "HugeiconsGlyphs.hpp"
#include "Style.hpp"

#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>
#include <hyprland/src/workspace/HLWorkspace.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/pass/RectPassElement.hpp>
#include <hyprland/src/render/pass/TexPassElement.hpp>
#include <hyprland/src/debug/log/Logger.hpp>

#include <cairo/cairo.h>
#include <hyprgraphics/image/Image.hpp>

namespace {
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
    // A reading the row does not agree on (a dialog at the top, a picture
    // scrolled under it) changes nothing: the bar keeps the colour it could
    // last tell, rather than the system's for as long as it lasts.
    if (const auto READ = AppColor::top(m_window.lock()))
        m_appColor = READ;
    listen();
}

// Every surface of the window, a subsurface the application draws in included
// (a browser draws the whole window in one): any of them committing may have
// changed the colour. Gathered again at each reading; a subsurface added
// since comes with a commit of its parent, which brings one about.
void CTitleBar::listen() {
    m_commits.clear();
    const auto W = m_window.lock();
    if (!W || !W->resource())
        return;
    W->resource()->breadthfirst([this](SP<CWLSurfaceResource> surface, const Vector2D&, void*) { m_commits.emplace_back(surface->m_events.commit.listen([this] { resample(); })); },
                                nullptr);
}

// Hyprland draws no decoration on a fullscreen window, the overlay layer
// included (renderWindow is told not to decorate it): its bar is painted from
// the render stage instead (paintOverFullscreen).
void CTitleBar::draw(Render::CRenderContext& ctx, PHLMONITOR monitor, float const& a, const Render::SWindowRenderPresentation& presentation) {
    const auto W = m_window.lock();
    if (W && Fullscreen::controller()->getFullscreenModes(W).internal != Fullscreen::FSMODE_FULLSCREEN)
        paint(ctx, monitor, a, presentation);
}

bool CTitleBar::overFullscreen(PHLMONITOR monitor) const {
    const auto W = m_window.lock();
    return validMapped(W) && Fullscreen::controller()->getFullscreenModes(W).internal == Fullscreen::FSMODE_FULLSCREEN && W->m_monitor == monitor &&
        W->m_workspace && W->m_workspace->visible() && (m_reveal->value() > 0 || m_reveal->goal() > 0);
}

void CTitleBar::paint(Render::CRenderContext& ctx, PHLMONITOR monitor, float a, const Render::SWindowRenderPresentation& presentation) {
    // A bar hidden from its application, or by the `decorate` rule, rolls in
    // or fades out as any other goes; only once it is away is it not drawn.
    const auto W    = m_window.lock();
    const bool AWAY = !above() && m_reveal->value() <= 0;
    if (!validMapped(W) || (!usable() && AWAY))
        return;
    const bool OPENING = W->presentation().animatingIn();
    // Read even while the bar is away, so that it comes out in its colour.
    sample(OPENING);

    // The application's colour, or the system's. A bar that is away takes it
    // at once rather than fading in from the last, and so does one whose
    // window is still opening: it comes in with the window, in the colour the
    // window settles on, rather than in the system's and then recoloured.
    const auto COLOR = m_appColor.value_or(Style::system());
    if (!(m_color->goal() == COLOR)) {
        if (AWAY || OPENING)
            m_color->setValueAndWarp(COLOR);
        else {
            m_color->setConfig(Style::fade());
            *m_color = COLOR;
        }
    }

    if (AWAY)
        return;

    // Above the window the bar is opaque, part of the window, and rolls out
    // of its top edge; over the window it fades.
    const float SCALE   = monitor->m_scale;
    const float ALPHA   = a * (above() ? 1.F : m_reveal->value());
    const auto  BAR     = barBox();
    const auto  ROUND   = W->presentation().rounding();
    const auto  toLocal = [&](CBox box) { return box.translate(-monitor->m_position + presentation.floatingOffset + presentation.workspaceOffset - W->presentation().renderPresentation().workspaceOffset).scale(SCALE).round(); };
    // What is on the bar, laid out on a whole one from its upper edge, and
    // cut to as much of it as is out.
    const auto CLIP = toLocal(BAR);

    // The window's rounding at the top. A shape taller than the bar by twice
    // the rounding has its lower corners well out of the way, and is cut down
    // to what is drawn: the bar and, under a bar above the window, the two
    // corners the window's own rounding would leave open. Rolled out less
    // than its rounding, its corners meet the window's own, so the bar and
    // the window are one rounded shape all the way.
    const auto SHAPE = toLocal({BAR.x, BAR.y, BAR.w, Style::height() + 2 * ROUND});
    std::vector<CBox> parts = {CLIP};
    if (above()) {
        parts.push_back(toLocal({BAR.x, BAR.y + BAR.h, ROUND, ROUND}));
        parts.push_back(toLocal({BAR.x + BAR.w - ROUND, BAR.y + BAR.h, ROUND, ROUND}));
    }
    for (const auto& clip : parts) {
        CRectPassElement::SRectData data;
        data.box           = SHAPE;
        data.clipBox       = clip;
        data.color         = withAlpha(m_color->value(), ALPHA);
        data.round         = std::round(ROUND * SCALE);
        data.roundingPower = W->presentation().roundingPower();
        g_pHyprRenderer->addPassElement(ctx, makeUnique<CRectPassElement>(data));
    }

    // Drawn in the ink of the colour the bar is going to, so the title turns
    // light or dark once rather than partway.
    const auto INK = Style::inkOn(COLOR);

    // Grey in a window without focus, as on macOS, until the pointer is on
    // them; their glyphs show only then.
    const float LIT = std::max(m_focus->value(), m_hover->value());
    for (int i = 0; i < Style::BUTTONS; ++i) {
        CRectPassElement::SRectData data;
        data.box     = toLocal(buttonBox(i));
        data.clipBox = CLIP;
        data.color   = withAlpha(mix(withAlpha(INK.text, 0.2F), INK.buttons[i], LIT), ALPHA);
        data.round   = std::round(Style::button() * SCALE / 2);
        g_pHyprRenderer->addPassElement(ctx, makeUnique<CRectPassElement>(data));
        if (m_hover->value() > 0)
            drawGlyph(ctx, i, data.box, CLIP, INK.glyph, ALPHA * m_hover->value());
    }

    // Centred on the window, and kept clear of the buttons on both sides.
    const int ROOM = std::floor((BAR.w - 2 * (Style::inset() + Style::BUTTONS * (Style::button() + Style::gap()))) * SCALE);
    if (W->metadata().title().empty() || ROOM <= 0)
        return;
    const auto FONT = Style::font();
    const auto KEY = std::format("{}\n{}\n{}\n{}\n{}\n{}\n{}", W->metadata().title(), SCALE, ROOM, key(INK.text), FONT.family, FONT.points, FONT.weight);
    if (!m_title || KEY != m_titleKey) {
        m_title    = g_pHyprRenderer->renderText(W->metadata().title(), INK.text, std::round(FONT.points * SCALE), false, FONT.family, ROOM, FONT.weight);
        m_titleKey = KEY;
    }
    const auto                   LOCAL = toLocal({BAR.x, BAR.y, BAR.w, Style::height()});
    CTexPassElement::SRenderData title;
    title.tex     = m_title;
    title.box     = CBox{LOCAL.middle() - m_title->m_size / 2, m_title->m_size}.round();
    title.clipBox = CLIP;
    title.a       = ALPHA * (0.5F + 0.5F * m_focus->value());
    g_pHyprRenderer->addPassElement(ctx, makeUnique<CTexPassElement>(std::move(title)));
}

/*
    A button's glyph, drawn into a texture of the button's own box (pixels) so
    it is centred on the button exactly: a character set in a face sits on its
    line's baseline, not in the middle of its box, and came out off centre.
    Close is a cross, minimize a bar, zoom a plus; layout shows what it does,
    two panes side by side on a floating window, which it tiles, and one on a
    tiled one, which it floats. These are the shell's Hugeicons Stroke Rounded paths,
    decoded by the compositor's own image loader and tinted in the button ink.
*/
void CTitleBar::drawGlyph(Render::CRenderContext& ctx, int button, const CBox& box, const CBox& clip, const CHyprColor& color, float alpha) {
    const auto W     = m_window.lock();
    const int  SHAPE = button == 3 && W && W->isFloating() ? 4 : button;
    const int  SIZE  = std::max(1, sc<int>(std::round(box.w)));
    const int  GLYPH = std::max(1, sc<int>(std::round(SIZE * Style::glyphScale())));
    auto [cached, inserted] = g_state->glyphs.try_emplace(std::format("{}:{}:{}:{}", SHAPE, SIZE, GLYPH, key(color)));
    auto& tex = cached->second;
    if (inserted) {
        const auto SVG = Hugeicons::windowGlyphs[SHAPE];
        Hyprgraphics::CImage image(std::span<const uint8_t>{reinterpret_cast<const uint8_t*>(SVG.data()), SVG.size()},
                                   Hyprgraphics::IMAGE_FORMAT_SVG, {GLYPH, GLYPH});
        const auto MASK = image.cairoSurface();
        if (!image.success() || !MASK || MASK->status() != CAIRO_STATUS_SUCCESS) {
            LOG(Log::ERR, "[windows] Could not draw Hugeicons glyph {}: {}", SHAPE, image.getError());
            return;
        }
        const auto SURFACE = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, SIZE, SIZE);
        const auto CR      = cairo_create(SURFACE);
        cairo_set_source_rgba(CR, color.r, color.g, color.b, color.a);
        const double INSET = (SIZE - GLYPH) / 2.0;
        cairo_mask_surface(CR, MASK->cairo(), INSET, INSET);
        const auto STATUS = cairo_status(CR);
        cairo_surface_flush(SURFACE);
        if (STATUS == CAIRO_STATUS_SUCCESS)
            tex = g_pHyprRenderer->createTexture(SURFACE);
        else
            LOG(Log::ERR, "[windows] Could not tint Hugeicons glyph {}: {}", SHAPE, cairo_status_to_string(STATUS));
        cairo_destroy(CR);
        cairo_surface_destroy(SURFACE);
    }
    if (!tex)
        return;
    CTexPassElement::SRenderData glyph;
    glyph.tex     = tex;
    glyph.box     = CBox{box.pos(), {sc<double>(SIZE), sc<double>(SIZE)}};
    glyph.clipBox = clip;
    glyph.a       = alpha;
    g_pHyprRenderer->addPassElement(ctx, makeUnique<CTexPassElement>(std::move(glyph)));
}
