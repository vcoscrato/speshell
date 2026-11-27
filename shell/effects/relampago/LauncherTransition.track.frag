#version 440
#extension GL_GOOGLE_include_directive : enable
// Everything around the racing launcher, outside the panel: comic speed lines
// streaming past in three depths, tapering from a round head to a point, the near
// ones outlined, in yellow, orange, and red, all round it while it races and only
// trailing off behind it in gusts once it stands; arcs of electricity crackling along
// the panel's border; where a bolt strikes the border, a starburst popping outward
// and a charge racing away along it both ways; the skid marks it leaves as it brakes;
// and the two trails of fire its tires lay down as it tears away.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 offset;        // px, where this item's top left lies on the screen
    vec2 resolution;    // this item's size, px
    float screenWidth;  // px
    float time;
    vec4 rect;          // px, the panel where it is drawn now
    float radius;       // its corner radius
    float lines;        // 0..1 speed lines
    float calm;         // 0..1 how far they have drawn back to trail behind it
    float spread;       // how far above and below the panel they reach, 1 at rest
    float travel;       // px the scenery has streamed past
    float arcs;         // 0..1 electric crackle on the border
    float skid;         // 0..1 skid marks
    vec2 skidSpan;      // px, x where the marks start and end
    float fire;         // 0..1 fire trail
    vec2 fireSpan;      // px, x where the trail starts and the tires are now
    float trackY;       // px, y of the tire tracks (the panel's bottom edge)
    vec4 hitA;          // two bolts striking the border: where (px), s since they
    vec4 hitB;          // landed (< 0 before), and a seed
    vec4 cLine;
    vec4 cCore;
    vec4 cGlow;
    vec4 cEdge;
    vec4 cPaint;
    vec4 cRubber;
} u;
#include "../common/common.glsl"
#include "Star.glsl"

// One depth of comic speed lines streaming left, in rows: lines of uneven lengths
// and gaps, each tapering from a round head on its right to a point, coming in gusts
// along the row. Returns (signed distance to the nearest, 0..1 which color).
vec2 speedLines(vec2 p, float k, float rowH, float density, float speed, float width) {
    float row = floor(p.y / rowH);
    vec3 h = vec3(hash(vec2(row, k * 7.0 + 1.0)), hash(vec2(row, k * 7.0 + 2.0)), hash(vec2(row, k * 7.0 + 3.0)));
    float cy = (row + 0.5 + (h.y - 0.5) * 0.5) * rowH;
    if (abs(p.y - cy) > width + 2.0)
        return vec2(1e3, 0.0);
    float period = rowH * mix(12.0, 22.0, h.z);
    float x = p.x + u.travel * speed * mix(0.8, 1.25, h.y) + h.x * period * 7.0;
    float cell = floor(x / period);
    vec3 c = vec3(hash(vec2(cell, row + k * 31.0)), hash(vec2(cell, row + k * 31.0 + 5.0)),
                  hash(vec2(cell, row + k * 31.0 + 9.0)));
    float gust = smoothstep(0.25, 0.65, vnoise(vec2(cell * 0.31, row * 0.37 + k * 3.0)));
    if (c.x > density * gust)
        return vec2(1e3, 0.0);
    float len = period * mix(0.3, 0.95, c.y * c.y);
    float s = x - (cell + 0.05 * c.z) * period;      // px from its tail
    float w = width * mix(0.65, 1.15, c.z);
    float body = max(len - w, 0.0);
    float taper = mix(0.12, 1.0, clamp(s / max(body, 1.0), 0.0, 1.0));
    float d = length(vec2(s - clamp(s, 0.0, body), p.y - cy)) - w * taper;
    return vec2(d, c.z);
}

// Distance to an arc of electricity along the border, `du` px along it from the arc's
// middle and `sd` px out from it: jumping out by up to `amp` and back over `len` px,
// in sharp kinks that re-roll with `seed`.
float borderArc(float sd, float du, float len, float amp, float seed) {
    float tt = du / len + 0.5;
    if (tt < 0.0 || tt > 1.0)
        return 1e3;
    float env = amp * pow(sin(PI * tt), 0.7);
    #define ARC(x) (1.5 + env * (0.5 + 1.2 * zig((x) / 13.0 + seed * 3.1, seed) + 0.4 * zig((x) / 5.0, seed + 1.0)))
    float off = ARC(du);
    float off2 = ARC(du + 1.0);
    #undef ARC
    return abs(sd - off) / sqrt(1.0 + (off2 - off) * (off2 - off));
}

// An arc at distance d, `w` px thick in its core, outlined.
vec4 arcOver(vec4 col, float d, float w, float on) {
    col = over(col, u.cRubber.rgb, cover(w + 2.0 - d) * on);
    col = over(col, u.cGlow.rgb, cover(w + 0.9 - d) * on);
    return over(col, u.cCore.rgb, cover(w - d) * on);
}

// Where a bolt struck the border: a comic starburst popping out of the border and
// shrinking away, and a charge racing off along the border both ways from it, its
// arcs trailing the fronts and dying out.
vec4 hitOver(vec4 col, vec4 hit, vec2 p, vec2 c, vec2 h, float sd, float s, float P) {
    float age = hit.z;
    if (age < 0.0 || age > 0.75)
        return col;
    vec2 q = p - hit.xy;
    float lq = length(q);
    if (lq < 60.0 && age < 0.34) {
        float k = clamp(age / 0.3, 0.0, 1.0);
        float sc = backOut(k / 0.3) * (1.0 - smoothstep(0.45, 1.0, k));
        if (sc > 0.02) {
            vec2 r = rot(q, hit.w * 6.0 + k * 0.5) / sc;
            float d0 = starDist(r, 9.0, 18.0, 48.0, hit.w);
            float d1 = starDist(rot(r, PI / 9.0), 9.0, 11.0, 30.0, hit.w + 1.0);
            col = over(col, u.cRubber.rgb, cover(2.5 - d0 * sc));
            col = over(col, u.cPaint.rgb, cover(-d0 * sc));
            col = over(col, u.cGlow.rgb, cover(-d1 * sc));
            col = over(col, u.cCore.rgb, cover(12.0 - lq / sc) * cover(-d1 * sc));
        }
    }
    if (sd < 24.0) {
        float s0 = rrArc(hit.xy - c, h, u.radius);
        float du = mod(s - s0 + P * 0.5, P) - P * 0.5;
        float front = 1100.0 * (1.0 - exp(-age * 3.2)) / 3.2;
        float fade = 1.0 - smoothstep(0.35, 0.75, age);
        float len = 90.0 * fade + 20.0;
        float flick = floor(u.time * 20.0);
        // The arc that trails each front, its tail on the front's side nearest the hit.
        float side = du < 0.0 ? -1.0 : 1.0;
        float d = borderArc(sd, abs(du) - front + len * 0.5, len, 18.0 * fade + 5.0, hit.w * 7.0 + flick + side);
        float on = fade * step(0.2, hash(vec2(flick, hit.w + side)));
        col = arcOver(col, d, 0.3 + 0.6 * fade, on);
    }
    return col;
}

void main() {
    vec2 p = u.offset + qt_TexCoord0 * u.resolution;
    vec2 c = u.rect.xy + u.rect.zw * 0.5;
    vec2 h = u.rect.zw * 0.5;
    float sd = sdRoundRect(p - c, h, u.radius);
    // Nothing is drawn over the panel.
    float keep = cover(sd - 2.0);
    if (keep <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    vec4 col = vec4(0.0);

    // ── Speed lines, far to near: all round the panel while it races, then only
    //    the nearer ones trailing off behind it ──
    if (u.lines > 0.0) {
        float edgeFade = smoothstep(0.0, 160.0, p.x) * smoothstep(0.0, 160.0, u.screenWidth - p.x);
        float behind = smoothstep(0.0, 24.0, u.rect.x - p.x) * exp(-max(0.0, u.rect.x - p.x - 40.0) / 170.0)
                     * (1.0 - smoothstep(h.y * 0.8, h.y * 1.0, abs(p.y - c.y)));
        for (int i = 0; i < 3; i++) {
            float k = float(i);
            float spread = (40.0 + 20.0 * k) * u.spread;
            float env = exp(-max(0.0, abs(p.y - c.y) - h.y * 0.9) / spread) * edgeFade;
            env = mix(env, behind * (k > 0.5 ? 1.0 : 0.7), u.calm) * u.lines;
            if (env < 0.01)
                continue;
            vec2 l = speedLines(p, k, 8.0 + 7.0 * k, 0.55 - 0.08 * k, 0.4 + 0.5 * k, 0.7 + 0.9 * k);
            if (l.x > 3.0)
                continue;
            if (i == 0) {
                col = over(col, u.cLine.rgb, cover(-l.x) * 0.22 * env);
            } else {
                // Nearer: outlined in rubber, yellow, orange, or red.
                vec3 lc = l.y < 0.4 ? u.cGlow.rgb : l.y < 0.75 ? u.cEdge.rgb : u.cPaint.rgb;
                lc = mix(lc, u.cLine.rgb, k < 1.5 ? 0.3 : 0.0);
                col = over(col, u.cRubber.rgb, cover(1.3 - l.x) * env * (0.55 + 0.4 * (k - 1.0)));
                col = over(col, lc, cover(-l.x) * env * (0.6 + 0.4 * (k - 1.0)));
            }
        }
    }

    // ── Electricity crackling along the border: arcs that jump out from it, their
    //    kinks re-rolling as they flicker, and die, in a few places at a time; and
    //    where bolts strike it ──
    bool hits = u.hitA.z >= 0.0 && u.hitA.z < 0.75 || u.hitB.z >= 0.0 && u.hitB.z < 0.75;
    if ((u.arcs > 0.0 || hits) && sd < 60.0) {
        float P = rrPerimeter(h, u.radius);
        float s = rrArc(p - c, h, u.radius);
        if (sd < 26.0 && u.arcs > 0.0) {
            for (int i = 0; i < 3; i++) {
                float k = float(i);
                float ph = u.time * (1.3 + 0.37 * k) + 0.37 * k;
                float slot = floor(ph);
                float life = fract(ph);
                if (hash(vec2(slot, k + 1.0)) > 0.6 || life > 0.36)
                    continue;
                float s0 = hash(vec2(slot, k + 5.0)) * P;
                float len = mix(50.0, 130.0, hash(vec2(slot, k + 9.0)));
                float du = mod(s - s0 + P * 0.5, P) - P * 0.5;
                float flick = floor(u.time * 18.0);
                float d = borderArc(sd, du, len, mix(10.0, 20.0, hash(vec2(slot, k + 3.0))), slot * 3.0 + k + flick * 0.13);
                float on = step(0.25, hash(vec2(flick, slot + k))) * (1.0 - smoothstep(0.24, 0.36, life)) * u.arcs;
                col = arcOver(col, d, 0.5, on);
            }
        }
        col = hitOver(col, u.hitA, p, c, h, sd, s, P);
        col = hitOver(col, u.hitB, p, c, h, sd, s, P);
    }

    // ── Skid marks: two dark streaks left behind as it braked, fading ──
    if (u.skid > 0.0 && p.x > u.skidSpan.x && p.x < u.skidSpan.y) {
        float t = (p.x - u.skidSpan.x) / max(u.skidSpan.y - u.skidSpan.x, 1.0);
        float wob = 1.5 * sin(p.x / 37.0) + 1.0 * sin(p.x / 13.0 + 1.0);
        float d = min(abs(p.y - u.trackY - 7.0 - wob), abs(p.y - u.trackY - 15.0 - wob * 0.8));
        float w = 0.6 + 2.0 * smoothstep(0.0, 0.6, t);
        float fray = 0.55 + 0.45 * vnoise(vec2(p.x * 0.35, floor(p.y)));
        col = over(col, u.cRubber.rgb, cover(w - d) * fray * 0.7 * u.skid);
    }

    // ── Fire trail: flames standing on the two tire tracks, the old end burning
    //    out first ──
    if (u.fire > 0.0 && p.x > u.fireSpan.x && p.x < u.fireSpan.y + 6.0) {
        float t = (p.x - u.fireSpan.x) / max(u.fireSpan.y - u.fireSpan.x, 1.0);
        float alive = smoothstep(1.0 - u.fire, 1.0 - u.fire + 0.25, t);
        for (int i = 0; i < 2; i++) {
            float y0 = u.trackY + 7.0 + 8.0 * float(i);
            float ht = (4.0 + 13.0 * vnoise(vec2(p.x / 9.0 + u.time * 6.0, float(i) * 5.0))
                       * vnoise(vec2(p.x / 31.0 - u.time * 2.0, float(i) + 2.0))) * alive;
            float y = (y0 - p.y) / max(ht, 0.5);       // 0 at the track .. 1 at the flame's tip
            if (y < -0.25 || y > 1.0 || ht < 0.6)
                continue;
            float a = cover((1.0 - y) * ht) * cover(y0 + 2.5 - p.y);
            vec3 fc = mix(u.cCore.rgb, u.cGlow.rgb, band(y, 0.25));
            fc = mix(fc, u.cEdge.rgb, band(y, 0.55));
            fc = mix(fc, u.cPaint.rgb, band(y, 0.8));
            col = over(col, fc, a);
        }
    }

    fragColor = col * keep * u.qt_Opacity;
}
