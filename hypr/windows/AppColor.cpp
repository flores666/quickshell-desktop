#include "AppColor.hpp"

#define WLR_USE_UNSTABLE

#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <hyprland/src/protocols/XDGShell.hpp>
#include <hyprland/src/render/Texture.hpp>

#include <hyprgraphics/egl/Egl.hpp>

#include <GLES3/gl32.h>

#include <unordered_map>
#include <vector>

namespace {
    // How far below the top edge the row is, in logical pixels: clear of a
    // highlight a frame draws along its very edge.
    constexpr double ROW = 2;
    // The share of the row that has to agree.
    constexpr double AGREEMENT = 0.75;

    /*!
        A row of the texture as it stores it. A shared-memory buffer is stored
        in whatever order its format puts the channels, and Hyprland swizzles
        them back as it samples, which a read does not; a dmabuf is imported as
        the colour it is.
    */
    std::optional<std::vector<uint8_t>> readRow(const SP<Render::ITexture>& tex, int x, int y, int width) {
        GLint previousRead = 0, previousPack = 0;
        glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &previousRead);
        glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING, &previousPack);
        // Hyprland's own errors are not ours to report.
        for (int i = 0; i < 8 && glGetError() != GL_NO_ERROR; ++i) {}

        GLuint fb = 0;
        glGenFramebuffers(1, &fb);
        glBindFramebuffer(GL_READ_FRAMEBUFFER, fb);
        glFramebufferTexture2D(GL_READ_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex->m_texID, 0);

        std::vector<uint8_t> row(sc<size_t>(width) * 4);
        bool                 read = glCheckFramebufferStatus(GL_READ_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
        if (read) {
            glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
            glReadPixels(x, y, width, 1, GL_RGBA, GL_UNSIGNED_BYTE, row.data());
            read = glGetError() == GL_NO_ERROR;
            glBindBuffer(GL_PIXEL_PACK_BUFFER, previousPack);
        }

        glBindFramebuffer(GL_READ_FRAMEBUFFER, previousRead);
        glDeleteFramebuffers(1, &fb);
        if (!read)
            return std::nullopt;
        return row;
    }

    // What sampling the stored channels gives: GL's swizzle, applied by hand.
    std::array<double, 4> swizzled(const uint8_t* px, const std::optional<std::array<GLint, 4>>& swizzle, bool opaque) {
        std::array<double, 4> stored = {px[0] / 255.0, px[1] / 255.0, px[2] / 255.0, px[3] / 255.0}, out = stored;
        if (swizzle) {
            for (int i = 0; i < 4; ++i) {
                switch ((*swizzle)[i]) {
                    case GL_RED: out[i] = stored[0]; break;
                    case GL_GREEN: out[i] = stored[1]; break;
                    case GL_BLUE: out[i] = stored[2]; break;
                    case GL_ALPHA: out[i] = stored[3]; break;
                    case GL_ZERO: out[i] = 0; break;
                    default: out[i] = 1; break;
                }
            }
        }
        if (opaque)
            out[3] = 1;
        return out;
    }
}

namespace {
    using Shown = std::vector<std::optional<std::array<double, 3>>>;

    /*!
        One surface's opaque pixels along the row, laid over what is there:
        `shown` holds a sample a logical pixel from `x0`, at height `y`, both
        in the window's main surface's coordinates; `offset` is where this
        surface is within it.
    */
    void lay(const SP<CWLSurfaceResource>& surface, const Vector2D& offset, double x0, double y, Shown& shown) {
        const auto& STATE = surface->m_current;
        const auto  TEX   = STATE.texture;
        // An external (YUV) image cannot be attached to read from, and a
        // turned buffer is rare enough to leave out.
        if (!surface->m_mapped || !TEX || !TEX->ok() || TEX->m_texID == 0 || TEX->m_type == Render::TEXTURE_EXTERNAL || STATE.transform != WL_OUTPUT_TRANSFORM_NORMAL ||
            STATE.size.x <= 0 || STATE.size.y <= 0)
            return;
        const double LY = y - offset.y;
        if (LY < 0 || LY >= STATE.size.y)
            return;

        // The samples that fall on it, each at its pixel's centre.
        const double SHIFT = x0 + 0.5 - offset.x;
        const int    FIRST = std::max(0, sc<int>(std::ceil(-SHIFT)));
        const int    LAST  = std::min(sc<int>(shown.size()), sc<int>(std::ceil(STATE.size.x - SHIFT)));
        if (LAST <= FIRST)
            return;

        // Surface-local to buffer pixels, through the viewport's crop if any.
        const double SCALE  = std::max(1, STATE.scale);
        const CBox   SOURCE = STATE.viewport.hasSource ? STATE.viewport.source : CBox{{}, STATE.bufferSize / SCALE};
        const auto   PIXEL  = [&](double lx) { return (SOURCE.pos() + Vector2D{lx, LY} * (SOURCE.size() / STATE.size)) * SCALE; };

        const int    BY  = std::floor(PIXEL(0).y);
        const int    BX0 = std::max(0, sc<int>(std::floor(PIXEL(FIRST + SHIFT).x)));
        const int    BX1 = std::min(sc<int>(TEX->m_size.x), sc<int>(std::floor(PIXEL(LAST - 1 + SHIFT).x)) + 1);
        if (BY < 0 || BY >= TEX->m_size.y || BX1 <= BX0)
            return;
        const auto ROW = readRow(TEX, BX0, BY, BX1 - BX0);
        if (!ROW)
            return;

        const auto FORMAT  = TEX->isDMA() ? nullptr : Hyprgraphics::Egl::getPixelFormatFromDRM(TEX->m_drmFormat);
        const auto SWIZZLE = FORMAT ? FORMAT->swizzle : std::nullopt;
        const bool OPAQUE  = TEX->m_type == Render::TEXTURE_RGBX || TEX->m_opaque;
        for (int i = FIRST; i < LAST; ++i) {
            const int BX = sc<int>(std::floor(PIXEL(i + SHIFT).x)) - BX0;
            if (BX < 0 || BX >= BX1 - BX0)
                continue;
            // Anything translucent leaves what is under it.
            const auto C = swizzled(&(*ROW)[sc<size_t>(BX) * 4], SWIZZLE, OPAQUE);
            if (C[3] >= 0.98)
                shown[i] = std::array<double, 3>{C[0], C[1], C[2]};
        }
    }
}

std::optional<CHyprColor> AppColor::top(PHLWINDOW window) {
    const auto ROOT = window->resource();
    if (!ROOT || ROOT->m_current.size.x <= 0 || ROOT->m_current.size.y <= 0)
        return std::nullopt;

    // The window's own box within its surface: a frame the client draws
    // itself has its shadow outside it.
    CBox box = {{}, ROOT->m_current.size};
    if (window->m_xdgSurface && !window->m_xdgSurface->m_current.geometry.empty())
        box = window->m_xdgSurface->m_current.geometry;

    // What the window shows along the row: each of its surfaces in the order
    // Hyprland draws them, the main one and its subsurfaces, the opaque
    // pixels of each over those below. A browser draws the whole window in a
    // subsurface, over a main surface that holds nothing.
    Shown shown(sc<size_t>(std::max(0.0, std::floor(box.w * 0.8))));
    if (shown.size() < 8)
        return std::nullopt;
    const double X0 = box.x + box.w * 0.1, Y = box.y + ROW;
    ROOT->breadthfirst([&](SP<CWLSurfaceResource> surface, const Vector2D& offset, void*) { lay(surface, offset, X0, Y, shown); }, nullptr);

    // Near colours counted together, a few levels apart per channel, and the
    // winning group's average taken; a sample nothing opaque covers counts
    // for none.
    std::unordered_map<uint32_t, std::pair<int, std::array<double, 3>>> groups;
    for (const auto& C : shown) {
        if (!C)
            continue;
        const auto KEY = (sc<uint32_t>((*C)[0] * 255) >> 3) << 10 | (sc<uint32_t>((*C)[1] * 255) >> 3) << 5 | (sc<uint32_t>((*C)[2] * 255) >> 3);
        auto& [count, sum] = groups[KEY];
        ++count;
        for (int c = 0; c < 3; ++c)
            sum[c] += (*C)[c];
    }

    const auto BEST = std::ranges::max_element(groups, {}, [](const auto& g) { return g.second.first; });
    if (BEST == groups.end() || BEST->second.first < shown.size() * AGREEMENT)
        return std::nullopt;
    const auto& [COUNT, SUM] = BEST->second;
    return CHyprColor{sc<float>(SUM[0] / COUNT), sc<float>(SUM[1] / COUNT), sc<float>(SUM[2] / COUNT), 1.F};
}
