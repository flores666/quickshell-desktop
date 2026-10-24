#pragma once

#define WLR_USE_UNSTABLE

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/helpers/Color.hpp>
#include <hyprutils/animation/AnimationConfig.hpp>

#include <array>

/*
    How the title bars look and move, all of it pushed by the shell from the
    design system (modules/common/CompositorTheme.qml), so that nothing here
    picks a colour or a timing of its own.

    A bar takes its application's colour where one can be told (AppColor), and
    the system's otherwise. What is drawn on it comes from the scheme of the
    same lightness: the day theme's on a light bar, the night theme's on a dark
    one — text, and the four buttons in the system's danger, warning, success
    and accent. Its animations are the shell's: the hover wash's time, the
    fade's, and the curve both are eased on; and the popups' door, which a bar
    above its window rolls out of and into its top edge on.
*/
namespace Style {
    // Close, minimize, zoom, and floating or tiled.
    inline constexpr int BUTTONS = 4;

    struct SInk {
        CHyprColor                      text, glyph;
        std::array<CHyprColor, BUTTONS> buttons;
    };

    using Config = Hyprutils::Animation::SAnimationPropertyConfig;

    /*! Register the options, before the first config reload. */
    void        init(HANDLE handle);
    /*! The config reloaded: Hyprland dropped the curve with every other one. */
    void        reloaded();

    /*! The system's bar, for an application whose colour cannot be told. */
    CHyprColor  system();
    /*! What is drawn on a bar of this colour. */
    SInk        inkOn(const CHyprColor& bar);

    /*! A pointer wash coming and going: the buttons lighting under it. */
    SP<Config>  hover();
    /*! A fade or a colour change: a bar shown, focus, a new colour. */
    SP<Config>  fade();
    /*! A bar rolling out of its window's top edge as the window floats, and
        back into it as the window tiles: a popup's door's timings and
        curves (components/Door.qml). */
    SP<Config>  rollOut();
    SP<Config>  rollIn();
    /*! How long the pointer rests at a tiled or fullscreen window's top edge
        before its bar comes out, and how long that bar stays once the
        pointer is off it. */
    int         dwell();
    int         linger();
}
