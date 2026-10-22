#include "Style.hpp"

#include <hyprland/src/animation/AnimationManager.hpp>
#include <hyprland/src/config/shared/animation/AnimationTree.hpp>
#include <hyprland/src/config/values/types/ColorValue.hpp>
#include <hyprland/src/config/values/types/IntValue.hpp>
#include <hyprland/src/config/values/types/StringValue.hpp>

#include <cmath>
#include <sstream>

namespace {
    using Config::Values::CColorValue;
    using Config::Values::CIntValue;
    using Config::Values::CStringValue;

    struct SInkValues {
        SP<CColorValue>                             text, glyph;
        std::array<SP<CColorValue>, Style::BUTTONS> buttons;
    };

    SP<CColorValue>           g_bar;
    // On a light bar, on a dark one.
    std::array<SInkValues, 2> g_inks;
    SP<CIntValue>             g_hover, g_fade, g_dwell, g_linger;
    SP<CStringValue>          g_curve;
    SP<Style::Config>         g_hoverConfig, g_fadeConfig;
    std::string               g_curveAdded;

    constexpr const char*     CURVE = "windowsStandard";

    CHyprColor                color(const SP<CColorValue>& value) {
        return CHyprColor{sc<uint64_t>(value->value())};
    }

    // WCAG relative luminance, as Appearance.luminance.
    double luminance(const CHyprColor& c) {
        const auto F = [](double v) { return v <= 0.03928 ? v / 12.92 : std::pow((v + 0.055) / 1.055, 2.4); };
        return 0.2126 * F(c.r) + 0.7152 * F(c.g) + 0.0722 * F(c.b);
    }

    // "x1 y1 x2 y2", a cubic-bezier() as CSS writes it; added again whenever
    // it changes or a reload has dropped it.
    void addCurve() {
        const auto VALUE = g_curve->value();
        if (VALUE == g_curveAdded && Animation::mgr()->bezierExists(CURVE))
            return;
        std::istringstream in(VALUE);
        double             x1 = 0.45, y1 = 0, x2 = 0.55, y2 = 1;
        if (!(in >> x1 >> y1 >> x2 >> y2))
            x1 = 0.45, y1 = 0, x2 = 0.55, y2 = 1;
        Animation::mgr()->addBezierWithName(CURVE, Vector2D{x1, y1}, Vector2D{x2, y2});
        g_curveAdded = VALUE;
    }

    // On or off with Hyprland's own fades, and with all its animations — the
    // shell's Animations setting, which the animation manager warps through.
    SP<Style::Config> config(SP<Style::Config>& config, const SP<CIntValue>& ms) {
        addCurve();
        if (!config) {
            config             = makeShared<Style::Config>();
            config->overridden = true;
            config->pValues    = config;
        }
        const auto FADE           = ::Config::animationTree()->getAnimationPropertyConfig("fade");
        const auto VALUES         = FADE ? FADE->pValues.lock() : nullptr;
        config->internalBezier    = CURVE;
        config->internalEnabled   = VALUES ? VALUES->internalEnabled : 1;
        // In tenths of a second, as Hyprland counts animation speed.
        config->internalSpeed = std::max(0.1F, ms->value() / 100.F);
        return config;
    }
}

void Style::init(HANDLE handle) {
    const auto REDRAW = ::Config::Supplementary::REFRESH_WINDOW_STATES;
    const auto ADD    = [&](auto value) {
        HyprlandAPI::addConfigValueV2(handle, value);
        return value;
    };
    const auto COLOR = [&](const char* name, const char* description, uint64_t def) {
        return ADD(makeShared<CColorValue>(name, description, def, ::Config::Values::SColorValueOptions{.refresh = REDRAW}));
    };
    const auto MS = [&](const char* name, const char* description, int64_t def) {
        return ADD(makeShared<CIntValue>(name, description, def, ::Config::Values::SIntValueOptions{.min = 0}));
    };

    g_bar = COLOR("plugin:windows:bar_color", "The system's title bar, where the application's colour cannot be told", 0xFFFFFFFF);
    // Literals: an option keeps a pointer to its name. Text, glyph, then the
    // buttons in order.
    constexpr std::array<std::array<const char*, 2 + BUTTONS>, 2> NAMES = {{
        {"plugin:windows:light_text", "plugin:windows:light_glyph", "plugin:windows:light_close", "plugin:windows:light_minimize", "plugin:windows:light_zoom",
         "plugin:windows:light_layout"},
        {"plugin:windows:dark_text", "plugin:windows:dark_glyph", "plugin:windows:dark_close", "plugin:windows:dark_minimize", "plugin:windows:dark_zoom",
         "plugin:windows:dark_layout"},
    }};
    for (int ink = 0; ink < 2; ++ink) {
        g_inks[ink].text  = COLOR(NAMES[ink][0], "The title on a bar of this lightness", 0xFF808080);
        g_inks[ink].glyph = COLOR(NAMES[ink][1], "The glyphs on its buttons", 0xFF808080);
        for (int i = 0; i < BUTTONS; ++i)
            g_inks[ink].buttons[i] = COLOR(NAMES[ink][2 + i], "A button on a bar of this lightness", 0xFF808080);
    }
    g_hover  = MS("plugin:windows:hover_duration", "How long a pointer wash takes, in ms", 120);
    g_fade   = MS("plugin:windows:fade_duration", "How long a fade or a colour change takes, in ms", 180);
    g_dwell  = MS("plugin:windows:dwell", "How long the pointer rests where a tiled or fullscreen window's bar would be before it comes out, in ms", 225);
    g_linger = MS("plugin:windows:linger", "How long a tiled window's bar stays once the pointer is off it, in ms", 250);
    g_curve  = ADD(makeShared<CStringValue>("plugin:windows:curve", "The curve every animation is eased on: x1 y1 x2 y2", "0.45 0 0.55 1"));
}

void Style::reloaded() {
    g_curveAdded.clear();
    addCurve();
}

CHyprColor Style::system() {
    return color(g_bar);
}

Style::SInk Style::inkOn(const CHyprColor& bar) {
    // Where black and white text read equally well.
    const auto& INK = g_inks[luminance(bar) > 0.179 ? 0 : 1];
    SInk        ink{.text = color(INK.text), .glyph = color(INK.glyph), .buttons = {}};
    for (int i = 0; i < BUTTONS; ++i)
        ink.buttons[i] = color(INK.buttons[i]);
    return ink;
}

SP<Style::Config> Style::hover() {
    return config(g_hoverConfig, g_hover);
}

SP<Style::Config> Style::fade() {
    return config(g_fadeConfig, g_fade);
}

int Style::dwell() {
    return g_dwell->value();
}

int Style::linger() {
    return g_linger->value();
}
