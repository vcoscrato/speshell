#version 440
#extension GL_GOOGLE_include_directive : enable
// Relâmpago's knob: a racing wheel that rolls as it travels, a treaded tire around a
// gold five-spoke rim with a red hub, and the charge it carries: a zigzag bolt
// along the filled track behind it, back to the track's start. Held or
// hovered, a live arc crackles along the track into the wheel and around its tire.
// Switched off, the wheel goes dull and the charge is gone. The item reaches back to
// the track's start and around the wheel.
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
#include "../../lib/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.area - u.center;
    float R = u.size * 0.5 - 1.0;
    float r = length(p);
    float a = atan(p.y, p.x);
    float ar = a - u.turn;                      // angle on the turning wheel
    float live = u.glow * (1.0 - u.dim);
    float slot = floor(u.time * 18.0);
    vec4 o = vec4(0.0);

    // ── The charge along the track ──
    float charge = 1.0 - u.dim;
    float xs = p.x + u.back;                    // px from the track's start
    if (charge > 0.0 && xs > 0.0 && p.x < 0.0) {
        float fadeIn = smoothstep(2.0, 14.0, xs);
        // The decal: a bolt zigzagging along the fill, its runs uneven, fixed to the
        // track so it doesn't slide as the knob moves, thickest at the knob.
        float P = max(9.0, u.size * 0.9);           // px per run, on average
        float A = u.size * 0.17;                    // px either side of the track's middle
        float w = u.size * mix(0.04, 0.085, smoothstep(0.0, 80.0, xs)) * fadeIn;
        float d = boltDist(vec2(xs, p.y / max(fadeIn, 0.05)), P, A, 7.0) * fadeIn - w;
        vec3 dc = mix(u.cEdge.rgb, u.cGold.rgb, smoothstep(0.0, 60.0, xs));
        dc = mix(dc, u.cCore.rgb, smoothstep(-20.0, 0.0, p.x) * 0.7);
        o = over(o, u.cTire.rgb, cover(0.9 - d) * 0.8 * fadeIn * charge);
        o = over(o, dc, cover(-d) * fadeIn * charge);
        // Live: an arc crackling along it, jumping off the track.
        if (live > 0.0) {
            float amp = u.size * 0.5;
            float y = amp * (zig(xs / 15.0, slot) + 0.5 * zig(xs / 5.0, slot + 1.0)) * fadeIn;
            float y2 = amp * (zig((xs + 1.0) / 15.0, slot) + 0.5 * zig((xs + 1.0) / 5.0, slot + 1.0)) * fadeIn;
            float da = abs(p.y - y) / sqrt(1.0 + (y2 - y) * (y2 - y));
            float on = live * step(0.2, hash(vec2(slot, 4.0)));
            o = over(o, u.cEdge.rgb, cover(4.0 - da) * 0.35 * on);
            o = over(o, u.cGold.rgb, cover(1.5 - da) * on);
            o = over(o, u.cCore.rgb, cover(0.7 - da) * on);
        }
    }

    // ── Crackle: two arcs chasing round the tire ──
    if (live > 0.0) {
        for (int i = 0; i < 2; i++) {
            float fi = float(i);
            float th = mod(a - u.time * (4.0 + 1.5 * fi) - fi * 3.1415927, 6.2831853);
            if (th > 2.0)
                continue;
            float along = th / 2.0;
            float s2 = floor(u.time * 14.0 + fi * 3.0);
            float rr = R * 1.18 + R * 0.3 * (zig(th * 5.0, s2) + 0.4 * zig(th * 13.0, s2 + 1.0)) * sin(3.1415927 * along);
            float d = abs(r - rr);
            float a0 = live * (1.0 - along) * step(0.25, hash(vec2(s2, fi)));
            o = over(o, u.cEdge.rgb, cover(2.6 - d) * 0.5 * a0);
            o = over(o, u.cCore.rgb, cover(0.9 - d) * a0);
        }
    }

    // ── The wheel ──
    vec3 rim = mix(u.cGold.rgb, u.cWall.rgb, 0.7 * u.dim);
    vec3 hub = mix(u.cPaint.rgb, u.cTire.rgb, 0.55 * u.dim);
    vec3 col = u.cTire.rgb;
    float tread = step(0.5, fract(ar * 14.0 / 6.2831853)) * step(R * 0.86, r);
    col = mix(col, u.cWall.rgb, 0.55 * tread);
    // Rim: five gold spokes, dark between them, a lip that catches the light.
    float spoke = abs(fract(ar * 5.0 / 6.2831853) - 0.5) * 6.2831853 / 5.0 * r;
    vec3 rc = mix(rim, u.cTire.rgb, 0.75);
    rc = mix(rc, rim, cover(R * 0.13 - spoke));
    rc = mix(rc, rim, cover(r - R * 0.52));
    rc = mix(rc, mix(rim, u.cCore.rgb, 0.4 + 0.4 * live), cover(0.9 - abs(r - R * 0.6)) * step(p.y, 0.0));
    col = mix(col, rc, cover(R * 0.68 - r));
    col = mix(col, hub, cover(R * 0.26 - r));
    col = mix(col, u.cTire.rgb, cover(R * 0.08 - r));

    o = over(o, u.cTire.rgb, cover(R + 0.8 - r));
    o = over(o, col, cover(R - r));
    fragColor = o * u.qt_Opacity;
}
