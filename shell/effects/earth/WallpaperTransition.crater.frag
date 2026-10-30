#version 440
#extension GL_GOOGLE_include_directive : enable
// The crater: a burst of dust at the point of impact, over everything else.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 rect;         // this item's rect on screen (px)
    vec2 center;       // px, the point of impact
    float time;        // s since the impact
    float reach;
    vec4 cDust;
    vec4 cDustShade;
} u;
#include "Shatter.glsl"

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    float kc = u.time / 0.9;
    vec2 pf = puff(p, u.center + vec2(0.0, -24.0 * kc), 20.0 + 70.0 * sqrt(kc), 0.37);
    float k = pf.x * 0.5 * pow(max(1.0 - kc, 0.0), 1.3);
    fragColor = vec4(mix(u.cDust.rgb, u.cDustShade.rgb, pf.y), 1.0) * k * u.qt_Opacity;
}
