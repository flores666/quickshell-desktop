import QtQuick
import "root:/config"
import "root:/components"

/*!
    The time-series chart: where a sample is placed (newest at the right edge,
    a point half a span old in the middle, a value's height), the auto scale,
    which points are drawn, the series colours in both themes, and the glyphs
    the task manager's tabs and cards use.
*/
Item {
    id: root

    Check {
        id: check
    }

    Chart {
        id: chart
        width: 200
        height: 100
        now: 100
        span: 60
        max: 100
        series: [{ color: "#ff0000", points: [{ t: 30, v: 10 }, { t: 40, v: 20 }, { t: 70, v: 50 }, { t: 100, v: 100 }] }]
    }

    Chart {
        id: auto
        width: 200
        height: 100
        now: 100
        max: 0
        series: [{ color: "#00ff00", points: [{ t: 10, v: 900 }, { t: 90, v: 4 }, { t: 100, v: 2 }] }]
    }

    Chart {
        id: quiet
        width: 200
        height: 100
        now: 100
        max: 0
        series: [{ color: "#00ff00", points: [{ t: 100, v: 0.2 }] }]
    }

    // A percentage's sparkline, as the date menu and the Performance tab
    // draw one: scaled to its data, a quarter above the highest point.
    StatCard {
        id: idle
        width: 200
        height: 120
        now: 100
        series: [{ color: "#0000ff", points: [{ t: 90, v: 3 }, { t: 100, v: 6 }] }]
    }

    StatCard {
        id: busy
        width: 200
        height: 120
        now: 100
        series: [{ color: "#0000ff", points: [{ t: 90, v: 40 }, { t: 100, v: 60 }] }]
    }

    Component.onCompleted: {
        check.attempt("place", () => {
            check.near("newest at the right edge", chart.place({ t: 100, v: 50 }, 100).x, 200);
            check.near("half a span old in the middle", chart.place({ t: 70, v: 50 }, 100).x, 100);
            check.near("max at the top", chart.place({ t: 100, v: 100 }, 100).y, 0);
            check.near("zero at the bottom", chart.place({ t: 100, v: 0 }, 100).y, 100);
            check.near("above max is clamped", chart.place({ t: 100, v: 500 }, 100).y, 0);
        });
        check.attempt("axes plot area", () => {
            chart.axes = true;
            const right = chart.place({ t: 100, v: 0 }, 100);
            check.near("axes: right edge is the chart's", right.x, 200);
            check.near("axes: left edge inside the labels", chart.place({ t: 40, v: 0 }, 100).x, Appearance.m.chartAxisWidth);
            check.near("axes: zero above the span labels", right.y, 100 - Appearance.m.chartAxisHeight);
            chart.axes = false;
        });
        check.attempt("auto max", () => {
            check.equal("auto: a quarter above the largest in the span", auto.effectiveMax, 5);
            check.equal("auto: at least `least`", quiet.effectiveMax, 1);
            check.equal("a stat card: scaled to its data", busy.chart.effectiveMax, 75);
            check.equal("a stat card: never under 10%", idle.chart.effectiveMax, 10);
            check.equal("fixed max", chart.effectiveMax, 100);
        });
        check.attempt("drawn", () => {
            check.equal("older than the span left out", chart.drawn(chart.series[0]).length, 3);
            check.equal("empty draws nothing", chart.drawn({ points: [] }).length, 0);
        });
        check.attempt("series tokens", () => {
            for (const k of ["seriesCpu", "seriesMemory", "seriesGpu", "seriesDisk", "seriesIn", "seriesOut"])
                check.equal(k + " differs by theme", String(Appearance.day[k]) !== String(Appearance.night[k]), true);
        });
        check.attempt("glyphs", () => {
            for (const k of ["performance", "disk", "network-transfer", "gpu", "download", "upload", "cpu", "ram", "grid"])
                check.equal("glyph " + k, Icons.has(k), true);
        });
        check.done();
    }
}
