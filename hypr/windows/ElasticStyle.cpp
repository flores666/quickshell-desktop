#include "ElasticState.hpp"

#include <hyprland/src/config/ConfigValue.hpp>
#include <hyprland/src/config/values/types/FloatValue.hpp>
#include <hyprland/src/config/values/types/ColorValue.hpp>
#include <hyprland/src/config/shared/animation/AnimationTree.hpp>
#include <hyprland/src/animation/AnimationManager.hpp>
#include <unordered_map>

namespace {
    std::unordered_map<std::string, SP<Config::Values::CFloatValue>> values;
    SP<Config::Values::CColorValue> g_indicator, g_shadow;
}

void ElasticDrag::Style::init(HANDLE handle) {
    // Native fallbacks only; CompositorTheme pushes config/WindowDrag.
    for (const auto& [name, fallback] : std::initializer_list<std::pair<const char*, double>>{
        {"scale", .93}, {"rotation", 2}, {"deformation", .025}, {"velocity", 1800},
        {"lift", 120}, {"settle", 180}, {"landing", 300}, {"edge_dwell", 350},
        {"workspace_slide", 350}, {"edge", 24}, {"indicator_width", 4}, {"indicator_height", 96},
        {"shadow_range", 56}, {"shadow_drop", 12}}) {
        // Config values retain their name; the map owns its stable storage.
        auto [it, _] = values.emplace(std::string{"plugin:windows:drag_"} + name, nullptr);
        it->second = makeShared<Config::Values::CFloatValue>(it->first.c_str(), "Elastic drag presentation", fallback);
        HyprlandAPI::addConfigValueV2(handle, it->second);
    }
    g_indicator = makeShared<Config::Values::CColorValue>("plugin:windows:drag_indicator", "Workspace edge cue", 0x5999AAFF);
    g_shadow = makeShared<Config::Values::CColorValue>("plugin:windows:drag_shadow", "Lifted window shadow", 0x38000000);
    HyprlandAPI::addConfigValueV2(handle, g_indicator);
    HyprlandAPI::addConfigValueV2(handle, g_shadow);
}

double ElasticDrag::Style::value(const char* name) { return values.at(std::string{"plugin:windows:drag_"} + name)->value(); }
CHyprColor ElasticDrag::Style::indicator() { return CHyprColor{sc<uint64_t>(g_indicator->value())}; }
CHyprColor ElasticDrag::Style::shadow() { return CHyprColor{sc<uint64_t>(g_shadow->value())}; }

bool ElasticDrag::Style::enabled() {
    static auto ENABLED = CConfigValue<Config::BOOL>("animations:enabled");
    const auto CONFIG = Config::animationTree()->getAnimationPropertyConfig("windowsMove")->pValues.lock();
    return *ENABLED && CONFIG && CONFIG->internalEnabled && value("lift") > 0 && value("landing") > 0;
}

SP<::Style::Config> ElasticDrag::Style::workspaceConfig() {
    auto config = makeShared<::Style::Config>();
    config->overridden = true;
    config->pValues = config;
    config->internalEnabled = true;
    config->internalSpeed = std::max(.1, value("workspace_slide") / 100);
    config->internalBezier = ::Style::fade()->internalBezier;
    return config;
}
