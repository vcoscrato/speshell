#version 440
#extension GL_GOOGLE_include_directive : enable
// One particle of Cosmos's control effects, by `kind`: 0 a mote of star dust,
// twinkling as it drifts; 1 a glint, a star flaring with four rays; 2 a constellation
// drawing itself out from the center, star by star.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float age;          // 0..1 over its life
    float seed;
    float kind;
    float size;         // px across
    float room;         // px of the layer above the center, so nothing leans off its top
    vec4 cStar;
    vec4 cHot;
    vec4 cGlow;
    vec4 cHaze;
} u;
#include "../common/common.glsl"

vec4 mote(vec2 p, float R) {
    float twinkle = 0.55 + 0.45 * sin(u.age * 30.0 + u.seed * 50.0);
    float r = R * (0.45 + 0.4 * twinkle);
    vec3 col = mix(u.cStar.rgb, u.cGlow.rgb, step(0.6, u.seed) * 0.6);
    return vec4(col, 1.0) * cover(r - length(p)) * (1.0 - u.age) * (0.5 + 0.5 * twinkle);
}

vec4 glint(vec2 p, float R) {
    float k = sin(3.1415927 * pow(u.age, 0.6));
    float c = cos(u.seed * 3.0 + u.age), s = sin(u.seed * 3.0 + u.age);
    vec2 q = mat2(c, s, -s, c) * p;
    vec2 a = abs(q);
    float len = R * k;
    float ray = max(cover(1.1 - a.y * (1.0 + 3.0 * a.x / max(len, 1.0))) * step(a.x, len),
                    cover(1.1 - a.x * (1.0 + 3.0 * a.y / max(len, 1.0))) * step(a.y, len));
    float core = cover(R * 0.18 * k + 0.6 - length(p));
    vec4 o = over(vec4(0.0), u.cGlow.rgb, ray * k);
    o = over(o, u.cHot.rgb, max(core, ray * step(length(q), len * 0.45)) * k);
    o = over(o, u.cGlow.rgb, cover(R * 0.5 * k - length(p)) * 0.18 * k);
    return o;
}

// A star of radius r and brightness b, with rays if it is a bright one.
vec4 star(vec4 o, vec2 p, float r, float b, float rays) {
    vec2 a = abs(p);
    float ray = rays * max(cover(0.7 - a.y * (1.0 + 2.5 * a.x / r)) * step(a.x, r * 3.2),
                           cover(0.7 - a.x * (1.0 + 2.5 * a.y / r)) * step(a.y, r * 3.2));
    o = over(o, u.cHaze.rgb, cover(r * 2.6 - length(p)) * 0.16 * b);
    o = over(o, u.cGlow.rgb, ray * b);
    return over(o, u.cHot.rgb, cover(r - length(p)) * b);
}

vec4 constellation(vec2 p, float R) {
    // A chain of stars wandering out from the center, and one branching off the third.
    vec2 pos[6];
    pos[0] = vec2(0.0);
    float a = u.seed * 6.2831853;
    for (int i = 1; i < 6; i++) {
        vec2 from = i == 5 ? pos[2] : pos[i - 1];
        a += (hash(vec2(u.seed, float(i))) - 0.5) * 2.6 + (i == 5 ? 1.9 : 0.0);
        float stepLen = R * (0.3 + 0.2 * hash(vec2(float(i), u.seed)));
        vec2 next = from + stepLen * vec2(cos(a), sin(a) * 0.72);
        if (next.y < 4.0 - u.room) {
            a = -a;
            next = from + stepLen * vec2(cos(a), sin(a) * 0.72);
        }
        float len = length(next);
        pos[i] = len > R * 0.9 ? next * R * 0.9 / len : next;
    }
    float fade = 1.0 - smoothstep(0.62, 1.0, u.age);
    vec4 o = vec4(0.0);
    for (int i = 1; i < 6; i++) {
        float t0 = 0.04 + float(i) * 0.075;
        float k = clamp((u.age - t0 + 0.075) / 0.075, 0.0, 1.0);
        if (k <= 0.0)
            continue;
        vec2 from = i == 5 ? pos[2] : pos[i - 1];
        vec2 to = mix(from, pos[i], k);
        float d = sdSeg(p, from, to);
        o = over(o, mix(u.cGlow.rgb, u.cStar.rgb, 0.4), cover(0.75 - d) * 0.75 * fade);
    }
    for (int i = 0; i < 6; i++) {
        float t0 = 0.04 + float(i) * 0.075;
        float since = u.age - t0;
        if (since < 0.0)
            continue;
        float h = hash(vec2(u.seed * 7.0, float(i)));
        float flare = 1.0 + 1.2 * exp(-since * 30.0);
        float twinkle = 0.75 + 0.25 * sin(u.age * 38.0 + h * 40.0);
        float r = (1.5 + 1.3 * h) * (i == 0 ? 1.3 : 1.0) * mix(1.0, flare, 0.5);
        o = star(o, p - pos[i], r, min(1.0, fade * twinkle * flare), step(0.55, h) + (i == 0 ? 1.0 : 0.0));
    }
    return o;
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.size;
    float R = u.size * 0.5 - 1.0;
    vec4 c = u.kind < 0.5 ? mote(p, R) : u.kind < 1.5 ? glint(p, R) : constellation(p, R);
    fragColor = c * u.qt_Opacity;
}
