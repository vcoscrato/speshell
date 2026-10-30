#version 440
#extension GL_GOOGLE_include_directive : enable
// The warm light the flames on the panel's top edge throw up into the air over it:
// strongest at the edge, fading upward, brighter where the flames burn higher and
// flickering with them. Nothing of it falls on the panel.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;    // px, this item's size
    float edge;         // px from this item's top to the panel's top edge
    float inset;        // px from each side to where the panel starts
    float time;
    float strength;     // 0..1
    vec4 cGlow;
} u;
#include "../common/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    float up = u.edge - p.y;
    if (up < 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    // Along the edge, fading off past the panel's corners.
    float w = u.resolution.x - 2.0 * u.inset;
    float along = smoothstep(-24.0, 36.0, min(p.x - u.inset, u.inset + w - p.x));
    float flicker = 0.65 + 0.35 * vnoise(vec2(p.x / 60.0, u.time * 1.3)) + 0.15 * vnoise(vec2(p.x / 23.0, u.time * 3.1));
    float reach = u.edge * (0.55 + 0.45 * flicker);
    float a = pow(max(0.0, 1.0 - up / reach), 2.4) * along * flicker * u.strength * 0.4;
    // Light added to what is behind it, mostly, so it warms rather than greys it.
    fragColor = vec4(u.cGlow.rgb * a, a * 0.35) * u.qt_Opacity;
}
