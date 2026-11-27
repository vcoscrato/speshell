#version 440
#extension GL_GOOGLE_include_directive : enable
// A comet around its head at this item's middle: a bright head in a soft glow; a dust
// tail along the spine of grains it shed over the last second, so it leans away from
// the panel's light and bends back along its path, widening and fading smoothly from
// the head, with faint streaks and a few specks streaming down it; and a thin ion
// tail straight away from the light. Hidden where it passes behind what shows of the
// panel.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 rect;          // this item's rect on screen (px)
    vec4 panel;         // the panel's rect on screen (px)
    float radius;       // panel corner radius
    vec2 away;          // unit direction from the panel's middle through the head
    vec4 tail01;        // the dust tail's spine after the head, relative to it (px),
    vec4 tail23;        // two points to a vector, youngest grains first
    vec4 tail45;
    vec4 tail67;
    float size;         // head radius (px)
    float k;            // 0..1 brightness
    float time;         // s, for the streaks and specks flowing down the tail
    vec4 cHead;
    vec4 cDust;
    vec4 cIon;
} u;
#include "../common/common.glsl"

vec2 spine(int i) {
    if (i == 1) return u.tail01.xy;
    if (i == 2) return u.tail01.zw;
    if (i == 3) return u.tail23.xy;
    if (i == 4) return u.tail23.zw;
    if (i == 5) return u.tail45.xy;
    if (i == 6) return u.tail45.zw;
    if (i == 7) return u.tail67.xy;
    if (i == 8) return u.tail67.zw;
    return vec2(0.0);
}

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec2 o = p - (u.rect.xy + u.rect.zw * 0.5);

    // The nearest point of the spine: how far, on which side, and how far down it.
    float dist = 1e9, side = 1.0, at = 0.0, run = 0.0;
    vec2 a = vec2(0.0);
    for (int i = 1; i <= 8; i++) {
        vec2 b = spine(i);
        vec2 ab = b - a;
        float l = max(length(ab), 1e-3);
        float h = clamp(dot(o - a, ab) / (l * l), 0.0, 1.0);
        vec2 r = o - a - ab * h;
        float d = length(r);
        if (d < dist) {
            dist = d;
            at = run + h * l;
            side = ab.x * r.y - ab.y * r.x < 0.0 ? -1.0 : 1.0;
        }
        run += l;
        a = b;
    }
    float t = at / max(run, 1.0);
    vec4 acc = vec4(0.0);

    // The ion tail: thin, faint, and straight away from the light, knotted by gusts
    // running out along it.
    float along = dot(o, u.away);
    float across = dot(o, vec2(-u.away.y, u.away.x));
    float ti = clamp(along / (1.25 * length(spine(8)) + 1.0), 0.0, 1.0);
    float wi = u.size * 0.35 + max(along, 0.0) * 0.022;
    float ion = exp(-across * across / (wi * wi)) * smoothstep(0.0, u.size * 3.0, along)
              * (1.0 - ti) * (1.0 - ti) * (0.55 + 0.45 * vnoise(vec2(along / 16.0 - u.time * 3.0, 3.0)));
    acc = over(acc, u.cIon.rgb, 0.12 * ion);

    // The dust tail: widening from the head, brightest by it, gone by its end, with
    // streaks along it drifting outward.
    float w = u.size * 1.4 + at * 0.17;
    float body = exp(-2.4 * dist * dist / (w * w));
    float fall = pow(1.0 - t, 1.3) * (0.45 + 0.55 * exp(-5.0 * t));
    float streak = 0.65 + 0.35 * vnoise(vec2(side * dist / w * 2.6 + 5.0, at / 55.0 - u.time * 0.7));
    vec3 dustCol = mix(u.cDust.rgb, u.cHead.rgb, 0.5 * exp(-6.0 * t));
    acc = over(acc, dustCol, 0.75 * body * fall * streak);

    // Specks of it, a few to the tail, streaming out and twinkling.
    float flow = at - u.time * 20.0;
    float cell = floor(flow / 12.0);
    vec3 hs = vec3(hash(vec2(cell, 3.1)), hash(vec2(cell, 7.7)), hash(vec2(cell, 12.9)));
    float sAt = (cell + 0.25 + 0.5 * hs.x) * 12.0 + u.time * 20.0;
    float sd = length(vec2(at - sAt, side * dist - (hs.y - 0.5) * 1.5 * w));
    float speck = step(hs.z, 0.5) * cover(mix(0.6, 1.1, hs.y) - sd) * (1.0 - t)
                * (0.55 + 0.45 * sin(u.time * 7.0 + hs.x * 40.0));
    acc = over(acc, u.cDust.rgb, 0.85 * speck * step(1.0, at));

    // The head: a small bright core in a soft glow, inside a faint coma.
    float d = length(o);
    acc = over(acc, mix(u.cDust.rgb, u.cHead.rgb, 0.4), 0.2 * exp(-d / (u.size * 4.5)));
    acc = over(acc, mix(u.cDust.rgb, u.cHead.rgb, 0.6), 0.55 * exp(-d / (u.size * 1.6)));
    acc = over(acc, u.cHead.rgb, 1.0 - smoothstep(u.size * 0.55, u.size * 1.15, d));

    float sp = sdRoundRect(p - u.panel.xy - u.panel.zw * 0.5, u.panel.zw * 0.5, u.radius);
    fragColor = acc * smoothstep(0.0, 1.5, sp) * u.k * u.qt_Opacity;
}
