#version 440
#extension GL_GOOGLE_include_directive : enable
// Relâmpago's knob: a cartoon racing wheel, outlined in rubber, that rolls as it
// travels: a fat tire with a shine on its sidewall, a gold rim with four spokes round
// a red hub, which blur into a ring as it speeds along, trailing speed dashes. Behind
// it, along the filled track back to the track's start, the bolt it carries: a stepped
// decal, outlined, pointed at its tail. Held or hovered, a charge runs along the decal
// into the wheel and zaps flick out round the tire. Switched off, the wheel goes dull
// and the decal is gone. The item reaches back to the track's start and around the wheel.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    vec2 center;        // px, the wheel's center in the item
    float size;         // the knob's diameter, px
    float back;         // px from the wheel's center back to the track's start
    float turn;         // radians it has rolled
    float speed;        // -1..1 how fast it moves, + to the right
    float glow;         // 0..1 held or hovered
    float dim;          // 0..1 switched off
    float time;
    vec4 cTire;
    vec4 cWall;
    vec4 cPaint;
    vec4 cGold;
    vec4 cCore;
    vec4 cEdge;
} u;
#include "../common/common.glsl"

const float TAU = 6.2831853;

// x of the step that starts run k of the decal, px from the track's start.
float runStart(float k, float P) {
    return (k + 0.35 * (hash(vec2(k, 3.0)) - 0.5)) * P;
}

// Signed distance to the decal: runs whose centerline slants down by 2A across each,
// jumping back up by less than the stripe's width between them, so its edges step.
// th is its half width. Returns (the distance, q's height over the nearest run's
// centerline).
vec2 decal(vec2 q, float P, float A, float th) {
    float i = floor(q.x / P);
    vec2 d = vec2(1e3, 0.0);
    for (int j = -1; j <= 1; j++) {
        float k = i + float(j);
        float x0 = runStart(k, P), x1 = runStart(k + 1.0, P);
        float f = (q.x - x0) / (x1 - x0);
        float slope = 2.0 * A / (x1 - x0);
        float y = q.y - A * (2.0 * f - 1.0);
        float dk = max((abs(y) - th) / sqrt(1.0 + slope * slope), max(x0 - q.x, q.x - x1));
        if (dk < d.x)
            d = vec2(dk, y);
    }
    return d;
}

void main() {
    vec2 p = qt_TexCoord0 * u.area - u.center;
    float R = u.size * 0.5 - 1.0;
    float live = u.glow * (1.0 - u.dim);
    float ink = max(1.0, R * 0.11);
    float sp = abs(u.speed);
    float dirn = u.speed >= 0.0 ? 1.0 : -1.0;
    vec4 o = vec4(0.0);

    // ── The decal along the track ──
    float charge = 1.0 - u.dim;
    float xs = p.x + u.back;                    // px from the track's start
    if (charge > 0.0 && xs > 0.0 && p.x < 0.0) {
        // Fixed to the track so it doesn't slide as the knob moves; it grows from a
        // point at the track's start to its full width over a few runs.
        float P = u.size * 1.6;
        // Thinner than the track, so the fill frames it, and zigzagging across it.
        float th = u.size * 0.075 * smoothstep(0.0, u.size * 2.6, xs);
        float A = th * 1.2;
        vec2 dd = decal(vec2(xs + P * 0.3, p.y), P, A, th);
        float d = dd.x;
        // Cel-shaded: white-hot, its lower edge orange, a highlight along its top, so it
        // reads on a red fill and a yellow one alike; live, a charge runs along it into
        // the wheel, lighting the highlight.
        float lower = band(dd.y, th * 0.1);
        float run = fract((xs - u.time * u.size * 9.0) / (u.size * 4.0));
        float hot = live * smoothstep(0.0, 0.05, run) * (1.0 - smoothstep(0.05, 0.3, run));
        vec3 dc = mix(mix(u.cCore.rgb, u.cGold.rgb, 0.3), u.cEdge.rgb, lower);
        dc = mix(dc, u.cCore.rgb, 0.6 * hot);
        float hi = band(-dd.y, th * 0.25) * cover(-d - 0.8);
        o = over(o, u.cTire.rgb, cover(ink - d) * charge);
        o = over(o, dc, cover(-d) * charge);
        o = over(o, u.cCore.rgb, hi * mix(0.7, 1.0, hot) * charge);
    }

    // ── Speed dashes streaming off behind it as it moves ──
    if (sp > 0.05) {
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float y = R * (fi - 1.0) * 0.62;
            float x0 = -dirn * (R + 3.0);
            float x1 = x0 - dirn * R * (0.4 + 1.3 * sp) * (i == 1 ? 1.0 : 0.65);
            float d = sdSeg(p, vec2(x0, y), vec2(x1, y)) - max(0.9, R * 0.12);
            float a = smoothstep(0.05, 0.35, sp);
            o = over(o, u.cTire.rgb, cover(ink - d) * a);
            o = over(o, mix(u.cCore.rgb, u.cGold.rgb, 0.4), cover(-d) * a);
        }
    }

    // ── Zaps flicking out round the tire while live ──
    if (live > 0.0 && length(p) < R * 2.2) {
        float slot = floor(u.time * 9.0);
        float a = atan(p.y, p.x);
        float r = length(p);
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float th = TAU * (hash(vec2(slot, fi)) + fi) / 3.0;
            vec2 dir = vec2(cos(th), sin(th));
            vec2 a0 = dir * (R + 2.5), a1 = dir * (R * 1.85 + 2.0);
            // A kink halfway, so each reads as a little bolt.
            vec2 m = (a0 + a1) * 0.5 + vec2(-dir.y, dir.x) * R * 0.22;
            float d = min(sdSeg(p, a0, m), sdSeg(p, m, a1)) - max(0.7, R * 0.09);
            float on = live * step(0.25, hash(vec2(slot, fi + 7.0)));
            o = over(o, u.cTire.rgb, cover(ink * 0.8 - d) * on);
            o = over(o, u.cGold.rgb, cover(-d) * on);
        }
    }

    // ── The wheel, squashed a little along its motion ──
    vec2 w = p * vec2(1.0 - 0.08 * sp, 1.0 + 0.06 * sp);
    float r = length(w);
    float ar = atan(w.y, w.x) - u.turn;          // angle on the turning wheel
    vec3 gold = mix(u.cGold.rgb, u.cWall.rgb, 0.7 * u.dim);
    vec3 hub = mix(u.cPaint.rgb, u.cWall.rgb, 0.7 * u.dim);
    vec3 shine = mix(u.cWall.rgb, u.cCore.rgb, 0.55 - 0.3 * u.dim);
    // Tire: rubber with a few tread notches, and a cartoon shine on the sidewall.
    vec3 col = u.cWall.rgb;
    float notch = step(0.62, fract(ar * 8.0 / TAU)) * step(R * 0.9, r);
    col = mix(col, u.cTire.rgb, notch);
    float sa = atan(w.y, w.x);
    float arcShine = cover(R * 0.08 + 0.4 - abs(r - R * 0.8)) * smoothstep(0.75, 0.2, abs(sa + 2.2));
    col = mix(col, shine, arcShine);
    // Rim: a gold disc with five lug holes round a red hub; they blur into a ring
    // as it speeds along.
    float ringR = R * 0.6;
    float sector = TAU / 5.0;
    float ah = (floor(ar / sector) + 0.5) * sector;
    float hole = length(w - vec2(cos(ah + u.turn), sin(ah + u.turn)) * R * 0.42) - max(0.8, R * 0.12);
    float blur = smoothstep(0.25, 0.8, sp);
    float holes = mix(cover(-hole), 0.5 * cover(max(0.8, R * 0.12) - abs(r - R * 0.42)), blur);
    vec3 rim = mix(gold, u.cTire.rgb, holes);
    rim = mix(rim, mix(gold, u.cCore.rgb, 0.65), cover(0.7 - abs(r - ringR * 0.8)) * smoothstep(0.5, 0.0, abs(sa + 2.2)));
    col = mix(col, u.cTire.rgb, cover(ringR + ink * 0.7 - r));
    col = mix(col, rim, cover(ringR - r));
    col = mix(col, u.cTire.rgb, cover(R * 0.22 + ink * 0.5 - r));
    col = mix(col, hub, cover(R * 0.22 - r));
    // The hub's glint, fixed to the light.
    col = mix(col, u.cCore.rgb, cover(R * 0.09 - length(w - vec2(-R * 0.08, -R * 0.09))) * (1.0 - u.dim));

    o = over(o, u.cTire.rgb, cover(R + ink * 0.5 - r));
    o = over(o, col, cover(R - ink * 0.5 - r));
    fragColor = o * u.qt_Opacity;
}
