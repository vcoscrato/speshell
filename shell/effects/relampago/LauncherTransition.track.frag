#version 440
#extension GL_GOOGLE_include_directive : enable
// Everything around the racing launcher, outside the panel: cartoon speed dashes
// streaming past in three depths, the near ones outlined, in yellow, orange, and red,
// all round it while it races and only trailing off behind it once it stands; arcs
// of electricity crackling along the panel's border; the skid marks it leaves as it
// brakes; and the two trails of fire its tires lay down as it tears away.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
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
    vec4 cLine;
    vec4 cCore;
    vec4 cGlow;
    vec4 cEdge;
    vec4 cPaint;
    vec4 cRubber;
} u;
#include "../common/common.glsl"

// One depth of speed dashes: round-capped dashes in some rows, streaming left.
// Returns (signed distance to the nearest, 0..1 which color).
vec2 speedLines(vec2 p, float k, float rowH, float density, float speed, float width) {
    float row = floor(p.y / rowH);
    vec4 h = vec4(hash(vec2(row, k * 7.0 + 1.0)), hash(vec2(row, k * 7.0 + 2.0)),
                  hash(vec2(row, k * 7.0 + 3.0)), hash(vec2(row, k * 7.0 + 4.0)));
    if (h.x > density)
        return vec2(1e3, 0.0);
    float cy = (row + 0.5 + (h.y - 0.5) * 0.3) * rowH;
    float period = rowH * mix(14.0, 30.0, h.z);
    float len = period * mix(0.2, 0.45, h.w);
    float x = p.x + u.travel * speed * mix(0.85, 1.2, h.y) + h.z * period * 3.0;
    float s = mod(x, period);
    float w = width * mix(0.7, 1.0, h.w);
    float d = length(vec2(max(0.0, max(w - s, s - len + w)), p.y - cy)) - w;
    return vec2(d, hash(vec2(floor(x / period), row + k)));
}

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
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

    // ── Speed dashes, far to near: all round the panel while it races, then only
    //    a few trailing off behind it ──
    if (u.lines > 0.0) {
        float edgeFade = smoothstep(0.0, 160.0, p.x) * smoothstep(0.0, 160.0, u.resolution.x - p.x);
        float behind = smoothstep(0.0, 30.0, u.rect.x - p.x) * exp(-max(0.0, u.rect.x - p.x - 40.0) / 140.0)
                     * (1.0 - smoothstep(h.y * 0.75, h.y * 0.95, abs(p.y - c.y)));
        for (int i = 0; i < 3; i++) {
            float k = float(i);
            float spread = (40.0 + 20.0 * k) * u.spread;
            float env = exp(-max(0.0, abs(p.y - c.y) - h.y * 0.9) / spread) * edgeFade;
            env = mix(env, behind * (k > 0.5 ? 1.0 : 0.0), u.calm) * u.lines;
            if (env < 0.01)
                continue;
            vec2 l = speedLines(p, k, 9.0 + 6.0 * k, 0.3 - 0.06 * k, 0.45 + 0.45 * k, 0.8 + 0.7 * k);
            if (l.x > 3.0)
                continue;
            if (i == 0) {
                col = over(col, u.cLine.rgb, cover(-l.x) * 0.25 * env);
            } else {
                // Nearer: outlined in rubber, yellow, orange, or red.
                vec3 lc = l.y < 0.4 ? u.cGlow.rgb : l.y < 0.75 ? u.cEdge.rgb : u.cPaint.rgb;
                lc = mix(lc, u.cLine.rgb, k < 1.5 ? 0.35 : 0.0);
                col = over(col, u.cRubber.rgb, cover(1.2 - l.x) * env * (0.5 + 0.4 * (k - 1.0)));
                col = over(col, lc, cover(-l.x) * env * (0.55 + 0.45 * (k - 1.0)));
            }
        }
    }

    // ── Electricity crackling along the border: short arcs that jump out from it,
    //    flicker, and die, in a few independent places at a time ──
    if (u.arcs > 0.0 && sd < 26.0) {
        float P = rrPerimeter(h, u.radius);
        float s = rrArc(p - c, h, u.radius);
        for (int i = 0; i < 3; i++) {
            float k = float(i);
            float ph = u.time * (1.7 + 0.45 * k) + 0.37 * k;
            float slot = floor(ph);
            float life = fract(ph);
            if (hash(vec2(slot, k + 1.0)) > 0.7 || life > 0.38)
                continue;
            float s0 = hash(vec2(slot, k + 5.0)) * P;
            float len = mix(60.0, 150.0, hash(vec2(slot, k + 9.0)));
            float du = mod(s - s0 + P * 0.5, P) - P * 0.5;
            float tt = du / len + 0.5;
            if (tt < 0.0 || tt > 1.0)
                continue;
            // Arcs out from the border and back, jagged.
            float seed = slot * 3.0 + k;
            float amp = 18.0 * pow(sin(3.1415927 * tt), 0.6);
            #define ARC(x) (2.0 + amp * (0.5 + 0.9 * zig((x) / 13.0, seed) + 0.2 * zig((x) / 5.0, seed + 1.0)))
            float off = ARC(du);
            float off2 = ARC(du + 1.0);
            #undef ARC
            float d = abs(sd - off) / sqrt(1.0 + (off2 - off) * (off2 - off));
            float on = step(0.3, hash(vec2(floor(u.time * 36.0), seed))) * (1.0 - life / 0.38) * u.arcs;
            float w = 0.8 + 0.7 * sin(3.1415927 * tt);
            col = over(col, u.cRubber.rgb, cover(w + 2.6 - d) * on);
            col = over(col, u.cGlow.rgb, cover(w + 1.2 - d) * on);
            col = over(col, u.cCore.rgb, cover(w - d) * on);
        }
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
