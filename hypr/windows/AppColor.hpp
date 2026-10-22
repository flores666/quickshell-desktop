#pragma once

#include <hyprland/src/desktop/DesktopTypes.hpp>
#include <hyprland/src/helpers/Color.hpp>

#include <optional>

/*
    The colour an application draws along the top of its window, which its
    title bar takes so the two read as one: a terminal's background, a
    toolbar, a header bar.

    Read from the window's own buffer, a row just inside its top edge, across
    the middle four fifths of its width. Only a colour most of that row agrees
    on counts: one drawn over by a picture, a gradient or anything translucent
    cannot be told, and the bar keeps the system's colour.

    It reads the GPU, so it is called while a frame is drawn, when the context
    is current and the buffer the frame will show is ready, and no more often
    than the bar asks.
*/
namespace AppColor {
    std::optional<CHyprColor> top(PHLWINDOW window);
}
