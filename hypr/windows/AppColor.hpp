#pragma once

#include <hyprland/src/desktop/DesktopTypes.hpp>
#include <hyprland/src/helpers/Color.hpp>

#include <optional>

/*
    The colour an application draws along the top of its window, which its
    title bar takes so the two read as one: a terminal's background, a
    toolbar, a header bar.

    Read from what the window shows, a row just inside its top edge, across
    the middle four fifths of its width: every surface of it, subsurfaces
    included, each over those below. Only a colour most of that row agrees on
    counts; a picture, a gradient, anything translucent or a dialog near the
    top cannot be told, and the answer is none (the bar keeps what it had).

    It reads the GPU, so it is called while a frame is drawn, when the context
    is current and the buffer the frame will show is ready, and no more often
    than the bar asks.
*/
namespace AppColor {
    std::optional<CHyprColor> top(PHLWINDOW window);
}
