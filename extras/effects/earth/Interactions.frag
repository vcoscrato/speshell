#version 440
#extension GL_GOOGLE_include_directive : enable
// One particle of Earth's control effects, by `kind`: 0 a rock chip, faceted and
// outlined, its faces shaded by their normals; 1 a puff of dust; 2 a jade shard.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float age;          // 0..1 over its life
    float seed;
    float kind;
    float size;         // px across
    vec4 cStone;
    vec4 cLight;
    vec4 cShade;
    vec4 cDust;
    vec4 cJade;
    vec4 cGlint;
} u;
#include "../../lib/common.glsl"

const vec2 LIGHT = vec2(-0.55, -0.83);

// A lopsided, faceted stone of radius about R: the top face and the side faces, each
// shaded by where it faces, with a dark outline.
vec4 chip(vec2 p, float R) {
    float d = -1e9;
    vec2 face = vec2(0.0);
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float a = 6.2831853 * (fi + 0.6 * (hash(vec2(u.seed, fi)) - 0.5)) / 6.0;
        vec2 n = vec2(cos(a), sin(a));
        float h = R * (0.62 + 0.38 * hash(vec2(fi, u.seed + 3.0)));
        float e = dot(p, n) - h;
        if (e > d) { d = e; face = n; }
    }
    float top = band(-d, R * 0.38);
    float lit = dot(face, LIGHT);
    vec3 side = lit > 0.35 ? u.cLight.rgb : lit > -0.3 ? u.cStone.rgb : mix(u.cStone.rgb, u.cShade.rgb, 0.55);
    vec3 col = mix(side, mix(u.cStone.rgb, u.cLight.rgb, 0.45), top);
    vec4 c = over(vec4(0.0), u.cShade.rgb, cover(-d));
    return over(c, col, cover(-d - 1.1));
}

vec4 dust(vec2 p, float R) {
    float grow = 0.45 + 0.55 * sqrt(u.age);
    // Lumpy: a few lobes, their edges frayed by noise.
    float d = 1e9;
    for (int i = 0; i < 4; i++) {
        vec2 o = (hash2(vec2(u.seed, float(i))) - 0.5) * R * 0.9;
        float r = R * grow * (0.38 + 0.22 * hash(vec2(float(i), u.seed)));
        d = min(d, length(p - o) - r);
    }
    d += (vnoise(p / 3.0 + u.seed * 40.0) - 0.5) * 3.0;
    float fade = pow(1.0 - u.age, 1.5);
    vec3 dirt = mix(u.cDust.rgb, u.cStone.rgb, 0.5);
    vec4 c = over(vec4(0.0), dirt, cover(-d) * 0.35 * fade);
    return over(c, mix(dirt, u.cLight.rgb, 0.35), cover(-d - R * 0.25) * 0.25 * fade);
}

vec4 shard(vec2 p, float R) {
    float w = R * 0.42;
    float d = max(abs(p.x) - w, abs(p.y) + abs(p.x) * 1.3 - R);
    vec3 col = p.x < 0.0 ? mix(u.cJade.rgb, u.cLight.rgb, 0.35) : mix(u.cJade.rgb, u.cShade.rgb, 0.3);
    col = mix(col, u.cGlint.rgb, 0.6 * cover(0.7 - abs(p.x + w * 0.45)) * step(abs(p.y), R * 0.5));
    vec4 c = over(vec4(0.0), u.cShade.rgb, cover(-d));
    return over(c, col, cover(-d - 1.0));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.size;
    float R = u.size * 0.5 - 1.0;
    vec4 c = u.kind < 0.5 ? chip(p, R) : u.kind < 1.5 ? dust(p, R) : shard(p, R);
    // Solid bits fade out at the end of their life.
    if (u.kind < 0.5 || u.kind > 1.5)
        c *= 1.0 - smoothstep(0.75, 1.0, u.age);
    fragColor = c * u.qt_Opacity;
}
