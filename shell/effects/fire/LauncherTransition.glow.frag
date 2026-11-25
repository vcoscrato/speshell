#version 440
#extension GL_GOOGLE_include_directive : enable
// The warm light the flames on the panel's top edge throw up into the air over it:
// strongest at the edge, fading outward, brighter where the flames burn higher and
// flickering with them. It follows the outline round the top corners and dies away
// as they turn down into the sides. Nothing of it falls on the panel.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;    // px, this item's size
    vec4 panel;         // px, the panel's rect in this item
    float radius;       // px, its corners' radius
    float reach;        // px, how far the light reaches off the edge
    float time;
    float strength;     // 0..1
    vec4 cGlow;
} u;
#include "../common/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    vec2 h = u.panel.zw * 0.5;
    vec2 rel = p - u.panel.xy - h;
    float d = sdRoundRect(rel, h, u.radius);
    // How far the nearest outline faces up: 1 along the top, 0 down the sides.
    vec2 q = abs(rel) - h + u.radius;
    float facing = rel.y < 0.0 ? (q.x > 0.0 && q.y > 0.0 ? q.y / length(q) : step(q.x, q.y)) : 0.0;
    if (d <= 0.0 || facing <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    // Fading off round the corners, where the flames thin out.
    float along = smoothstep(-16.0, 40.0, h.x - abs(rel.x)) * smoothstep(0.0, 0.8, facing);
    float flicker = 0.65 + 0.35 * vnoise(vec2(p.x / 60.0, u.time * 1.3)) + 0.15 * vnoise(vec2(p.x / 23.0, u.time * 3.1));
    float reach = u.reach * (0.55 + 0.45 * flicker);
    float a = pow(max(0.0, 1.0 - d / reach), 2.4) * along * flicker * u.strength * 0.4;
    // Light added to what is behind it, mostly, so it warms rather than greys it.
    fragColor = vec4(u.cGlow.rgb * a, a * 0.35) * u.qt_Opacity;
}
