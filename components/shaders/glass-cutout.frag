#version 440

// Rebuild from the repository root:
// /usr/lib/qt6/bin/qsb --glsl '100 es,120,150' -o components/shaders/glass-cutout.frag.qsb components/shaders/glass-cutout.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform Uniforms {
    mat4 qt_Matrix;
    float qt_Opacity;
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D cutoutMask;

void main()
{
    vec4 cutout = texture(cutoutMask, qt_TexCoord0);
    // The paint, including the popup fade, attenuates the glass during source-over.
    float paintOpacity = cutout.r * qt_Opacity;
    float glassWeight = (1.0 - cutout.a) / max(1.0 - paintOpacity, 0.0001);
    fragColor = texture(source, qt_TexCoord0) * (glassWeight * qt_Opacity);
}
