#version 440
#extension GL_GOOGLE_include_directive : enable
// One particle of Air's control effects, by `kind`: 0 a wisp of wind, a bent stroke
// that streams out and blows away along its path (the item turns with it); 1 a leaf,
// tumbling; 2 a curl of wind, arms spiralling out around a point; 3 a speck of dust;
// 4 a streak of wind, long and thin, blowing past a slider's knob.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float age;          // 0..1 over its life
    float seed;
    float kind;
    float size;         // px across
    vec4 cWind;
    vec4 cLeaf;
    vec4 cLeafBack;
    vec4 cOutline;
} u;
#include "../../lib/common.glsl"

vec4 wisp(vec2 p, float R) {
    float bend = (hash(vec2(u.seed, 1.0)) - 0.5) * 0.9;
    // Along the stroke from its tail (-R) to its head (R); the visible piece streams out
    // ahead, then the tail catches up.
    float t = (p.x + R) / (2.0 * R);
    float head = min(1.0, 0.25 + u.age * 2.2), tail = max(0.0, u.age * 1.3 - 0.3);
    float along = (t - tail) / max(head - tail, 0.01);
    if (along < 0.0 || along > 1.0)
        return vec4(0.0);
    float cy = bend * (p.x * p.x / R - R * 0.35);
    float w = 0.6 + 1.7 * sin(3.1415927 * along) * along;
    float dist = abs(p.y - cy);
    float fade = (0.55 + 0.45 * along) * (1.0 - u.age * u.age);
    // Outlined, as Air's strokes are, so it reads on light and dark alike.
    vec4 c = over(vec4(0.0), u.cOutline.rgb, cover(w + 1.1 - dist) * fade * 0.7);
    return over(c, u.cWind.rgb, cover(w - dist + 0.3) * fade);
}

vec4 leaf(vec2 p, float R) {
    float flip = cos(u.age * mix(14.0, 26.0, u.seed) + u.seed * 20.0);
    vec2 q = p;
    q.x /= max(abs(flip), 0.22);
    float L = R * 0.9;
    float d = sdLeaf(q, L, L * 0.62);
    float rib = cover(0.5 - abs(q.x)) * step(abs(q.y), L * 0.7);
    vec3 face = flip > 0.0 ? u.cLeaf.rgb : u.cLeafBack.rgb;
    vec4 c = over(vec4(0.0), u.cOutline.rgb, cover(0.9 - d));
    c = over(c, mix(face, u.cOutline.rgb, 0.4 * rib), cover(-d));
    return c * (1.0 - smoothstep(0.8, 1.0, u.age));
}

vec4 eddy(vec2 p, float R) {
    float grow = 1.0 - pow(1.0 - u.age, 2.0);
    float r = length(p);
    float a = atan(p.y, p.x);
    vec4 c = vec4(0.0);
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float spin = a - fi * 2.0943951 - u.age * 5.0 - u.seed * 6.0;
        float th = mod(spin, 6.2831853);                    // along the arm, 0 at its head
        float rs = R * grow * (0.95 - 0.09 * th) * (0.85 + 0.15 * hash(vec2(fi, u.seed)));
        float len = 3.2 * (1.0 - 0.4 * u.age);
        if (th > len || rs < 2.0)
            continue;
        float along = 1.0 - th / len;                       // 1 at its head
        float w = 0.8 + 1.8 * along * (1.0 - along * 0.5);
        float fade = (0.6 + 0.4 * along) * (1.0 - u.age * u.age);
        c = over(c, u.cOutline.rgb, cover(w + 1.1 - abs(r - rs)) * fade * 0.7);
        c = over(c, u.cWind.rgb, cover(w - abs(r - rs)) * fade);
    }
    return c;
}

vec4 speck(vec2 p, float R) {
    vec4 c = over(vec4(0.0), u.cOutline.rgb, cover(R * 0.5 + 0.8 - length(p)) * 0.6 * (1.0 - u.age));
    return over(c, u.cWind.rgb, cover(R * 0.5 - length(p)) * 0.85 * (1.0 - u.age));
}

// A streak of wind: a long thin line with a slow wave that streams in head first and
// thins away tail first.
vec4 streak(vec2 p, float R) {
    float t = (p.x + R) / (2.0 * R);
    float head = min(1.0, 0.35 + u.age * 2.4), tail = max(0.0, u.age * 1.7 - 0.6);
    float along = (t - tail) / max(head - tail, 0.01);
    if (along < 0.0 || along > 1.0)
        return vec4(0.0);
    float cy = R * 0.05 * sin(t * 7.0 + u.seed * 40.0 - u.age * 9.0);
    float w = 0.3 + 1.0 * pow(sin(3.1415927 * along), 0.7) * (0.35 + 0.65 * along);
    float d = abs(p.y - cy);
    float fade = smoothstep(0.0, 0.12, u.age) * (1.0 - u.age * u.age);
    vec4 c = over(vec4(0.0), u.cOutline.rgb, cover(w + 1.0 - d) * fade * 0.5);
    return over(c, u.cWind.rgb, cover(w - d + 0.3) * fade * 0.9);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.size;
    float R = u.size * 0.5 - 1.0;
    vec4 c = u.kind < 0.5 ? wisp(p, R) : u.kind < 1.5 ? leaf(p, R) : u.kind < 2.5 ? eddy(p, R)
           : u.kind < 3.5 ? speck(p, R) : streak(p, R);
    fragColor = c * u.qt_Opacity;
}
