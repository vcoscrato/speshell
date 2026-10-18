#version 440
#extension GL_GOOGLE_include_directive : enable
// Everything around the racing launcher, outside the panel: speed lines streaming
// past in three depths, the near ones hot-headed with a red tail; arcs of
// electricity crackling along the panel's border; the skid marks it leaves as it
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
#include "../../lib/common.glsl"

// One depth of speed lines: dashes in some rows, streaming left, thickest at their
// leading (left) end. Returns (coverage, outline coverage, 0..1 along from the head).
vec3 speedLines(vec2 p, float k, float rowH, float density, float speed, float width) {
    float row = floor(p.y / rowH);
    vec4 h = vec4(hash(vec2(row, k * 7.0 + 1.0)), hash(vec2(row, k * 7.0 + 2.0)),
                  hash(vec2(row, k * 7.0 + 3.0)), hash(vec2(row, k * 7.0 + 4.0)));
    if (h.x > density)
        return vec3(0.0);
    float cy = (row + 0.5 + (h.y - 0.5) * 0.5) * rowH;
    float period = rowH * mix(30.0, 70.0, h.z);
    float len = period * mix(0.18, 0.42, h.w);
    float s = mod(p.x + u.travel * speed * mix(0.85, 1.2, h.y) + h.z * period * 3.0, period);
    float t = s / len;                           // 0 head .. 1 tail
    if (t > 1.0)
        return vec3(0.0);
    float w = width * pow(1.0 - t, 0.7) * smoothstep(0.0, 0.04, t);
    float d = abs(p.y - cy);
    return vec3(cover(w - d + 0.3), cover(w + 1.0 - d) * clamp(2.0 * w, 0.0, 1.0), t);
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

    // ── Speed lines, far to near, in a band around the panel ──
    if (u.lines > 0.0) {
        float edgeFade = smoothstep(0.0, 160.0, p.x) * smoothstep(0.0, 160.0, u.resolution.x - p.x);
        for (int i = 0; i < 3; i++) {
            float k = float(i);
            float spread = (40.0 + 20.0 * k) * u.spread;
            float env = exp(-max(0.0, abs(p.y - c.y) - h.y * 0.9) / spread) * edgeFade * u.lines;
            if (env < 0.01)
                continue;
            vec3 l = speedLines(p, k, 7.0 + 5.0 * k, 0.32 - 0.06 * k, 0.45 + 0.45 * k, 0.6 + 0.65 * k);
            if (i < 2) {
                col = over(col, u.cLine.rgb, l.x * (0.22 + 0.2 * k) * env);
            } else {
                // Near: a hot head trailing off into racing red, outlined.
                vec3 lc = mix(u.cCore.rgb, u.cGlow.rgb, smoothstep(0.02, 0.15, l.z));
                lc = mix(lc, u.cEdge.rgb, smoothstep(0.2, 0.45, l.z));
                lc = mix(lc, u.cPaint.rgb, smoothstep(0.5, 0.8, l.z));
                col = over(col, u.cRubber.rgb, l.y * 0.5 * env);
                col = over(col, lc, l.x * env);
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
            #define ARC(x) (2.0 + amp * (0.5 + 0.8 * zig((x) / 9.0, seed) + 0.45 * zig((x) / 3.5, seed + 1.0)))
            float off = ARC(du);
            float off2 = ARC(du + 1.0);
            #undef ARC
            float d = abs(sd - off) / sqrt(1.0 + (off2 - off) * (off2 - off));
            float on = step(0.3, hash(vec2(floor(u.time * 36.0), seed))) * (1.0 - life / 0.38) * u.arcs;
            float w = 0.8 + 0.7 * sin(3.1415927 * tt);
            col = over(col, u.cEdge.rgb, cover(w + 5.0 - d) * 0.35 * on);
            col = over(col, u.cGlow.rgb, cover(w + 1.4 - d) * on);
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
