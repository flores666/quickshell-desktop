import QtQuick

/*!
    The tests' own OKLab (Björn Ottosson's, from sRGB), to judge the shell's
    colours by rather than with the shell's own maths: a colour's lightness
    `l`, chroma `c` and hue `h` in degrees, and its saturation.
*/
QtObject {
    id: root

    function lch(value: color): var {
        const lin = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        const r = lin(value.r), g = lin(value.g), b = lin(value.b);
        const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
        const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
        const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
        const A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
        const B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
        return {
            l: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            c: Math.hypot(A, B),
            h: (Math.atan2(B, A) * 180 / Math.PI + 360) % 360
        };
    }

    /*! How much of the most chroma sRGB holds at its lightness and hue a
        colour has, 0 to 1. */
    function saturation(value: color): real {
        const { l, c, h } = root.lch(value);
        const a = Math.cos(h * Math.PI / 180), b = Math.sin(h * Math.PI / 180);
        // In sRGB, a channel at most a hair outside 0 to 1.
        const fits = chroma => {
            const L = l + 0.3963377774 * a * chroma + 0.2158037573 * b * chroma;
            const M = l - 0.1055613458 * a * chroma - 0.0638541728 * b * chroma;
            const S = l - 0.0894841775 * a * chroma - 1.2914855480 * b * chroma;
            const [x, y, z] = [L * L * L, M * M * M, S * S * S];
            return [4.0767416621 * x - 3.3077115913 * y + 0.2309699292 * z,
                -1.2684380046 * x + 2.6097574011 * y - 0.3413193965 * z,
                -0.0041960863 * x - 0.7034186147 * y + 1.7076956890 * z]
                .every(v => v >= -1e-4 && v <= 1 + 1e-4);
        };
        let low = 0, high = 0.5;
        for (let i = 0; i < 40; ++i) {
            const mid = (low + high) / 2;
            if (fits(mid))
                low = mid;
            else
                high = mid;
        }
        return low > 0 ? c / low : 0;
    }

    /*! How far apart two hues are, either way round. */
    function hueApart(a: real, b: real): real {
        const d = Math.abs(a - b) % 360;
        return Math.min(d, 360 - d);
    }
}
