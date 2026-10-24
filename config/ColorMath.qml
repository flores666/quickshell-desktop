pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    Colour in OKLab (Björn Ottosson's, over sRGB), whose lightness is the
    eye's: a colour moved to another's lightness keeps its hue and, held to
    its share of what sRGB holds there, how colourful it looks. What the accent taken from the wallpaper is made with
    (Appearance.fromWallpaper), and what it is matched to libadwaita's
    accents by.
*/
Singleton {
    id: root

    /*! [L, a, b]. */
    function lab(value: color): var {
        const lin = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        const r = lin(value.r), g = lin(value.g), b = lin(value.b);
        const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
        const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
        const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
        return [
            0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        ];
    }

    /*! The sRGB colour of [L, a, b], or null where sRGB has none. */
    function rgb(lab: var): var {
        const [L, a, b] = lab;
        const l = Math.pow(L + 0.3963377774 * a + 0.2158037573 * b, 3);
        const m = Math.pow(L - 0.1055613458 * a - 0.0638541728 * b, 3);
        const s = Math.pow(L - 0.0894841775 * a - 1.2914855480 * b, 3);
        const linear = [
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076956890 * s
        ];
        if (linear.some(v => v < -1e-4 || v > 1 + 1e-4))
            return null;
        const encode = v => v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055;
        const [r, g, bl] = linear.map(v => encode(Math.max(0, Math.min(1, v))));
        return Qt.rgba(r, g, bl, 1);
    }

    /*!
        `seed` at `like`'s lightness: its hue, and as large a share of the
        most chroma sRGB holds at that lightness and hue as the seed has of
        what sRGB holds at its own — its saturation, so that a deep blue
        lifted stays a clear blue rather than greying — raised as little as
        `enough` (a colour → bool) asks, if any chroma will do. A seed with
        no hue at all takes `like`'s.
    */
    function tone(seed: color, like: color, enough: var): color {
        const lightness = root.lab(like)[0];
        const [sl, sa, sb] = root.lab(seed);
        const chroma = Math.hypot(sa, sb);
        const [, la, lb] = root.lab(like);
        const hue = chroma > 1e-4 ? Math.atan2(sb, sa) : Math.atan2(lb, la);
        const share = chroma > 1e-4 ? Math.min(1, chroma / root.most(sl, hue)) : 0;
        const at = c => root.rgb([lightness, c * Math.cos(hue), c * Math.sin(hue)]);
        const most = root.most(lightness, hue);
        let c = share * most;
        // The least that is enough, by halving.
        if (!enough(at(c)) && enough(at(most)))
            c = root.edge(c, most, x => !enough(at(x)))[1];
        return at(c);
    }

    /*! The most chroma sRGB holds at a lightness and hue (radians); none is
        grey, always in. */
    function most(lightness: real, hue: real): real {
        const inside = c => root.rgb([lightness, c * Math.cos(hue), c * Math.sin(hue)]) !== null;
        return inside(0.5) ? 0.5 : root.edge(0, 0.5, inside)[0];
    }

    /*! Where `inside` stops holding, between `low`, where it holds, and
        `high`, where it does not: [the last value found inside, the first
        outside], a hair apart. */
    function edge(low: real, high: real, inside: var): var {
        for (let i = 0; i < 30; ++i) {
            const mid = (low + high) / 2;
            if (inside(mid))
                low = mid;
            else
                high = mid;
        }
        return [low, high];
    }

    /*! The name in `named` (name → colour) whose colour is nearest to
        `value` in hue and chroma, lightness aside. */
    function nearest(value: color, named: var): string {
        const [, a, b] = root.lab(value);
        let best = "", distance = Infinity;
        for (const name in named) {
            const [, na, nb] = root.lab(named[name]);
            const d = Math.hypot(na - a, nb - b);
            if (d < distance) {
                distance = d;
                best = name;
            }
        }
        return best;
    }
}
