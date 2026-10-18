#version 440
#extension GL_GOOGLE_include_directive : enable
// Draws a captured item through a circular portal of radius `circle` around `origin`:
// inside it (or outside, with `outside` set) the item shows, bent near the edge
// like light around a lens, behind a white-hot ring with a warm glow and a faint
// violet haze.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 rect;          // this item's rect on screen (px)
    vec2 origin;
    float circle;       // portal radius (px)
    float outside;      // 1: show the item outside the circle instead of inside
    float lens;         // px the edge bends the item by
    float ringWidth;    // ring scale
    float ring;         // 0..1 ring brightness
    vec4 cHot;
    vec4 cGlow;
    vec4 cHaze;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../../lib/common.glsl"

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec2 rel = p - u.origin;
    float d = length(rel);
    vec2 dir = rel / max(d, 1.0);
    // A faint wobble keeps the edge from reading as a ruled circle.
    float edge = u.circle + (vnoise(dir * 5.0 + u.circle / 40.0) - 0.5) * 3.0 * u.ringWidth;
    float s = u.outside > 0.5 ? d - edge : edge - d;     // > 0 shown

    // Near the edge, sample from closer to it, so the item stretches along the rim.
    float bend = u.lens * exp(-max(s, 0.0) / max(u.lens * 2.5, 1.0));
    vec2 sp = p + dir * bend * (u.outside > 0.5 ? -1.0 : 1.0);
    vec4 content = texture(source, clamp((sp - u.rect.xy) / u.rect.zw, 0.0, 1.0));
    float shape = texture(source, qt_TexCoord0).a;

    float w = u.ringWidth;
    float hot = 1.0 - smoothstep(0.6 * w, 2.4 * w, abs(s));
    float glow = exp(-abs(s) / (8.0 * w));
    float haze = exp(-max(-s, 0.0) / (26.0 * w)) * (1.0 - smoothstep(0.0, 3.0 * w, s));
    vec4 rim = vec4(u.cHaze.rgb, 1.0) * haze * 0.35;
    rim = vec4(u.cGlow.rgb, 1.0) * glow * 0.9 + rim * (1.0 - glow * 0.9);
    rim = vec4(u.cHot.rgb, 1.0) * hot + rim * (1.0 - hot);
    rim *= u.ring * shape;

    vec4 shown = content * cover(s);
    fragColor = (rim + shown * (1.0 - rim.a)) * u.qt_Opacity;
}
