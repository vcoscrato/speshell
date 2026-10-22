#version 440
#extension GL_GOOGLE_include_directive : enable
// Full-resolution cel shading of the flame simulation into flat bands.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
    vec4 cCore;
    vec4 cMid;
    vec4 cOuter;
    vec4 cEdge;
} u;
layout(binding = 1) uniform sampler2D state;
#include "../../lib/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    vec4 s = texture(state, qt_TexCoord0);
    // Fine erosion adds edge detail the low-res sim cannot hold, mostly where flames are thin.
    float detail = fbm(vec2(p.x / 22.0, p.y / 30.0 + u.time * 3.0)) - 0.5;
    float thin = 1.0 - smoothstep(0.15, 0.55, s.r);
    float f = s.r + detail * mix(0.04, 0.16, thin);
    // Inner bands by how far through its life the fuel is, so weak flames still have
    // a hot core at their base; the outline stays by the fuel itself.
    float life = 0.2 + (f - 0.2) * 0.8 / (clamp(s.b, 0.47, 1.0) - 0.2);
    float h = s.g + detail * 0.12;

    float a = band(f, 0.20);
    vec4 col = mix(u.cEdge, u.cOuter, band(f, 0.235));
    col = mix(col, u.cMid, band(h, 0.5) * band(life, 0.42));
    col = mix(col, u.cCore, band(h, 0.78) * band(life, 0.62));
    fragColor = vec4(col.rgb * a, a) * u.qt_Opacity;
}
