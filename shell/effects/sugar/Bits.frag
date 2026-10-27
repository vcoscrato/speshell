#version 440
#extension GL_GOOGLE_include_directive : enable
// One particle of Sugar's small effects, by `kind`, the bigger ones edged softly in
// chocolate: 0 a sugar sparkle, a four-pointed twinkle; 1 powdered sugar sifted down
// from the item's top, grains spreading as they fall; 2 a puff of powdered sugar, lumps that
// bloom and shrink, dusted with grains; 3 a grain of sugar, glinting as it turns; 4 a
// crumb of cake, a lumpy chunk of sponge with a frosted side.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float age;          // 0..1 over its life
    float seed;
    float kind;
    float size;         // px across
    vec4 cInk;
    vec4 cFrost;
    vec4 cFrostLight;
    vec4 cFrostShade;
    vec4 cSparkle;
    vec4 cCream;
    vec4 cSponge;
} u;
#include "../common/common.glsl"

const float TAU = 6.2831853;

float ink(float R) {
    return clamp(R * 0.08, 1.0, 2.5);
}

// A shape at signed distance d (< 0 inside), filled and softly edged.
vec4 inked(vec4 under, float d, vec3 fill, float ow, float a) {
    vec4 c = over(under, u.cInk.rgb, cover(ow - d) * a * 0.45);
    return over(c, fill, cover(-d) * a);
}

// Pops out past full size and settles, 0..1 over the first `t` of its life.
float pop(float t) {
    float k = clamp(u.age / t, 0.0, 1.0);
    return 1.0 + 2.7 * (k - 1.0) * (k - 1.0) * (k - 1.0) + 1.7 * (k - 1.0) * (k - 1.0);
}

vec4 sparkle(vec2 p, float R) {
    float s = R * pop(0.25) * (1.0 - smoothstep(0.4, 1.0, u.age));
    if (s < 0.5)
        return vec4(0.0);
    vec2 q = abs(rot(p, 0.8 * u.age + u.seed)) / s;
    float d = (sqrt(q.x) + sqrt(q.y) - 1.0) * s * 0.45;
    vec4 c = over(vec4(0.0), u.cFrostLight.rgb, cover(1.2 - d) * 0.8);
    return over(c, u.cSparkle.rgb, cover(-d));
}

// Powdered sugar sifted down from the top of the item: a faint haze where it leaves
// the sieve, and fine grains that fall slowly and spread as they go, each fading as it
// settles, a few catching the light on the way.
vec4 sift(vec2 p, float R) {
    vec4 c = vec4(0.0);
    vec2 hz = p - vec2(0.0, -R * 0.62 + R * 0.35 * u.age);
    float haze = exp(-dot(hz, hz) / (R * R * 0.09)) * 0.2 * (1.0 - smoothstep(0.2, 0.9, u.age));
    c = over(c, u.cCream.rgb, haze);
    float gr = max(0.7, R * 0.036);
    for (int i = 0; i < 34; i++) {
        float fi = float(i);
        vec4 h = vec4(hash(vec2(fi, u.seed)), hash(vec2(fi, u.seed + 1.3)), hash(vec2(fi, u.seed + 2.7)), hash(vec2(fi, u.seed + 4.1)));
        float t = u.age - h.z * 0.35;
        if (t <= 0.0)
            continue;
        float fade = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.35, 0.62, t));
        vec2 g = vec2((h.x - 0.5) * R * 0.45 + (h.y - 0.5) * R * 1.1 * t + R * 0.04 * sin(t * 9.0 + fi),
                      -R * 0.7 + h.w * R * 0.12 + R * mix(1.6, 2.4, h.y) * t);
        float r = gr * mix(0.7, 1.3, h.w);
        c = over(c, mix(u.cCream.rgb, u.cSparkle.rgb, h.x), cover(r - length(p - g)) * fade * 0.9);
        // Now and then a grain glints.
        if (h.w > 0.8) {
            float tw = (1.0 - smoothstep(0.0, 0.1, abs(t - 0.28)));
            vec2 q = abs(p - g) / (r * 4.5 * tw + 1e-3);
            c = over(c, u.cSparkle.rgb, cover((1.0 - sqrt(q.x) - sqrt(q.y)) * r * 2.0) * tw);
        }
    }
    return c;
}

// A grain of sugar, a tiny glinting square, falling and turning.
vec4 grain(vec2 p, float R) {
    float fade = 1.0 - smoothstep(0.5, 1.0, u.age);
    vec2 q = abs(rot(p, u.age * 6.0 + u.seed * 6.0));
    float d = max(q.x, q.y) - R * 0.45;
    vec4 c = over(vec4(0.0), u.cCream.rgb, cover(-d) * fade);
    return over(c, u.cSparkle.rgb, cover(-d - R * 0.2) * step(0.5, fract(u.age * 5.0 + u.seed)) * fade);
}

vec4 puff(vec2 p, float R) {
    float grow = mix(0.3, 1.0, pop(0.3)) * (1.0 - 0.8 * smoothstep(0.4, 1.0, u.age));
    vec2 q = p + vec2(0.0, R * 0.2 * u.age);
    float d = 1e3;
    vec2 lc = vec2(0.0);
    float lr = 1.0;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float a = TAU * (u.seed + fi / 4.0) + 0.6 * hash(vec2(fi, u.seed + 3.0));
        vec2 c = i == 4 ? vec2(0.0) : vec2(cos(a), sin(a) * 0.75) * R * 0.36 * grow;
        float r = R * grow * (i == 4 ? 0.48 : mix(0.28, 0.42, hash(vec2(fi, u.seed))));
        float di = length(q - c) - r;
        if (di < d) {
            d = di;
            lc = c;
            lr = r;
        }
    }
    float lit = dot((q - lc) / lr, vec2(-0.45, -0.9));
    vec3 col = mix(mix(u.cCream.rgb, u.cFrostShade.rgb, 0.3), u.cCream.rgb, band(lit, -0.3));
    col = mix(col, u.cSparkle.rgb, band(lit, 0.55));
    float fade = 1.0 - smoothstep(0.8, 1.0, u.age);
    vec4 c = over(vec4(0.0), col, cover(-d) * 0.9 * fade);
    // Grains dusted round it, drifting out.
    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float a = TAU * hash(vec2(fi, u.seed + 9.0));
        vec2 g = vec2(cos(a), sin(a)) * R * mix(0.5, 0.95, hash(vec2(fi, u.seed + 4.0))) * mix(0.6, 1.0, u.age);
        c = over(c, u.cSparkle.rgb, cover(max(0.6, R * 0.05) * (1.0 - u.age) - length(p - g)) * fade);
    }
    return c;
}

vec4 crumb(vec2 p, float R) {
    float s = 1.0 - smoothstep(0.75, 1.0, u.age);
    if (s < 0.05)
        return vec4(0.0);
    vec2 q = p / s;
    float a = atan(q.y, q.x);
    // Lumpy: a few uneven bumps round its edge.
    float r = R * 0.8 * (1.0 + 0.16 * sin(a * 3.0 + u.seed * 9.0) + 0.1 * sin(a * 5.0 + u.seed * 4.0));
    float d = (length(q) - r) * s;
    vec3 col = mix(u.cSponge.rgb, mix(u.cSponge.rgb, u.cInk.rgb, 0.25), band(q.y, R * 0.15));
    // Air holes in the sponge, and a frosted top on some.
    col = mix(col, mix(u.cSponge.rgb, u.cInk.rgb, 0.4), cover(R * 0.09 - length(q - vec2(R * 0.2, R * 0.1))));
    col = mix(col, mix(u.cSponge.rgb, u.cInk.rgb, 0.4), cover(R * 0.07 - length(q + vec2(R * 0.25, -R * 0.2))));
    if (u.seed > 0.5)
        col = mix(col, u.cFrost.rgb, band(-q.y, R * 0.18));
    return inked(vec4(0.0), d, col, ink(R) * 0.8, 1.0);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.size;
    float R = u.size * 0.5 - 1.0;
    vec4 c = u.kind < 0.5 ? sparkle(p, R) : u.kind < 1.5 ? sift(p, R) : u.kind < 2.5 ? puff(p, R)
           : u.kind < 3.5 ? grain(p, R) : crumb(p, R);
    fragColor = c * u.qt_Opacity;
}
