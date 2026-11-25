#version 440
#extension GL_GOOGLE_include_directive : enable
// A small orrery around the launcher panel, which stands in the middle of its
// plane like a card on a table and lights it as the sun: tilted orbits whose far
// sides pass behind the panel and near sides below it, planets each with their own
// surface, lit from the panel so the near ones show a crescent, a moon, a ringed
// giant, a belt of dust drifting round, and a few stars that twinkle. Everything
// is masked out of what shows of the panel.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 rect;          // this item's rect on screen (px)
    vec4 panel;         // the panel's rect on screen (px)
    float radius;       // panel corner radius
    vec2 origin;        // the portal's center
    float circle;       // the portal's radius: the panel shows only inside it
    vec2 sun;           // the panel's center, which lights the planets
    vec2 center;        // orbit center, below the panel's
    float scale;        // px per orbit unit, growing from collapsed to full
    float fade;         // 0..1 planets, orbit lines, and dust
    float glow;         // 0..1 corona around the panel
    float time;         // s, for spin, drift, and twinkles
    vec4 angles;        // planets 0..3
    float angle4;
    float moonAngle;
    vec4 c0;
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 c4;
    vec4 cLand;
    vec4 cBand;
    vec4 cRing;
    vec4 cMoon;
    vec4 cShade;
    vec4 cOrbit;
    vec4 cGlow;
    vec4 cGlint;
    vec4 cDust;
} u;
#include "../common/common.glsl"

// The plane seen at a tilt: an orbit's depth axis shrinks to RATIO on screen, and
// the whole plane leans by TILT. LauncherTransition.qml keeps the same values.
const float RATIO = 0.46;
const float TILT = -0.08;
const float BELT_IN = 1.92;
const float BELT_OUT = 2.06;

// Planet i: orbit size (in orbit units, the panel's half width), radius (px), and angle.
vec3 planetParams(int i) {
    if (i == 0) return vec3(1.2, 5.5, u.angles.x);
    if (i == 1) return vec3(1.41, 10.0, u.angles.y);
    if (i == 2) return vec3(1.62, 15.0, u.angles.z);
    if (i == 3) return vec3(1.8, 7.5, u.angles.w);
    return vec3(2.27, 20.5, u.angle4);
}

// A point of the plane (x across, y toward the viewer, in px) on screen.
vec2 onScreen(vec2 v) {
    return u.center + rot(vec2(v.x, v.y * RATIO), TILT);
}

// Planet i's place in the plane (px).
vec2 inPlane(int i) {
    vec3 pp = planetParams(i);
    return pp.x * u.scale * vec2(cos(pp.z), sin(pp.z));
}

// A planet of radius r at c, whose place in the plane is v: a sphere lit from the
// panel, in three flat tones and a glint, with a surface by kind. 0: pocked rock;
// 1: swirled cloud bands; 2: ocean with land and polar caps under a thin
// atmosphere; 3: rust with dark plains and a polar cap; 4: a banded giant with a
// storm.
vec4 planet(vec4 dst, vec2 p, vec2 c, float z, float r, vec3 col, int kind, float spin) {
    vec2 d = (p - c) / r;
    float dist = length(d);
    float a = cover((1.0 - dist) * r);
    if (a <= 0.0)
        return dst;
    vec3 n = vec3(d, sqrt(max(0.0, 1.0 - dist * dist)));
    // Toward the panel's middle, and toward the viewer the more the planet is behind
    // the panel, so a near one is half lit from above and a far one nearly full.
    vec3 l = normalize(vec3(normalize(u.sun - c + vec2(0.0, 1e-3)), 0.5 - 0.4 * z));
    float lit = dot(n, l);
    // Longitude and latitude, the planet turning about a slightly leaning axis.
    vec2 m = rot(n.xy, 0.25);
    vec2 s = vec2(atan(m.x, n.z) + spin, m.y);

    vec3 surf = col;
    if (kind == 0) {
        surf = mix(col, col * 0.78, band(vnoise(s * vec2(2.2, 3.0) + 3.0), 0.6));
    } else if (kind == 1) {
        float f = s.y * 6.0 + 0.9 * vnoise(vec2(s.x * 2.0, s.y * 3.0) + 7.0);
        surf = mix(col, mix(col, u.cGlint.rgb, 0.45), band(sin(f), 0.35));
    } else if (kind == 2) {
        float land = vnoise(vec2(s.x * 1.4, s.y * 2.4) + 11.0) + 0.3 * vnoise(vec2(s.x * 3.5, s.y * 5.0));
        surf = mix(col, u.cLand.rgb, band(land, 0.82));
        surf = mix(surf, u.cGlint.rgb, band(abs(s.y), 0.8 - 0.06 * sin(s.x * 3.0)));
    } else if (kind == 3) {
        surf = mix(col, col * 0.7, band(vnoise(vec2(s.x * 1.8, s.y * 2.6) + 5.0), 0.62));
        surf = mix(surf, u.cGlint.rgb, band(-s.y, 0.74));
    } else {
        // Bands of three tones with ragged edges, and an oval storm riding one.
        float f = s.y * 4.6 + 0.22 * vnoise(vec2(s.x * 3.0, s.y * 10.0)) + 0.3;
        float k = fract(floor(f) * 0.618);
        surf = mix(col, u.cBand.rgb, step(0.33, k));
        surf = mix(surf, mix(col, u.cGlint.rgb, 0.55), step(0.7, k));
        vec2 st = vec2(mod(s.x - 0.6, TAU) - PI, s.y - 0.33) * vec2(1.0, 2.6);
        surf = mix(surf, mix(u.c3.rgb, col, 0.35), cover(0.32 - length(st)));
    }

    vec3 shade = mix(surf, u.cShade.rgb, 0.58);
    vec3 tone = mix(shade, mix(surf, u.cShade.rgb, 0.3), band(lit, -0.12));
    tone = mix(tone, surf, band(lit, 0.22));
    tone = mix(tone, mix(surf, u.cGlint.rgb, 0.5), band(lit, 0.9) * band(dist, 0.5));
    // A thin bright limb where the light grazes, and an atmosphere's blue rim.
    float limb = band(dist, kind == 2 ? 0.82 : 0.88) * band(lit, 0.05);
    tone = mix(tone, mix(surf, u.cGlint.rgb, kind == 2 ? 0.55 : 0.35), limb * (kind == 2 ? 0.9 : 0.6));
    return over(dst, tone, a);
}

// The giant's rings around c, front the half nearer the viewer, leaning with the
// plane: two bands split by a dark gap, the outer edge dimmer.
vec4 rings(vec4 dst, vec2 p, vec2 c, float r, bool front) {
    vec2 q = rot(p - c, -TILT - 0.22);
    if ((q.y > 0.0) != front)
        return dst;
    float e = length(q / vec2(1.0, 0.36)) / r;
    float a = cover((e - 1.32) * r * 0.36) * cover((2.3 - e) * r * 0.36);
    if (a <= 0.0)
        return dst;
    a *= 1.0 - 0.8 * cover((0.06 - abs(e - 1.86)) * r * 0.36);
    vec3 col = mix(u.cRing.rgb, mix(u.cRing.rgb, u.cGlint.rgb, 0.4), band(e, 1.62));
    col = mix(col, mix(col, u.cShade.rgb, 0.4), band(e, 2.05));
    return over(dst, col, a * u.cRing.a);
}

// Dust of the belt at p, whose place in the plane is v, drifting round, inner rows
// faster: one speck to a cell of a grid in angle and radius, so a pixel only looks
// at its own.
float belt(vec2 p, vec2 v) {
    float rr = length(v) / u.scale;
    if (rr < BELT_IN || rr > BELT_OUT)
        return 0.0;
    float row = floor((rr - BELT_IN) / 0.04);
    float drift = u.time * TAU / (30.0 + 6.0 * row + 4.0 * hash(vec2(row, 4.0)));
    float ang = atan(v.y, v.x) - drift;
    const float N = 150.0;
    float cell = floor(ang / TAU * N);
    float cid = mod(cell, N);
    vec3 h = vec3(hash(vec2(cid, row)), hash(vec2(cid, row + 9.0)), hash(vec2(cid, row + 21.0)));
    // Clumps and gaps round the belt, from waves that fit it a whole number of times.
    float around = cid / N * TAU;
    float keep = 0.3 + 0.2 * sin(around * 3.0 + row * 1.7) + 0.14 * sin(around * 8.0 + 2.0 + row);
    if (h.x > keep)
        return 0.0;
    float sa = (cell + 0.2 + 0.6 * h.y) / N * TAU + drift;
    float sr = (BELT_IN + (row + 0.2 + 0.6 * h.z) * 0.04) * u.scale;
    vec2 sv = sr * vec2(cos(sa), sin(sa));
    float near = sv.y / sr;
    float size = mix(0.45, 1.3, fract(h.x * 13.7)) * (1.0 + 0.3 * near);
    return cover(size - length(onScreen(sv) - p)) * mix(0.35, 0.9, h.z) * (0.75 + 0.25 * near);
}

// A few stars around the system, each twinkling now and then into a small cross.
vec4 twinkles(vec4 dst, vec2 p) {
    const float CELL = 78.0;
    vec2 g = floor(p / CELL);
    vec3 h = vec3(hash(g + 31.0), hash(g + 57.0), hash(g + 83.0));
    vec2 rel = (p - u.rect.xy) / u.rect.zw * 2.0 - 1.0;
    if (h.x > 0.2 * (1.0 - smoothstep(0.55, 1.0, length(rel))))
        return dst;
    vec2 sp = (g + 0.3 + 0.4 * hash2(g + 5.0)) * CELL;
    vec2 o = abs(p - sp);
    float period = 4.0 + 5.0 * h.y;
    float ph = fract(u.time / period + h.z);
    float tw = pow(max(0.0, 1.0 - abs(ph - 0.5) * 5.0), 2.0);
    float core = cover(mix(0.5, 1.0, h.y) + 0.8 * tw - length(o));
    float len = 3.0 + 9.0 * tw;
    float rays = tw * cover(0.55 - min(o.x, o.y)) * cover(len - max(o.x, o.y)) * (1.0 - max(o.x, o.y) / len);
    float k = max(core * (0.4 + 0.6 * tw), rays);
    return over(dst, mix(u.cDust.rgb, u.cGlint.rgb, tw), k);
}

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec4 acc = vec4(0.0);

    // Corona: a warm haze hugging what the portal shows of the panel, so it never
    // outlines the part still hidden.
    vec2 ph = u.panel.zw * 0.5;
    float sd = sdRoundRect(p - (u.panel.xy + ph), ph, u.radius);
    float shown = max(sd, length(p - u.origin) - u.circle);
    float corona = u.cGlow.a * u.glow * exp(-max(shown, 0.0) / 26.0) * smoothstep(0.0, 1.5, shown);

    acc = twinkles(acc, p);

    // Orbit lines, faint and a little heavier on the near side, brightening along
    // the trail each planet leaves behind it.
    vec2 q = rot(p - u.center, -TILT);
    float th = atan(q.y, q.x);
    for (int i = 0; i < 5; i++) {
        vec3 pp = planetParams(i);
        float A = pp.x * u.scale;
        vec2 e = vec2(A, A * RATIO);
        float f = length(q / e);
        float dl = (f - 1.0) * f / max(length(q / (e * e)), 1e-4);
        if (abs(dl) > 2.5)
            continue;
        float near = smoothstep(-1.0, 1.0, q.y / e.y);
        float behind = mod(pp.z - th, TAU) / (TAU * 0.3);
        float trail = behind < 1.0 ? (1.0 - behind) * (1.0 - behind) : 0.0;
        float line = 1.0 - smoothstep(0.35 + 0.35 * near + 0.4 * trail, 1.4 + 0.3 * near + 0.5 * trail, abs(dl));
        acc = over(acc, u.cOrbit.rgb, line * u.cOrbit.a * ((0.2 + 0.25 * near) + 1.6 * trail));
    }
    acc = over(acc, u.cDust.rgb, belt(p, vec2(q.x, q.y / RATIO)));
    acc *= u.fade;

    // Bodies, far ones first; nearer is larger.
    vec4 bodies = vec4(0.0);
    for (int pass = 0; pass < 2; pass++) {
        for (int i = 0; i < 5; i++) {
            vec2 pv = inPlane(i);
            float z = pv.y / (planetParams(i).x * u.scale);
            if ((z > 0.0) != (pass == 1))
                continue;
            vec2 c = onScreen(pv);
            float r = planetParams(i).y * (1.0 + 0.36 * z) * mix(0.5, 1.0, u.fade);
            if (length(p - c) > r * 2.8 + 2.0)
                continue;
            float spin = u.time * (0.5 - 0.07 * float(i));
            if (i == 0) {
                bodies = planet(bodies, p, c, z, r, u.c0.rgb, 0, spin);
            } else if (i == 1) {
                bodies = planet(bodies, p, c, z, r, u.c1.rgb, 1, spin);
            } else if (i == 2) {
                // Its moon passes behind it half the time.
                vec2 mo = vec2(cos(u.moonAngle), sin(u.moonAngle));
                vec2 mc = c + rot(vec2(mo.x * r * 2.3, mo.y * r * 0.8), TILT);
                if (mo.y < 0.0)
                    bodies = planet(bodies, p, mc, z, r * 0.3, u.cMoon.rgb, 0, spin);
                bodies = planet(bodies, p, c, z, r, u.c2.rgb, 2, spin);
                if (mo.y >= 0.0)
                    bodies = planet(bodies, p, mc, z, r * 0.3, u.cMoon.rgb, 0, spin);
            } else if (i == 3) {
                bodies = planet(bodies, p, c, z, r, u.c3.rgb, 3, spin);
            } else {
                bodies = rings(bodies, p, c, r, false);
                bodies = planet(bodies, p, c, z, r, u.c4.rgb, 4, spin * 1.6);
                bodies = rings(bodies, p, c, r, true);
            }
        }
    }
    acc = bodies * u.fade + acc * (1.0 - bodies.a * u.fade);

    // Nothing draws over what shows of the panel; the corona goes under the rest.
    acc *= smoothstep(0.0, 1.5, shown);
    acc = acc + vec4(u.cGlow.rgb, 1.0) * corona * (1.0 - acc.a);
    fragColor = acc * u.qt_Opacity;
}
