# Hugeicons shell icons

[Hugeicons](https://github.com/hugeicons/hugeicons), **Stroke Rounded**, from
`@hugeicons/core-free-icons` version **4.4.0**, package git revision
`4fd1c2d5572f832eb908d401ca95a18013069abf`. The free package's artwork and source
are distributed under the included upstream MIT `LICENSE` (copyright Hugeicons).

Source archive:
`https://registry.npmjs.org/@hugeicons/core-free-icons/-/core-free-icons-4.4.0.tgz`

- SHA-256: `c69dae55981a6316bcfe90037dc54dab008367d032344930d1f021a3c691c3d1`
- Verified npm integrity: `sha512-7Mz8bmGoY6tZ6l3C2TXwNMLVSr0I8HPwjjFIERAuJFj3rWwLxdF2ZLkDqdrVuEE1dx5b/VXyIsP4WoSU6Q40KQ==`

The selected `dist/esm/<Name>Icon.js` data arrays are serialized here as
`<Name>.svg`: `key` is omitted, SVG attribute names replace their React camelCase
spellings, and the SVG root has `viewBox="0 0 24 24"` and `fill="none"`, matching
the official renderer. Geometry, element order, strokes, caps, joins and widths
are preserved. Missing caps/joins retain SVG's butt/miter defaults; do not replace
them with round globally. Most strokes are 1.5 units; gamepad button dots use 2.
Circles remain circles in the source artwork. No fonts or application theme are
needed to render these icons.

`map.json` preserves the shell's 143 semantic keys. The battery aliases use five
upstream levels (`BatteryEmpty`, `BatteryLow`, `BatteryMedium01`,
`BatteryMedium02`, `BatteryFull`), with separate charging and external-supply
symbols; the displayed battery percentage stays exact. Wi-Fi uses the matching
arc family, with fewer arcs for weaker reception. Native title-bar controls use
`Cancel01`, `MinusSign`, `Add01`, `Square`, and `Layout2Column`, in that order.

Run `python3 tools/genicons.py` after changing the map or sources. Generation
uses the vendored files and Python's standard library, with no network access.
`--check` verifies that the shell and title-bar outputs match these sources.
