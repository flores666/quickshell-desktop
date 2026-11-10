#pragma once

#include <algorithm>
#include <cmath>
#include <numbers>

// No integration step or unbounded spring: independent of frame/input rate.
namespace ElasticMath {
    inline double smooth(double t) {
        t = std::clamp(t, 0.0, 1.0);
        return t * t * (3 - 2 * t);
    }

    // An ease-out back with a single small overshoot; no oscillating tail.
    inline double landing(double t) {
        const double x = std::clamp(t, 0.0, 1.0) - 1;
        return 1 + 1.6 * x * x * x + 0.6 * x * x;
    }

    struct Point { double x = 0, y = 0; };
    struct Pose {
        Point grab, cursor;
        double scaleX = 1, scaleY = 1, angle = 0;

        Point map(Point p) const {
            const double x = (p.x - grab.x) * scaleX;
            const double y = (p.y - grab.y) * scaleY;
            return {cursor.x + x * std::cos(angle) - y * std::sin(angle),
                    cursor.y + x * std::sin(angle) + y * std::cos(angle)};
        }
    };

    inline double decay(double elapsedMs, double settleMs) {
        if (elapsedMs >= settleMs || settleMs <= 0) return 0;
        return 1 - smooth(elapsedMs / settleMs);
    }
}
