#version 440
#extension GL_GOOGLE_include_directive : enable
// One particle of Fire's control effects, by `kind`: 0 a tongue of flame, swaying and
// shrinking as it burns out; 1 a spark streaking along its path (the item turns with
// it); 2 a puff of smoke; 3 a burning streak on a slider's track, cooling from white
// heat to a dying red; 4 an ember floating up, flickering as it cools; 5 a flash of
// ignition.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float age;          // 0..1 over its life
    float seed;
    float kind;
    float size;         // px across
    vec4 cCore;
    vec4 cMid;
    vec4 cOuter;
    vec4 cEdge;
    vec4 cSmoke;
    vec4 cGlint;
} u;
#include "../common/common.glsl"

// Cel bands of a flame by how deep inside it a point is (0 at the edge, 1 at the heart).
vec4 flameBands(float inside, float edgeDist) {
    vec4 c = over(vec4(0.0), u.cEdge.rgb, cover(edgeDist));
    c = over(c, u.cOuter.rgb, cover(edgeDist - 1.0));
    c = over(c, u.cMid.rgb, band(inside, 0.35));
    return over(c, u.cCore.rgb, band(inside, 0.68));
}

vec4 tongue(vec2 p, float R) {
    float k = pow(1.0 - u.age, 0.6);
    R *= 0.35 + 0.65 * k;
    // Each tongue its own: wider or slimmer, leaning, swaying at its own pace.
    float h1 = hash(vec2(u.seed, 1.0)), h2 = hash(vec2(u.seed, 2.0)), h3 = hash(vec2(u.seed, 3.0));
    float base = R * 0.55, tip = -R * (0.7 + 0.3 * h1);
    float t = clamp((base - p.y) / (base - tip), 0.0, 1.0);    // 0 base .. 1 tip
    float sway = (sin(t * (2.5 + 2.0 * h2) + u.seed * 40.0 + u.age * (10.0 + 8.0 * h3)) * 0.28
                  + (h3 - 0.5) * 0.7 * t) * R * t;
    float rb = R * (0.3 + 0.2 * h2);
    // A round base narrowing to a point.
    float hw = rb * sqrt(clamp(1.0 - t, 0.0, 1.0)) * smoothstep(-0.05, 0.25, t + 0.2);
    float bulb = length(p - vec2(0.0, base - rb)) - rb;
    float body = max(abs(p.x - sway) - hw, tip - p.y);
    float d = p.y > base - rb ? bulb : min(body, bulb);
    float inside = clamp(-d / max(rb * (1.0 - t * 0.6), 1.0), 0.0, 1.0);
    return flameBands(inside, -d) * (1.0 - smoothstep(0.8, 1.0, u.age));
}

vec4 spark(vec2 p, float R) {
    float len = R * (0.9 - 0.6 * u.age);
    float d = length(vec2(max(abs(p.x + len * 0.4) - len * 0.6, 0.0), p.y)) - 0.9;
    vec3 col = u.age < 0.35 ? u.cCore.rgb : u.age < 0.7 ? u.cMid.rgb : u.cOuter.rgb;
    return vec4(col, 1.0) * cover(-d) * (1.0 - smoothstep(0.7, 1.0, u.age));
}

vec4 smoke(vec2 p, float R) {
    float grow = 0.45 + 0.55 * sqrt(u.age);
    float d = 1e9;
    for (int i = 0; i < 4; i++) {
        vec2 o = (hash2(vec2(u.seed, float(i))) - 0.5) * R * 0.9;
        d = min(d, length(p - o) - R * grow * (0.36 + 0.22 * hash(vec2(float(i), u.seed))));
    }
    d += (vnoise(p / 3.0 + u.seed * 40.0) - 0.5) * 3.0;
    float fade = pow(1.0 - u.age, 1.4);
    vec4 c = over(vec4(0.0), u.cSmoke.rgb, cover(-d) * 0.4 * fade);
    return over(c, mix(u.cSmoke.rgb, u.cGlint.rgb, 0.15), cover(-d - R * 0.25) * 0.25 * fade);
}

vec4 scorch(vec2 p, float R) {
    float heat = 1.0 - u.age;
    // A flat ember, ragged along its length, thinning as it cools.
    float hh = (1.2 + 1.6 * heat) * (0.75 + 0.5 * vnoise(vec2(p.x / 3.0 + u.seed * 50.0, u.age * 4.0)));
    float d = length(vec2(max(abs(p.x) - R * 0.85, 0.0), p.y)) - hh;
    vec3 col = heat > 0.8 ? u.cCore.rgb : heat > 0.55 ? u.cMid.rgb : heat > 0.3 ? u.cOuter.rgb : u.cEdge.rgb;
    float fade = 1.0 - smoothstep(0.65, 1.0, u.age);
    vec4 c = over(vec4(0.0), u.cOuter.rgb, cover(3.0 - d) * 0.3 * heat * fade);
    return over(c, col, cover(-d) * fade);
}

vec3 heatColor(float heat) {
    return heat > 0.75 ? u.cCore.rgb : heat > 0.5 ? u.cMid.rgb : heat > 0.25 ? u.cOuter.rgb : u.cEdge.rgb;
}

vec4 ember(vec2 p, float R) {
    float heat = 1.0 - u.age;
    // Drifting side to side as it rises.
    p.x -= sin(u.age * (9.0 + 6.0 * u.seed) + u.seed * 30.0) * R * 0.45;
    float flick = 0.7 + 0.3 * sin(u.age * 45.0 + u.seed * 60.0);
    float r = R * 0.28 * (0.6 + 0.4 * heat) * flick;
    float d = length(p);
    vec4 c = over(vec4(0.0), u.cOuter.rgb, cover(r * 2.6 - d) * 0.3 * heat);
    return over(c, heatColor(heat * flick + 0.1), cover(r - d)) * (1.0 - smoothstep(0.75, 1.0, u.age));
}

vec4 flash(vec2 p, float R) {
    float k = sin(3.1415927 * pow(u.age, 0.45));
    float a = atan(p.y, p.x);
    // A ragged blob of flame, licking upward, not a ring.
    float lick = 0.55 + 0.45 * vnoise(vec2(a * 2.2 + u.seed * 40.0, u.age * 5.0)) + 0.35 * max(0.0, -p.y / max(length(p), 1.0));
    float d = length(p) - R * k * lick;
    float inside = clamp(-d / max(R * k * 0.6, 1.0), 0.0, 1.0);
    return flameBands(inside, -d) * k;
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.size;
    float R = u.size * 0.5 - 1.0;
    vec4 c = u.kind < 0.5 ? tongue(p, R) : u.kind < 1.5 ? spark(p, R) : u.kind < 2.5 ? smoke(p, R)
        : u.kind < 3.5 ? scorch(p, R) : u.kind < 4.5 ? ember(p, R) : flash(p, R);
    fragColor = c * u.qt_Opacity;
}
