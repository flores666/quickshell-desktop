#include "Style.hpp"

#include <hyprland/src/animation/AnimationManager.hpp>
#include <hyprland/src/config/shared/animation/AnimationTree.hpp>
#include <hyprland/src/config/ConfigValue.hpp>
#include <hyprland/src/config/values/types/ColorValue.hpp>
#include <hyprland/src/config/values/types/IntValue.hpp>
#include <hyprland/src/config/values/types/FloatValue.hpp>
#include <hyprland/src/config/values/types/StringValue.hpp>

#include <cmath>
#include <sstream>

namespace {
    using Config::Values::CColorValue;
    using Config::Values::CIntValue;
    using Config::Values::CFloatValue;
    using Config::Values::CStringValue;

    struct SInkValues {
        SP<CColorValue>                             text, glyph;
        std::array<SP<CColorValue>, Style::BUTTONS> buttons;
    };

    SP<CColorValue>           g_bar;
    // On a light bar, on a dark one.
    std::array<SInkValues, 2> g_inks;
    SP<CIntValue>             g_hover, g_fade, g_rollOut, g_rollIn, g_dwell, g_linger;
    SP<CIntValue>             g_minimize, g_exposure, g_move, g_close;
    SP<CIntValue>             g_height, g_button, g_gap, g_inset, g_edge, g_fontPoints, g_fontWeight;
    SP<CFloatValue>           g_widthCap, g_heightCap;
    SP<CStringValue>          g_fontFamily;
    SP<Style::Config>         g_hoverConfig, g_fadeConfig, g_rollOutConfig, g_rollInConfig, g_minimizeConfig;

    // A curve the shell pushes, registered with Hyprland's animation manager
    // by name.
    struct SCurve {
        const char*      name;
        SP<CStringValue> value;
        std::string      added = {};
    };
    // Fades and colour; a title bar rolling out.
    SCurve                    g_standard{"windowsStandard"}, g_emphasized{"windowsEmphasized"}, g_motion{"windowsMotion"};

    CHyprColor                color(const SP<CColorValue>& value) {
        return CHyprColor{sc<uint64_t>(value->value())};
    }

    // WCAG relative luminance, as Appearance.luminance.
    double luminance(const CHyprColor& c) {
        const auto F = [](double v) { return v <= 0.03928 ? v / 12.92 : std::pow((v + 0.055) / 1.055, 2.4); };
        return 0.2126 * F(c.r) + 0.7152 * F(c.g) + 0.0722 * F(c.b);
    }

    // "x1 y1 x2 y2", a cubic-bezier() as CSS writes it; added again whenever
    // it changes or a reload has dropped it. One that does not read is linear.
    void addCurve(SCurve& curve) {
        const auto VALUE = curve.value->value();
        if (VALUE == curve.added && Animation::mgr()->bezierExists(curve.name))
            return;
        std::istringstream in(VALUE);
        double             x1 = 0, y1 = 0, x2 = 1, y2 = 1;
        if (!(in >> x1 >> y1 >> x2 >> y2))
            x1 = 0, y1 = 0, x2 = 1, y2 = 1;
        Animation::mgr()->addBezierWithName(curve.name, Vector2D{x1, y1}, Vector2D{x2, y2});
        curve.added = VALUE;
    }

    // On or off with Hyprland's own fades, and with all its animations — the
    // shell's Animations setting, which the animation manager warps through.
    SP<Style::Config> config(SP<Style::Config>& config, const SP<CIntValue>& ms, SCurve& curve, const char* leaf = "fade") {
        addCurve(curve);
        if (!config) {
            config             = makeShared<Style::Config>();
            config->overridden = true;
            config->pValues    = config;
        }
        const auto FADE           = ::Config::animationTree()->getAnimationPropertyConfig(leaf);
        const auto VALUES         = FADE ? FADE->pValues.lock() : nullptr;
        config->internalBezier    = curve.name;
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
    const auto SIZE = [&](const char* name, const char* description, int64_t def) {
        return ADD(makeShared<CIntValue>(name, description, def, ::Config::Values::SIntValueOptions{.min = 1}));
    };
    const auto CAP = [&](const char* name, const char* description, float def) {
        return ADD(makeShared<CFloatValue>(name, description, def, ::Config::Values::SFloatValueOptions{.min = 0.01F, .max = 1.F}));
    };

    // Fallbacks for a compositor started before the shell pushes its tokens.
    g_height = SIZE("plugin:windows:height", "Title-bar height in logical pixels", 28);
    g_button = SIZE("plugin:windows:button_size", "Title-bar button diameter", 12);
    g_gap = MS("plugin:windows:button_gap", "Gap between title-bar buttons", 8);
    g_inset = MS("plugin:windows:button_inset", "Title-bar button inset", 12);
    g_edge = MS("plugin:windows:reveal_edge", "Top edge that reveals an overlaid bar", 4);
    g_fontPoints = SIZE("plugin:windows:font_size", "Title font size in points", 10);
    g_fontWeight = SIZE("plugin:windows:font_weight", "Title font weight", 600);
    g_fontFamily = ADD(makeShared<CStringValue>("plugin:windows:font_family", "Title fontconfig family", "sans-serif"));
    g_widthCap = CAP("plugin:windows:width_cap", "Initial floating width as a share of the work area", 0.7F);
    g_heightCap = CAP("plugin:windows:height_cap", "Initial floating height as a share of the work area", 0.8F);
    g_minimize = MS("plugin:windows:minimize_duration", "Genie minimize/restore duration in ms", 373);
    g_exposure = MS("plugin:windows:minimize_exposure", "Genie motion blur exposure in ms", 22);
    g_move = MS("plugin:windows:move_duration", "Window geometry transition duration in ms", 479);
    g_close = MS("plugin:windows:close_duration", "Window close duration in ms", 180);
    g_motion.value = ADD(makeShared<CStringValue>("plugin:windows:move_curve", "Window geometry curve: x1 y1 x2 y2", "0.25 0.1 0.25 1"));

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
    g_hover   = MS("plugin:windows:hover_duration", "How long a pointer wash takes, in ms", 120);
    g_fade    = MS("plugin:windows:fade_duration", "How long a fade or a colour change takes, in ms", 180);
    g_rollOut = MS("plugin:windows:roll_out_duration", "How long a title bar takes to roll out of its window's top edge, in ms", 200);
    g_rollIn  = MS("plugin:windows:roll_in_duration", "How long a title bar takes to roll back into its window's top edge, in ms", 138);
    g_dwell   = MS("plugin:windows:dwell", "How long the pointer rests at a tiled or fullscreen window's top edge before its bar comes out, in ms", 225);
    g_linger  = MS("plugin:windows:linger", "How long a tiled window's bar stays once the pointer is off it, in ms", 250);
    g_standard.value =
        ADD(makeShared<CStringValue>("plugin:windows:curve", "The curve fades, colour changes and a bar rolling in are eased on: x1 y1 x2 y2", "0.45 0 0.55 1"));
    g_emphasized.value = ADD(makeShared<CStringValue>("plugin:windows:roll_curve", "The curve a bar rolls out on: x1 y1 x2 y2", "0.33 1 0.68 1"));
}

void Style::reloaded() {
    for (auto* curve : {&g_standard, &g_emphasized, &g_motion}) {
        curve->added.clear();
        addCurve(*curve);
    }
    restyle();
}

void Style::restyle() {
    addCurve(g_motion);
    addCurve(g_standard);
    const auto SET = [](const char* name, const SP<CIntValue>& ms, const char* curve, const std::string& style = "") {
        const auto VALUES = ::Config::animationTree()->getAnimationPropertyConfig(name)->pValues.lock();
        ::Config::animationTree()->setConfigForNode(name, (!VALUES || VALUES->internalEnabled) && ms->value() > 0,
            std::max(0.1F, ms->value() / 100.F), curve, style);
    };
    SET("windowsMove", g_move, g_motion.name);
    // Windows without a dock target keep their final box and fade. A 100%
    // popin is Hyprland's native no-geometry-change presentation.
    SET("windowsIn", g_fade, g_standard.name, "popin 100%");
    SET("fadeIn", g_fade, g_standard.name);
    SET("windowsOut", g_close, g_standard.name, "popin 100%");
    SET("fadeOut", g_close, g_standard.name);
}

SP<Style::Config> Style::minimize() {
    return config(g_minimizeConfig, g_minimize, g_standard, "windowsMove");
}

int Style::minimizeExposure() { return g_exposure->value(); }

bool Style::motionEnabled() {
    static auto ENABLED = CConfigValue<::Config::INTEGER>("animations:enabled");
    return *ENABLED && g_minimize->value() > 0 && minimize()->internalEnabled;
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
    return config(g_hoverConfig, g_hover, g_standard);
}

SP<Style::Config> Style::fade() {
    return config(g_fadeConfig, g_fade, g_standard);
}

SP<Style::Config> Style::rollOut() {
    return config(g_rollOutConfig, g_rollOut, g_emphasized);
}

SP<Style::Config> Style::rollIn() {
    return config(g_rollInConfig, g_rollIn, g_standard);
}

int Style::dwell() {
    return g_dwell->value();
}

int Style::linger() {
    return g_linger->value();
}

double Style::height() { return g_height->value(); }
double Style::button() { return g_button->value(); }
double Style::gap() { return g_gap->value(); }
double Style::inset() { return g_inset->value(); }
double Style::edge() { return g_edge->value(); }
Vector2D Style::sizeCap() { return {g_widthCap->value(), g_heightCap->value()}; }
Style::SFont Style::font() { return {g_fontFamily->value(), sc<int>(g_fontPoints->value()), sc<int>(g_fontWeight->value())}; }
