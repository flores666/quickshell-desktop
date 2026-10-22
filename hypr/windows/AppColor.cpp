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

std::optional<CHyprColor> AppColor::top(PHLWINDOW window) {
    const auto SURFACE = window->resource();
    if (!SURFACE)
        return std::nullopt;
    const auto& STATE = SURFACE->m_current;
    const auto  TEX   = STATE.texture;
    // An external (YUV) image cannot be attached to read from, and a turned
    // buffer is rare enough to leave to the system's colour.
    if (!TEX || !TEX->ok() || TEX->m_texID == 0 || TEX->m_type == Render::TEXTURE_EXTERNAL || STATE.transform != WL_OUTPUT_TRANSFORM_NORMAL || STATE.size.x <= 0 ||
        STATE.size.y <= 0)
        return std::nullopt;

    // The window's own box within its surface: a frame the client draws
    // itself has its shadow outside it.
    CBox box = {{}, STATE.size};
    if (window->m_xdgSurface && !window->m_xdgSurface->m_current.geometry.empty())
        box = window->m_xdgSurface->m_current.geometry;

    // Surface-local to buffer pixels, through the viewport's crop if any.
    const double SCALE  = std::max(1, STATE.scale);
    const CBox   SOURCE = STATE.viewport.hasSource ? STATE.viewport.source : CBox{{}, STATE.bufferSize / SCALE};
    const auto   PIXEL  = [&](const Vector2D& local) { return (SOURCE.pos() + local * (SOURCE.size() / STATE.size)) * SCALE; };

    const auto   FROM = PIXEL({box.x + box.w * 0.1, box.y + ROW});
    const auto   TO   = PIXEL({box.x + box.w * 0.9, box.y + ROW});
    const int    Y = std::floor(FROM.y), X = std::max(0.0, std::floor(FROM.x));
    const int    WIDTH = std::min(std::floor(TO.x), TEX->m_size.x) - X;
    if (Y < 0 || Y >= TEX->m_size.y || WIDTH < 8)
        return std::nullopt;

    const auto ROWDATA = readRow(TEX, X, Y, WIDTH);
    if (!ROWDATA)
        return std::nullopt;

    const auto FORMAT  = TEX->isDMA() ? nullptr : Hyprgraphics::Egl::getPixelFormatFromDRM(TEX->m_drmFormat);
    const auto SWIZZLE = FORMAT ? FORMAT->swizzle : std::nullopt;
    const bool OPAQUE  = TEX->m_type == Render::TEXTURE_RGBX || TEX->m_opaque;

    // Near colours counted together, a few levels apart per channel, and the
    // winning group's average taken; anything translucent counts for none.
    std::unordered_map<uint32_t, std::pair<int, std::array<double, 3>>> groups;
    for (int i = 0; i < WIDTH; ++i) {
        const auto C = swizzled(&(*ROWDATA)[i * 4], SWIZZLE, OPAQUE);
        if (C[3] < 0.98)
            continue;
        const auto KEY = (sc<uint32_t>(C[0] * 255) >> 3) << 10 | (sc<uint32_t>(C[1] * 255) >> 3) << 5 | (sc<uint32_t>(C[2] * 255) >> 3);
        auto& [count, sum] = groups[KEY];
        ++count;
        for (int c = 0; c < 3; ++c)
            sum[c] += C[c];
    }

    const auto BEST = std::ranges::max_element(groups, {}, [](const auto& g) { return g.second.first; });
    if (BEST == groups.end() || BEST->second.first < WIDTH * AGREEMENT)
        return std::nullopt;
    const auto& [COUNT, SUM] = BEST->second;
    return CHyprColor{sc<float>(SUM[0] / COUNT), sc<float>(SUM[1] / COUNT), sc<float>(SUM[2] / COUNT), 1.F};
}
