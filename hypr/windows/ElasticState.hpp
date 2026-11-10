#pragma once

#include "ElasticDrag.hpp"
#include "ElasticMath.hpp"
#include <hyprland/src/render/transformer/Transformer.hpp>
#include <hyprland/src/helpers/time/Time.hpp>

namespace ElasticDrag {
    namespace Style {
        void init(HANDLE handle);
        double value(const char* name);
        CHyprColor indicator();
        CHyprColor shadow();
        bool enabled();
        SP<::Style::Config> workspaceConfig();
    }

    struct Session {
        PHLWINDOWREF window;
        PHLMONITORREF monitor;
        CBox initial, displayed, released, lastDamage;
        Vector2D grab, cursor, lastCursor, velocity;
        Time::steady_tp started, lastMotion, dropped;
        bool held = true, external = false, alive = true;
        double dropLift = 1;
        Vector2D dropVelocity;

        CBox box(Time::steady_tp now) const;
        double lift(Time::steady_tp now) const;
        ElasticMath::Pose pose(Time::steady_tp now) const;
        void motion(Vector2D point);
    };

    extern SP<Session> session;
    void attach(const SP<Session>& state);
    void clear();
    void release(const CBox& target);
    void damage();
    void edgeInit();
    void edgeExit();
    void edgeMotion();
    void edgeClear();
    void edgePaint(Render::CRenderContext& ctx, PHLMONITOR monitor);
}
