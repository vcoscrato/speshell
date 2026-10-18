#version 440
#extension GL_GOOGLE_include_directive : enable
// Fire's button face: the accent warming toward the foot, where a row of flame tongues
// stands in cel bands, outer to core. Hovered, the tongues rise and flicker and embers
// drift up through the face.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;
    float glow;
    float press;
    vec2 at;
    float time;
    vec4 cBase;
    vec4 cMid;
    vec4 cOuter;
    vec4 cCore;
    vec4 cShade;
} u;
#include "../../lib/common.glsl"

// How far inside flame `k` (of a row `width` apart) p is, px; `scale` shrinks it to an
// inner layer. Each leans and narrows to a curved tip.
float tongue(vec2 p, float up, float k, float width, float h, float flicker, float scale) {
    float tall = h * (0.15 + 0.12 * u.glow) * (0.6 + 0.8 * vnoise(vec2(k * 1.7, flicker * 0.8))) * scale;
    float t = up / max(tall, 1.0);
    float lean = ((hash(vec2(k, 3.0)) - 0.5) * 0.7 + 0.25 * sin(flicker * 1.3 + k * 2.1) * u.glow) * width;
    float center = (k + 0.5 + 0.3 * (hash(vec2(k, 1.0)) - 0.5)) * width + lean * t * t;
    float spread = width * 0.62 * scale * pow(clamp(1.0 - t, 0.0, 1.0), 0.75);
    return min(spread - abs(p.x - center), (1.0 - t) * tall);
}

void main() {
    vec2 p = qt_TexCoord0 * u.area;
    float h = u.area.y;
    float up = h - p.y;
    vec3 col = u.cBase.rgb;

    // Heat rising from the foot, in two soft bands.
    col = mix(col, mix(u.cBase.rgb, u.cMid.rgb, 0.5), band(h * 0.5 - up, 0.0) * 0.35);

    // The tongues: curved flames side by side, each layer nested in the last, taller
    // and livelier while hovered.
    float flicker = u.time * 3.0;
    float width = h * 0.42;
    float outer = -1e3, mid = -1e3, core = -1e3;
    float k0 = floor(p.x / width);
    for (int j = -1; j <= 1; j++) {
        float k = floor(p.x / width) + float(j);
        outer = max(outer, tongue(p, up, k, width, h, flicker, 1.0));
        mid = max(mid, tongue(p, up, k, width, h, flicker, 0.7));
        core = max(core, tongue(p, up, k, width, h, flicker, 0.42));
    }
    // The bed they rise from.
    float bed = h * 0.07 - up + 1.2 * sin(p.x / 5.0 + k0);
    outer = max(outer, bed);
    mid = max(mid, bed - h * 0.03);
    col = mix(col, u.cOuter.rgb, cover(outer) * 0.9);
    col = mix(col, mix(u.cOuter.rgb, u.cMid.rgb, 0.55), cover(mid));
    col = mix(col, u.cCore.rgb, cover(core) * 0.85);

    // Embers drifting up, each in its own column.
    float lane = h * 0.28;
    float i = floor(p.x / lane);
    float rise = fract(u.time * (0.5 + 0.4 * hash(vec2(i, 3.0))) + hash(vec2(i, 7.0)));
    vec2 ember = vec2((i + 0.3 + 0.4 * hash(vec2(i, 1.0))) * lane + sin(rise * 6.0 + i) * 2.0, h * (1.0 - rise * 1.1));
    float alive = step(0.45, hash(vec2(i, 5.0))) * (1.0 - rise) * u.glow;
    col = mix(col, u.cCore.rgb, cover(0.9 - length(p - ember)) * alive);

    col = mix(col, u.cShade.rgb, 0.12 * u.press);
    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
