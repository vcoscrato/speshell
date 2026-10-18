#version 440
#extension GL_GOOGLE_include_directive : enable
// Fire backdrop, drawn once over a surface's base color: heat banked along
// the bottom edge rises in pointed flame tongues of three cel-shaded steps, embers drift up off it,
// and the top darkens as if under smoke. It stays a few percent off the base so text
// reads.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 cBase;
    vec4 cDeep;
    vec4 cAccent;
    vec4 cEmber;
    vec4 cFlame;
} u;
#include "../../lib/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.size;
    float h = u.size.y - p.y;                     // px above the bottom edge

    // Smoke: the top half settles toward the deepest color, in drifting wisps.
    float smoke = clamp(1.0 - p.y / (u.size.y * 0.5), 0.0, 1.0);
    smoke *= 0.75 + 0.5 * fbm(p / vec2(130.0, 45.0));
    vec3 col = mix(u.cBase.rgb, u.cDeep.rgb, smoke * smoke * 0.55);

    // Heat: pointed tongues licking up from the bottom, a few tall and many short,
    // bent sideways as they rise. Each column's flame reaches `reach` px; the field is
    // the share of that reach still above this pixel, > 0 inside the fire. The glow
    // adds light, so the panel's own hue stays warm under it.
    float bend = (fbm(vec2(p.x / 90.0, h / 120.0) + 11.0) - 0.5) * 70.0 * (h / 200.0);
    float x = (p.x + bend) / 52.0;
    float crest = 1.0 - abs(2.0 * vnoise(vec2(x, 1.3)) - 1.0);
    float small = 1.0 - abs(2.0 * vnoise(vec2(x * 2.7, 7.0)) - 1.0);
    float tall = pow(vnoise(vec2(p.x / 110.0, 4.0)), 2.0);
    float reach = u.size.y * (0.05 + 0.10 * small * small + 0.26 * crest * crest * crest * (0.4 + tall));
    float lick = (fbm(vec2(p.x / 26.0, h / 50.0) + 5.0) - 0.5) * 0.3;
    float heat = 1.0 - h / reach + lick;
    col += u.cFlame.rgb * 0.07 * band(heat, 0.0);
    col += u.cEmber.rgb * 0.06 * band(heat, 0.4);
    col += u.cAccent.rgb * 0.07 * band(heat, 0.75);

    // Embers: one candidate per cell, thinning out fast above the fire, each a short
    // streak leaning with the draft.
    vec2 cell = floor(p / 17.0);
    float rise = clamp(h / (u.size.y * 0.6), 0.0, 1.0);
    if (hash(cell + 3.1) < 0.12 * pow(1.0 - rise, 3.0)) {
        vec2 hc = hash2(cell);
        vec2 e = (cell + 0.2 + 0.6 * hc) * 17.0;
        vec2 v = p - e;
        v.x -= (hash(cell + 9.0) - 0.5) * 0.6 * v.y;
        float r = 0.55 + 0.7 * hash(cell + 4.2);
        float streak = length(v / vec2(r, r * (1.5 + 2.0 * hc.y)));
        float s = 1.0 - smoothstep(0.6, 1.3, streak);
        float glow = exp(-dot(v, v) / (r * r * 14.0));
        vec3 ember = mix(u.cEmber.rgb, u.cAccent.rgb, hc.x);
        col = mix(col, ember, clamp(s * 0.7 + glow * 0.16, 0.0, 0.75) * (1.0 - 0.6 * rise));
    }

    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
