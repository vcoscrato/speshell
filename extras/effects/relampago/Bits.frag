#version 440
#extension GL_GOOGLE_include_directive : enable
// One particle of Relâmpago's small effects, by `kind`: 0 a spark, a hot streak
// along its flight (the item turns with it); 1 a puff of tire smoke, billowing and
// thinning; 2 a burst, jagged rays of electricity crackling out from the middle;
// 3 a strike, a forked bolt from the item's top down to its middle, landing in a
// burst (turn the item to strike from another side); 4 an arc, a bolt flickering
// along the item's x axis (the item turns with its flight).
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
    vec4 cGlow;
    vec4 cEdge;
    vec4 cRubber;
    vec4 cSmoke;
    vec4 cSmokeShade;
} u;
#include "../../lib/common.glsl"

vec4 spark(vec2 p, float R) {
    // A streak from its tail (-R) to its head, shortening as it cools.
    float len = R * (1.6 - 0.9 * u.age);
    float t = (p.x + R) / len;                   // 0 tail .. 1 head
    if (t < 0.0 || t > 1.0)
        return vec4(0.0);
    float w = (0.4 + 1.2 * t) * (1.0 - 0.5 * u.age);
    float d = abs(p.y);
    float fade = 1.0 - smoothstep(0.6, 1.0, u.age);
    vec3 col = mix(u.cEdge.rgb, u.cGlow.rgb, smoothstep(0.2, 0.7, t));
    col = mix(col, u.cCore.rgb, smoothstep(0.75, 0.95, t) * (1.0 - u.age));
    vec4 c = over(vec4(0.0), u.cRubber.rgb, cover(w + 0.9 - d) * 0.45 * fade);
    return over(c, col, cover(w - d + 0.3) * fade);
}

vec4 smoke(vec2 p, float R) {
    float grow = 0.45 + 0.55 * (1.0 - pow(1.0 - u.age, 2.0));
    float fade = (1.0 - u.age) * (1.0 - u.age) * smoothstep(0.0, 0.08, u.age);
    // Three lumps, heaped and lit from above.
    float d = 1e3, lit = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float a = 6.2831853 * (u.seed + fi / 3.0);
        vec2 c = vec2(cos(a), sin(a)) * R * 0.32 * grow;
        float r = R * grow * mix(0.45, 0.62, hash(vec2(fi, u.seed)));
        float di = length(p - c) - r;
        if (di < d) {
            d = di;
            lit = dot((p - c) / r, vec2(-0.45, -0.9));
        }
    }
    vec3 col = mix(u.cSmokeShade.rgb, u.cSmoke.rgb, band(lit, 0.1));
    return over(vec4(0.0), col, cover(-d) * 0.75 * fade);
}

// A jagged channel down the item's y axis from y0 to y1 at x(y), two octaves of
// kinks; returns its distance from p.
float channel(vec2 p, float y0, float y1, float amp, float seed) {
    if (p.y < y0 || p.y > y1)
        return 1e3;
    float L = y1 - y0;
    float x = amp * (zig(p.y / (L * 0.22), seed) + 0.32 * zig(p.y / (L * 0.07), seed + 3.0));
    float x2 = amp * (zig((p.y + 1.0) / (L * 0.22), seed) + 0.32 * zig((p.y + 1.0) / (L * 0.07), seed + 3.0));
    return abs(p.x - x) / sqrt(1.0 + (x2 - x) * (x2 - x));
}

// A bolt's glow, color, and core over `under`, for a channel at distance d.
vec4 boltOver(vec4 under, float d, float w, float on) {
    vec4 c = over(under, u.cEdge.rgb, cover(w + 4.0 - d) * 0.4 * on);
    c = over(c, u.cGlow.rgb, cover(w + 1.6 - d) * on);
    return over(c, u.cCore.rgb, cover(w * 0.6 - d) * on);
}

// Flickers off and on as it dies.
float flicker(float fadeFrom, float fadeTo) {
    return step(0.3, hash(vec2(floor(u.age * 20.0), u.seed))) * (1.0 - smoothstep(fadeFrom, fadeTo, u.age))
         + step(u.age, 0.12);
}

vec4 burst(vec2 p, float R) {
    // A discharge: jagged rays crackling out from the middle, re-forking as it flickers.
    float on = min(1.0, flicker(0.4, 0.8));
    float slot = floor(u.age * 20.0);
    float r = length(p);
    float a = atan(p.y, p.x);
    float reach = R * (0.55 + 0.45 * smoothstep(0.0, 0.15, u.age));
    float n = 6.0;
    float k = floor(a / 6.2831853 * n + 0.5);
    float ra = (k + 0.35 * (hash(vec2(k, u.seed + slot)) - 0.5)) * 6.2831853 / n;
    float wig = R * 0.12 * zig(r / (R * 0.18), k + u.seed * 13.0 + slot) * smoothstep(0.0, R * 0.3, r);
    vec2 dir = vec2(cos(ra), sin(ra));
    float d = abs(dot(p, vec2(-dir.y, dir.x)) - wig);
    float along = dot(p, dir);
    float len = reach * mix(0.55, 1.0, hash(vec2(k, u.seed + 7.0)));
    vec4 c = vec4(0.0);
    if (along > 0.0 && along < len)
        c = boltOver(c, d, 1.2 * (1.0 - along / len) + 0.3, on);
    return over(c, u.cCore.rgb, cover(R * 0.16 * (1.0 - u.age) - r) * on);
}

vec4 strike(vec2 p, float R) {
    // Strikes down from the top to the middle in an instant, forks, and flickers out;
    // where it lands, a burst.
    float tip = -R + R * smoothstep(0.0, 0.08, u.age);
    if (p.y > tip + R * 0.3)
        return vec4(0.0);
    float on = min(1.0, flicker(0.45, 0.75));
    vec4 c = vec4(0.0);
    float d = channel(p, -R, tip, R * 0.28, u.seed * 10.0);
    // Two forks off the main channel, partway down.
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        float y0 = -R + R * (0.25 + 0.3 * fi + 0.1 * hash(vec2(fi, u.seed)));
        if (tip < y0)
            continue;
        float side = (hash(vec2(fi, u.seed + 2.0)) < 0.5 ? -1.0 : 1.0);
        float x0 = R * 0.28 * (zig(y0 / (R * 0.44), u.seed * 10.0) + 0.32 * zig(y0 / (R * 0.14), u.seed * 10.0 + 3.0));
        vec2 f = p - vec2(x0, y0);
        f = mat2(0.8, side * 0.6, -side * 0.6, 0.8) * f;
        float len = R * mix(0.25, 0.45, hash(vec2(fi, u.seed + 4.0)));
        float df = channel(f, 0.0, len, R * 0.1, u.seed * 10.0 + 9.0 + fi) + 0.6 * f.y / len;
        d = min(d, df);
    }
    float w = 1.3 + min(R * 0.01, 1.2);
    c = boltOver(c, d, w, on);
    // The landing: a hot spot with short rays.
    if (u.age > 0.07) {
        float r = length(p);
        float a = atan(p.y, p.x);
        float rays = 0.5 + 0.5 * cos(a * 7.0 + u.seed * 20.0);
        float hot = min(R * 0.1, 7.0) * (1.0 - u.age);
        float land = cover(hot * (0.6 + 0.8 * rays) - r);
        c = over(c, u.cGlow.rgb, cover(hot * 1.6 - r) * 0.5 * on);
        c = over(c, u.cCore.rgb, land * on);
    }
    return c;
}

vec4 arc(vec2 p, float R) {
    // An arc of electricity along the item's x axis, jumping between kinks that
    // re-roll as it flickers, thinning toward its tail (-R).
    float on = min(1.0, flicker(0.3, 0.7));
    float slot = floor(u.age * 20.0);
    vec2 q = vec2(p.y, p.x);
    float d = channel(q, -R, R, R * 0.35 * (1.0 - u.age * 0.5), u.seed * 10.0 + slot);
    float t = (p.x + R) / (2.0 * R);
    return boltOver(vec4(0.0), d, 0.4 + 1.0 * t, on * smoothstep(0.0, 0.2, t));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.size;
    float R = u.size * 0.5 - 1.0;
    vec4 c = u.kind < 0.5 ? spark(p, R) : u.kind < 1.5 ? smoke(p, R) : u.kind < 2.5 ? burst(p, R)
           : u.kind < 3.5 ? strike(p, R) : arc(p, R);
    fragColor = c * u.qt_Opacity;
}
