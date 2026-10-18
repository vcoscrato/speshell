#version 440
#extension GL_GOOGLE_include_directive : enable
// A small solar system around the launcher panel, which plays the sun: tilted
// orbits, cel-shaded planets lit from the panel, a ringed giant, a moon, and a
// faint corona. Everything is masked out of the panel itself.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 rect;          // this item's rect on screen (px)
    vec4 panel;         // the panel's rect on screen (px)
    float radius;       // panel corner radius
    vec2 center;        // orbit center
    float halfWidth;    // orbit scale: the innermost orbit sits just past this
    float spread;       // 0..1 orbit size, from collapsed to full
    float fade;         // 0..1 planets and orbit lines
    float glow;         // 0..1 corona around the panel
    vec4 angles;        // planets 0..3
    float angle4;
    float moonAngle;
    vec4 c0;
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 c4;
    vec4 cRing;
    vec4 cMoon;
    vec4 cShade;
    vec4 cOrbit;
    vec4 cGlow;
    vec4 cGlint;
} u;
#include "../../lib/common.glsl"

const float RATIO = 0.42;      // orbit ellipse b / a: the plane seen at a tilt
const float TILT = -0.12;      // radians

// Planet i: orbit size (in half widths), radius (px), angle, and color. Plain
// branches, since the older GLSL targets have no constant arrays.
vec3 planetParams(int i) {
    if (i == 0) return vec3(1.18, 4.5, u.angles.x);
    if (i == 1) return vec3(1.36, 7.0, u.angles.y);
    if (i == 2) return vec3(1.56, 8.5, u.angles.z);
    if (i == 3) return vec3(1.77, 6.5, u.angles.w);
    return vec3(2.02, 11.5, u.angle4);
}

vec3 planetColor(int i) {
    if (i == 0) return u.c0.rgb;
    if (i == 1) return u.c1.rgb;
    if (i == 2) return u.c2.rgb;
    if (i == 3) return u.c3.rgb;
    return u.c4.rgb;
}

float orbitA(int i) {
    return u.halfWidth * planetParams(i).x * mix(0.12, 1.0, u.spread);
}

// Position of planet i, and its depth (-1 far .. 1 near).
vec3 body(int i) {
    float a = orbitA(i);
    float th = planetParams(i).z;
    return vec3(u.center + rot(vec2(a * cos(th), a * RATIO * sin(th)), TILT), sin(th));
}

// A planet disc lit from the center: lit face, shadowed face, and a thin rim.
vec4 planet(vec4 dst, vec2 p, vec2 c, float r, vec3 col) {
    vec2 d = (p - c) / r;
    float dist = length(d);
    float a = cover((1.0 - dist) * r);
    if (a <= 0.0)
        return dst;
    vec2 l = normalize(u.center - c + vec2(0.0, 1e-3));
    // Terminator on the sphere's surface, slightly toward the lit side.
    float lit = dot(d, l) + 0.35 * sqrt(max(0.0, 1.0 - dist * dist));
    vec3 shaded = mix(col, u.cShade.rgb, 0.62);
    vec3 surf = mix(shaded, col, band(lit, 0.18));
    surf = mix(surf, mix(col, u.cGlint.rgb, 0.45), band(lit, 0.9) * band(dist, 0.62));
    return over(dst, surf, a);
}

// Saturn-style ring around c; `front` picks the half nearer the viewer.
vec4 ring(vec4 dst, vec2 p, vec2 c, float r, bool front) {
    vec2 q = rot(p - c, 0.35);
    if ((q.y > 0.0) != front)
        return dst;
    float e = length(q / vec2(r * 2.2, r * 0.62));
    float inner = (e - 1.28) * r * 0.62;
    float outer = (1.62 - e) * r * 0.62;
    float a = min(cover(inner), cover(outer));
    // A dark gap splits the ring in two.
    a *= 1.0 - 0.75 * (1.0 - smoothstep(0.02, 0.06, abs(e - 1.47)));
    return over(dst, u.cRing.rgb, a * u.cRing.a);
}

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec4 acc = vec4(0.0);

    // Corona: a warm haze hugging the panel.
    vec2 ph = u.panel.zw * 0.5;
    float sd = sdRoundRect(p - (u.panel.xy + ph), ph, u.radius);
    acc = over(acc, u.cGlow.rgb, u.cGlow.a * u.glow * exp(-max(sd, 0.0) / 26.0));

    // Orbit lines, brighter on the near side.
    vec2 q = rot(p - u.center, -TILT);
    for (int i = 0; i < 5; i++) {
        vec2 e = vec2(orbitA(i), orbitA(i) * RATIO);
        float f = length(q / e);
        float d = (f - 1.0) * f / max(length(q / (e * e)), 1e-4);
        float near = smoothstep(-1.0, 1.0, q.y / e.y);
        float line = 1.0 - smoothstep(0.5, 1.6, abs(d));
        acc = over(acc, u.cOrbit.rgb, line * u.cOrbit.a * (0.45 + 0.55 * near) * u.fade);
    }

    // Bodies, far ones first.
    vec4 bodies = vec4(0.0);
    for (int pass = 0; pass < 2; pass++) {
        for (int i = 0; i < 5; i++) {
            vec3 pos = body(i);
            if ((pos.z > 0.0) != (pass == 1))
                continue;
            vec2 c = pos.xy;
            float r = planetParams(i).y * (1.0 + 0.18 * pos.z) * mix(0.5, 1.0, u.spread);
            vec3 col = planetColor(i) * (0.82 + 0.18 * pos.z);
            if (i == 2) {
                // The third planet's moon passes behind it half the time.
                vec2 m = c + rot(vec2(cos(u.moonAngle) * r * 2.6, sin(u.moonAngle) * r * 1.0), TILT);
                if (sin(u.moonAngle) < 0.0)
                    bodies = planet(bodies, p, m, r * 0.34, u.cMoon.rgb);
                bodies = planet(bodies, p, c, r, col);
                if (sin(u.moonAngle) >= 0.0)
                    bodies = planet(bodies, p, m, r * 0.34, u.cMoon.rgb);
            } else if (i == 4) {
                bodies = ring(bodies, p, c, r, false);
                bodies = planet(bodies, p, c, r, col);
                bodies = ring(bodies, p, c, r, true);
            } else {
                bodies = planet(bodies, p, c, r, col);
            }
        }
    }
    acc = bodies * u.fade + acc * (1.0 - bodies.a * u.fade);

    // Nothing draws over the panel.
    fragColor = acc * smoothstep(0.0, 1.5, sd) * u.qt_Opacity;
}
