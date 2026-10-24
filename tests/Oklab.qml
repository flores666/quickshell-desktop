import QtQuick

/*!
    The tests' own OKLab (Björn Ottosson's, from sRGB), to judge the shell's
    colours by rather than with the shell's own maths: a colour's lightness
    `l`, chroma `c` and hue `h` in degrees.
*/
QtObject {
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

    /*! How far apart two hues are, either way round. */
    function hueApart(a: real, b: real): real {
        const d = Math.abs(a - b) % 360;
        return Math.min(d, 360 - d);
    }
}
