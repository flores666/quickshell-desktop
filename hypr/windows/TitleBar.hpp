#pragma once

#define WLR_USE_UNSTABLE

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/render/decorations/IHyprWindowDecoration.hpp>
#include <hyprland/src/render/Texture.hpp>
#include <hyprland/src/config/values/types/ColorValue.hpp>
#include <hyprland/src/helpers/signal/Signal.hpp>

#include <array>
#include <unordered_map>
#include <vector>

/*
    A macOS-style title bar: close, minimize and zoom on the left, the title
    centred. Given to every window but one whose client draws its own frame
    (ServerSide.cpp).

    Floating, the bar sits above the window in space it reserves, as part of
    the window. Tiled, it reserves nothing — the window keeps its whole tile —
    and is drawn over the window's top only while the pointer is there. In
    fullscreen there is none: Hyprland draws no decoration on a fullscreen
    window.
*/
class CTitleBar : public IHyprWindowDecoration {
  public:
    // macOS's, in logical pixels.
    static constexpr double HEIGHT = 28;

    explicit CTitleBar(PHLWINDOW window);

    /*! Whether a window gets a bar: whether its client left the frame to the
        compositor, or could not say. Decided once, as it maps. */
    static bool                wanted(PHLWINDOW window);
    /*! Whether the user took the bar from the window's application. */
    static bool                hiddenFor(PHLWINDOW window);

    SDecorationPositioningInfo getPositioningInfo() override;
    void                       onPositioningReply(const SDecorationPositioningReply& reply) override;
    void                       draw(PHLMONITOR monitor, float const& a) override;
    eDecorationType            getDecorationType() override;
    void                       updateWindow(PHLWINDOW window) override;
    void                       damageEntire() override;
    bool                       onInputOnDeco(const eInputType type, const Vector2D& pos, std::any data) override;
    eDecorationLayer           getDecorationLayer() override;
    uint64_t                   getDecorationFlags() override;
    std::string                getDisplayName() override;

    static CTitleBar*          of(PHLWINDOW window);

    /*! Where the pointer is on this bar: a tiled window's hidden bar answers
        only on the window's upper edge, and keeps the whole bar once shown. */
    bool hoverableAt(const Vector2D& pos, bool hovered) const;
    /*! The button at a point, -1 for none: 0 close, 1 minimize, 2 zoom. */
    int  buttonAt(const Vector2D& pos) const;
    /*! The window went floating or tiled: the bar moves between above the
        window and over it. */
    void reposition();
    /*! Hyprland places a floating window by its own box, without what is
        drawn above it: one floated from a full-height tile had its bar off
        the top of the screen. Moved down, and shortened if it must be, until
        the bar is in the work area. Only where Hyprland places the window —
        one dragged there is left there. */
    void keepOnScreen();

  private:
    PHLWINDOWREF         m_window;
    // Where the positioner last put the bar: above the window, or over it.
    bool                 m_above = false;
    CBox                 m_assigned;

    SP<Render::ITexture> m_title;
    std::string          m_titleKey;

    bool                 decorated() const;
    bool                 shown() const;
    CBox                 barBox() const;
    CBox                 buttonBox(int button) const;
    void                 act(int button);
};

/*! What the pointer is doing to the bars. One pointer, so one of each. */
struct SState {
    PHLWINDOWREF hovered;
    bool         overButtons = false;
    // The button pressed on the hovered bar; it acts if released there.
    int          armed = -1;
    // A press on a bar's background: a move, once the pointer moves.
    PHLWINDOWREF dragging;
    PHLWINDOWREF active;
    std::vector<uint32_t> held;

    // Every window given a bar, closed ones included: one that has closed can
    // still be held alive (a fade, the last frame's render pass) where no
    // list of Hyprland's reaches it, and its bar must not outlive the plugin.
    std::vector<PHLWINDOWREF> decorated;

    SP<Config::Values::CColorValue> barColor, textColor;
    // App ids, from the windows:hidden_for dispatcher (see hiddenFor).
    std::vector<std::string> hiddenFor;
    std::unordered_map<float, std::array<SP<Render::ITexture>, 3>> glyphs;
    std::vector<CHyprSignalListener> listeners;

    void hover(PHLWINDOW window, bool overButtons);
};

inline HANDLE         PHANDLE = nullptr;
inline UP<SState>     g_state;
