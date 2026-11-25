#version 440
#extension GL_GOOGLE_include_directive : enable
// Full-resolution cel shading of the flame simulation into flat bands, the deeper
// row of rim flames in duller ones behind.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 offset;
    vec2 resolution;
    vec4 cCore;
    vec4 cMid;
    vec4 cOuter;
    vec4 cEdge;
    vec4 cBack;
    vec4 cBackHot;
} u;
layout(binding = 1) uniform sampler2D state;
#include "../common/common.glsl"

void main() {
    vec2 p = u.offset + qt_TexCoord0 * u.resolution;
    vec4 s = texture(state, qt_TexCoord0);
    // Fine erosion adds edge detail the low-res sim cannot hold, mostly where flames are thin.
    // It adds at most 0.06, so where there is too little fuel to show it is skipped.
    float detail = 0.0;
    if (max(s.r, s.a) > 0.1)
        detail = fbm(vec2(p.x / 22.0, p.y / 30.0 + u.time * 3.0)) - 0.5;
    float thin = 1.0 - smoothstep(0.15, 0.55, s.r);
    // Fuel that has lost its heat draws in, so a cooling flame shrinks away rather
    // than lingering as a flat patch.
    float cold = 1.0 - smoothstep(0.0, 0.25, s.g);
    float fuel = s.r - 0.2 * cold;
    float f = fuel + detail * mix(0.04, 0.16, thin);
    // Inner bands by how far through its life the fuel is, so weak flames still have
    // a hot core at their base; the outline stays by the fuel itself. The erosion
    // stays off them: inside a narrow tongue its blobs would stack into beads.
    float life = 0.2 + (fuel - 0.2) * 0.8 / (clamp(s.b, 0.47, 1.0) - 0.2);
    float h = s.g;

    float a = band(f, 0.20);
    vec4 col = mix(u.cEdge, u.cOuter, band(f, 0.235));
    col = mix(col, u.cMid, band(h, 0.5) * band(life, 0.42));
    col = mix(col, u.cCore, band(h, 0.78) * band(life, 0.62));

    float fb = s.a + detail * mix(0.06, 0.2, 1.0 - smoothstep(0.15, 0.55, s.a));
    float ab = band(fb, 0.20);
    vec4 back = vec4(mix(u.cBack.rgb, u.cBackHot.rgb, band(fb, 0.5)), 1.0) * ab;
    fragColor = over(back, col.rgb, a) * u.qt_Opacity;
}
