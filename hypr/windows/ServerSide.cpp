#include "TitleBar.hpp"

#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/protocols/XDGDecoration.hpp>
#include <hyprland/src/protocols/XDGShell.hpp>
#include <hyprland/src/xwayland/XSurface.hpp>
#include <hyprland/src/xwayland/XWayland.hpp>

#include <algorithm>

namespace {
    using CDecorations = std::unordered_map<wl_resource*, UP<CXDGDecoration>>;

    // The protocol keeps its decoration objects private and has no accessor.
    // An explicit instantiation may name a private member ([temp.spec.general]),
    // which reads the map without redefining `private`.
    CDecorations CXDGDecorationProtocol::* decorationsMember();
    template <CDecorations CXDGDecorationProtocol::* MEMBER>
    struct SDecorationsAccess {
        friend CDecorations CXDGDecorationProtocol::* decorationsMember() {
            return MEMBER;
        }
    };
    template struct SDecorationsAccess<&CXDGDecorationProtocol::m_decorations>;
}

/*
    Every window but one whose client said it draws its own frame. Hyprland
    answers every xdg-decoration request with server-side mode, so what tells
    is the request: client-side mode (Chromium and Electron windows that draw
    their own controls) gets none. A client that asks for server-side mode gets
    one, and so does one that makes no decoration object at all — GTK never
    does, and its header bars carry no window buttons here (button-layout ':',
    profile/gtk.dconf). The protocol has the object made before the window's
    first commit, so it is there by the time the window maps.

    An X11 window cannot say: Hyprland does not read _MOTIF_WM_HINTS, and
    reading it here would be a round trip to Xwayland from the compositor's
    thread. Every application window gets one — those that draw their own
    frame too are the user's to take it from (hiddenFor) — but nothing that is
    not a window to the user: a menu, a tooltip, a splash screen.
*/
bool CTitleBar::wanted(PHLWINDOW window) {
    if (window->m_isX11) {
        const auto SURFACE = window->m_xwaylandSurface.lock();
        if (!SURFACE || window->isX11OverrideRedirect() || window->m_X11DoesntWantBorders)
            return false;
        const auto& TYPES = SURFACE->m_atoms;
        return TYPES.empty() || std::ranges::contains(TYPES, HYPRATOMS["_NET_WM_WINDOW_TYPE_NORMAL"]) ||
            std::ranges::contains(TYPES, HYPRATOMS["_NET_WM_WINDOW_TYPE_DIALOG"]);
    }
    if (!window->m_xdgSurface)
        return false;
    const auto TOPLEVEL = window->m_xdgSurface->m_toplevel.lock();
    if (!TOPLEVEL)
        return false;
    if (!PROTO::xdgDecoration)
        return true;
    // Keyed by the toplevel's resource, which only the toplevel's protocol
    // object maps back from.
    for (const auto& [RESOURCE, DECORATION] : (*PROTO::xdgDecoration).*decorationsMember())
        if (CXDGToplevelResource::fromResource(RESOURCE) == TOPLEVEL)
            return DECORATION->mostRecentlyRequested != ZXDG_TOPLEVEL_DECORATION_V1_MODE_CLIENT_SIDE;
    return true;
}

/*
    The applications the user took the bar from in the dock's menu, by app id,
    handed over by the shell (services/TitleBars.qml) through the
    windows:hidden_for dispatcher. A window keeps its bar hidden rather than
    losing it, so the choice can be undone while it is open.
*/
bool CTitleBar::hiddenFor(PHLWINDOW window) {
    return std::ranges::contains(g_state->hiddenFor, window->m_class);
}
