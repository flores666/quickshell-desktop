#pragma once

#define WLR_USE_UNSTABLE

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/render/decorations/IHyprWindowDecoration.hpp>
#include <hyprland/src/render/Texture.hpp>
#include <hyprland/src/helpers/AnimatedVariable.hpp>
#include <hyprland/src/helpers/signal/Signal.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopTimer.hpp>

#include <chrono>
#include <optional>
#include <unordered_map>
#include <vector>

/*
    A macOS-style title bar: close, minimize, zoom and floating-or-tiled on the
    left, the title centred, in the application's own colour (AppColor) and the
    system's buttons (Style). Given to every window but one whose client draws
    its own frame (ServerSide.cpp).

    Floating, the bar sits above the window in space it reserves, as part of
    the window. Tiled or fullscreen, it reserves nothing — the window keeps
    its whole tile, or the screen — and is drawn over the window's top once
    the pointer has rested at that top edge (Pointer.cpp), so one only
    passing by on its way to the top of the screen brings nothing out. Every
    change to it — shown, lit under the pointer, focused, recoloured — is
    eased on the shell's timings.
*/
class CTitleBar : public IHyprWindowDecoration {
  public:
    // macOS's proportions, in logical pixels.
    static constexpr double HEIGHT = 28, BUTTON = 12, GAP = 8, INSET = 12;
    // How far into a tiled or fullscreen window's top the pointer brings its
    // bar out: an edge, as macOS's menu bar over a full-screen window, since
    // under the rest of the bar are the application's own controls (a
    // browser's tabs).
    static constexpr double EDGE = 4;

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

    /*! Whether the bar can be there at all: the window is decorated. */
    bool usable() const;
    /*! Above a floating window, always out; over a tiled or fullscreen one,
        only brought out. */
    bool above() const;
    /*! On the bar's box, or the edge that brought it out; and at its
        window's top edge — the top EDGE px, or the gap above them — which is
        what brings a bar over its window out. */
    bool onBar(const Vector2D& pos) const;
    bool revealsAt(const Vector2D& pos) const;
    /*! The button at a point, -1 for none: close, minimize, zoom, layout. */
    int  buttonAt(const Vector2D& pos) const;
    /*! The window went floating or tiled, or in or out of fullscreen: the bar
        moves between above the window and over it. */
    void reposition();
    /*! Hyprland places a floating window by its own box, without what is
        drawn above it: one floated from a full-height tile had its bar off
        the top of the screen. Moved down, and shortened if it must be, until
        the bar is in the work area. Only where Hyprland places the window —
        one dragged there is left there. */
    void keepOnScreen();
    /*! Ease towards what the pointer and focus now say. */
    void animate();
    /*! Out, or coming out, over a fullscreen window on this monitor: painted
        from the render stage, with the monitor kept off its direct path. */
    bool overFullscreen(PHLMONITOR monitor) const;
    void paint(PHLMONITOR monitor, float alpha);
    /*! The surface committed since the colour was last read; read again on
        the next frame drawn, unless that was a moment ago. */
    void resample();
    /*! The moment is up: a read put off is drawn for now. */
    void retry();

  private:
    PHLWINDOWREF         m_window;
    // Where the positioner last put the bar: above the window, or over it.
    bool                 m_above = false;
    CBox                 m_assigned;

    // 0 to 1: drawn, buttons lit by the pointer, window focused.
    PHLANIMVAR<float>      m_reveal, m_hover, m_focus;
    PHLANIMVAR<CHyprColor> m_color;

    // The application's colour, read from its buffer (AppColor).
    std::optional<CHyprColor>             m_appColor;
    bool                                  m_sampleDue = true;
    std::chrono::steady_clock::time_point m_sampled;
    CHyprSignalListener                   m_commit;

    SP<Render::ITexture> m_title;
    std::string          m_titleKey;

    bool                 decorated() const;
    bool                 shown() const;
    CBox                 barBox() const;
    CBox                 edgeBox() const;
    CBox                 buttonBox(int button) const;
    void                 act(int button);
    void                 sample(bool opening);
    void                 drawGlyph(int button, const CBox& box, const CHyprColor& color, float alpha);
};

/*! What the pointer is doing to the bars. One pointer, so one of each. */
struct SState {
    // The bar the pointer is on, and whether on its buttons.
    PHLWINDOWREF hovered;
    bool         overButtons = false;
    // The tiled or fullscreen window whose bar is out, and the one whose top the
    // pointer is resting on until the dwell is up.
    PHLWINDOWREF revealed, waiting;
    Vector2D     pointer;
    // The button pressed on the hovered bar; it acts if released there.
    int          armed = -1;
    // A press on a bar's background: a move, once the pointer moves.
    PHLWINDOWREF dragging;
    PHLWINDOWREF active;
    std::vector<uint32_t> held;

    // The dwell, the linger, and the colour read put off by a moment.
    SP<CEventLoopTimer> dwell, linger, resample;

    // Every window given a bar, closed ones included: one that has closed can
    // still be held alive (a fade, the last frame's render pass) where no
    // list of Hyprland's reaches it, and its bar must not outlive the plugin.
    std::vector<PHLWINDOWREF> decorated;

    // App ids, from the windows:hidden_for dispatcher (see hiddenFor).
    std::vector<std::string> hiddenFor;
    std::unordered_map<std::string, SP<Render::ITexture>> glyphs;
    std::vector<CHyprSignalListener> listeners;

    void hover(PHLWINDOW window, bool overButtons);
    void reveal(PHLWINDOW window);
};

/*! The pointer's side of the bars (Pointer.cpp). */
namespace Pointer {
    void init();
    void exit();
    void move(const Vector2D& pos, Event::SCallbackInfo& info);
    void button(const IPointer::SButtonEvent& e);
    /*! Floating or tiled, fullscreen or not: the pointer is placed afresh by
        its next move, and the bar goes above the window or over it. Only a
        window floated is kept on screen: one leaving fullscreen is still on
        its way back to its own box, which would be pinned where it stood. */
    void modeChanged(PHLWINDOW window, bool floated);
}

inline HANDLE         PHANDLE = nullptr;
inline UP<SState>     g_state;
