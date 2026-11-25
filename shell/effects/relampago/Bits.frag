#version 440
#extension GL_GOOGLE_include_directive : enable
// One particle of Relâmpago's small effects, by `kind`, each drawn like a cartoon,
// flat and outlined in rubber: 0 a spark, a fat teardrop along its flight (the item
// turns with it); 1 a puff of tire smoke, lumps that swell, rise, drift apart, and
// shrink away; 2 a starburst, a spiky comic impact that pops out and shrinks; 3 a
// strike, a jagged forked bolt from the item's top down to its middle, landing in a
// little starburst (turn the item to strike from another side); 4 an arc, a zigzag
// flickering along the item's x axis (the item turns with its flight); 5 a glint, a
// four-pointed twinkle; 6 a strike that lands bare, for a caller that draws its own
// impact.
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
    vec4 cPaint;
    vec4 cRubber;
    vec4 cSmoke;
    vec4 cSmokeShade;
} u;
#include "../common/common.glsl"

// The outline's width for a particle of radius R.
float ink(float R) {
    return clamp(R * 0.045, 1.0, 3.5);
}

// A shape at signed distance d (< 0 inside), filled and outlined.
vec4 inked(vec4 under, float d, vec3 fill, float ow, float a) {
    vec4 c = over(under, u.cRubber.rgb, cover(ow - d) * a);
    return over(c, fill, cover(-d) * a);
}

// Pops out past full size and settles, 0..1 over the first `t` of its life.
float pop(float t) {
    float k = clamp(u.age / t, 0.0, 1.0);
    return 1.0 + 2.7 * (k - 1.0) * (k - 1.0) * (k - 1.0) + 1.7 * (k - 1.0) * (k - 1.0);
}

vec4 spark(vec2 p, float R) {
    // A teardrop from its tail (-R) to its round head, shortening as it cools.
    float shrink = 1.0 - smoothstep(0.55, 1.0, u.age);
    float xh = R * (0.55 - 0.5 * u.age);
    float xt = -R;
    float t = clamp((p.x - xt) / (xh - xt), 0.0, 1.0);
    float w = max(1.4, R * 0.2) * shrink;
    float d = length(p - vec2(mix(xt, xh, t), 0.0)) - mix(0.25, w, t * t * (3.0 - 2.0 * t));
    if (w < 0.2)
        return vec4(0.0);
    vec3 col = mix(u.cEdge.rgb, u.cGlow.rgb, smoothstep(0.25, 0.6, t));
    col = mix(col, u.cCore.rgb, step(0.82, t) * (1.0 - u.age));
    return inked(vec4(0.0), d, col, ink(R) * 0.9, 1.0);
}

vec4 smoke(vec2 p, float R) {
    // A cartoon puff: lumps heaped round a bigger middle one swell out and rise, then
    // drift apart and shrink away each at its own time, lit from above in flat tones
    // and outlined in a darker smoke, so it billows rather than sits like a stone.
    float grow = mix(0.35, 1.0, pop(0.4));
    vec2 q = p + vec2(0.0, R * 0.22 * u.age);
    float apart = 0.2 * smoothstep(0.35, 1.0, u.age);
    float d = 1e3;
    vec2 lc = vec2(0.0);
    float lr = 1.0;
    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        vec2 h = hash2(vec2(fi, u.seed * 13.0));
        float a = TAU * (u.seed + fi / 6.0) + 0.8 * (h.x - 0.5);
        vec2 c = i == 6 ? vec2(0.0, -R * 0.05) : vec2(cos(a), sin(a) * 0.72) * R * (mix(0.3, 0.42, h.y) + apart) * grow;
        float r = R * grow * (i == 6 ? 0.42 : mix(0.2, 0.32, h.y))
                * (1.0 - smoothstep(mix(0.5, 0.85, h.x), 1.0, u.age));
        float di = length(q - c) - r;
        if (di < d) {
            d = di;
            lc = c;
            lr = max(r, 1.0);
        }
    }
    if (d > ink(R) * 1.5)
        return vec4(0.0);
    float lit = dot((q - lc) / lr, vec2(-0.4, -0.92));
    vec3 col = mix(mix(u.cSmokeShade.rgb, u.cSmoke.rgb, 0.4), u.cSmoke.rgb, band(lit, -0.3));
    col = mix(col, mix(u.cSmoke.rgb, u.cCore.rgb, 0.4), band(lit, 0.55));
    vec4 c = over(vec4(0.0), mix(u.cSmokeShade.rgb, u.cRubber.rgb, 0.45), cover(ink(R) * 0.8 - d));
    return over(c, col, cover(-d)) * 0.94;
}

// Signed distance to a star of n spikes, valleys at radius ri, each spike reaching an
// uneven radius from ro * 0.7 to ro.
float starDist(vec2 p, float n, float ri, float ro, float seed) {
    float a = atan(p.y, p.x) / TAU * n;
    float k = floor(a);
    float d = 1e3;
    float inside = 0.0;
    for (int j = -1; j <= 1; j++) {
        float c = k + float(j);
        float v0 = c * TAU / n, v1 = (c + 1.0) * TAU / n, vt = (c + 0.5) * TAU / n;
        float rt = ro * mix(0.7, 1.0, hash(vec2(mod(c, n), seed)));
        vec2 a0 = vec2(cos(v0), sin(v0)) * ri;
        vec2 a1 = vec2(cos(v1), sin(v1)) * ri;
        vec2 tip = vec2(cos(vt), sin(vt)) * rt;
        d = min(d, min(sdSeg(p, a0, tip), sdSeg(p, tip, a1)));
        if (j == 0) {
            // Inside this spike's sector when on the inner side of both its edges.
            vec2 e0 = tip - a0, e1 = a1 - tip;
            float s0 = e0.x * (p.y - a0.y) - e0.y * (p.x - a0.x);
            float s1 = e1.x * (p.y - tip.y) - e1.y * (p.x - tip.x);
            inside = (s0 > 0.0 && s1 > 0.0) || length(p) < ri ? 1.0 : 0.0;
        }
    }
    return inside > 0.5 ? -d : d;
}

// A comic impact: a red star of spikes, a yellow one inside it turned half a spike,
// and a hot core, popping out and shrinking away.
vec4 starburst(vec2 p, float R, float age, float seed) {
    float s = mix(0.2, 1.0, pop(0.18)) * (1.0 - smoothstep(0.55, 1.0, age));
    if (s < 0.02)
        return vec4(0.0);
    float n = R > 40.0 ? 11.0 : 8.0;
    vec2 q = rot(p, 0.25 * age + seed * 6.0) / s;
    float d0 = starDist(q, n, R * 0.5, R * 0.98, seed);
    float d1 = starDist(rot(q, 0.5 * TAU / n), n, R * 0.34, R * 0.7, seed + 1.0);
    float d2 = starDist(q, n, R * 0.18, R * 0.36, seed + 2.0);
    vec4 c = inked(vec4(0.0), d0 * s, u.cPaint.rgb, ink(R), 1.0);
    c = over(c, u.cGlow.rgb, cover(-d1 * s));
    return over(c, u.cCore.rgb, cover(-d2 * s));
}

// Corner i of n of a cartoon bolt from (0, y0) down to (0, y1): at uneven heights,
// kicked out by uneven amounts up to `amp`, mostly by turns left and right but now
// and then twice the same way, and leaning off to one side as it falls.
vec2 boltKink(float i, float y0, float y1, float amp, float seed, float n) {
    if (i < 0.5 || i > n - 0.5)
        return vec2(0.0, i < 0.5 ? y0 : y1);
    float f = (i + 0.4 * (hash(vec2(i, seed + 1.0)) - 0.5)) / n;
    float side = (mod(i + floor(seed * 2.0), 2.0) * 2.0 - 1.0) * (hash(vec2(i, seed + 2.0)) < 0.2 ? -1.0 : 1.0);
    float lean = (hash(vec2(seed, 9.0)) - 0.5) * amp * 1.4 * sin(PI * f);
    return vec2(side * amp * mix(0.3, 1.0, hash(vec2(i, seed))) + lean, mix(y0, y1, f));
}

// Distance to a cartoon bolt of n runs (up to 8) between boltKink's corners, its
// stroke tapering from w0 at the top to w1 at the bottom.
float bolt(vec2 p, float y0, float y1, float amp, float w0, float w1, float seed, float n) {
    float d = 1e3;
    vec2 prev = vec2(0.0, y0);
    for (int i = 1; i <= 8; i++) {
        float fi = float(i);
        if (fi > n)
            break;
        vec2 cur = boltKink(fi, y0, y1, amp, seed, n);
        vec2 pa = p - prev, ba = cur - prev;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        float t = (mix(prev.y, cur.y, h) - y0) / (y1 - y0);
        d = min(d, length(pa - ba * h) - mix(w0, w1, t));
        prev = cur;
    }
    return d;
}

// A bolt at distance d: the rubber outline, yellow, and a hot core.
vec4 boltOver(vec4 under, float d, float ow, float w, float on) {
    vec4 c = over(under, u.cRubber.rgb, cover(ow - d) * on);
    c = over(c, u.cGlow.rgb, cover(-d) * on);
    return over(c, u.cCore.rgb, cover(-d - w * 0.55) * on);
}

// Blinks twice as it dies.
float flicker(float fadeFrom, float fadeTo) {
    float k = (u.age - fadeFrom) / (fadeTo - fadeFrom);
    return step(u.age, fadeFrom) + step(fadeFrom, u.age) * step(k, 1.0) * step(0.5, fract(k * 2.0 + 0.25));
}

vec4 strike(vec2 p, float R, bool burst) {
    // Strikes down from the top in an instant, holds, and blinks out; where it lands,
    // spikes flare up round the middle. The bolt stops short of the middle, which the
    // spikes leave hollow, and they shrink away to the sides and below, so what was
    // picked and the line it is on stay readable under them. Bare, it reaches the
    // middle and lands without them.
    float hole = burst ? min(R * 0.3, 20.0) * 0.55 : 0.0;
    float tip = -R + (R - hole) * smoothstep(0.0, 0.07, u.age);
    float n = R > 90.0 ? 8.0 : 5.0;
    float amp = R * (R > 90.0 ? 0.05 : 0.09);
    if (length(p) > min(R * 0.3, 20.0) * 2.3 && (p.y > tip + R * 0.3 || abs(p.x) > R * 0.62))
        return vec4(0.0);
    float on = flicker(0.36, 0.7);
    float w0 = clamp(R * 0.045, 1.5, 6.5);
    float ow = ink(R);
    float seed = u.seed * 10.0;
    float d = bolt(p, -R, 0.0, amp, w0, w0 * 0.3, seed, n);
    // Out of nothing at the top, rather than cut off by the item's edge.
    d += 1.3 * (w0 + ow) * (1.0 - smoothstep(-R * 0.97, -R * 0.75, p.y));
    // A short fork off one of its upper corners and, on a long one, another lower
    // down, thin, kinked, splaying out the way the bolt kicked there, steeper than it,
    // and tapering to points.
    for (int i = 0; i < 2; i++) {
        float k = floor(mix(2.0, 3.99, hash(vec2(seed, 4.0)))) + 3.0 * float(i);
        if (k > n - 2.0)
            break;
        vec2 f0 = boltKink(k, -R, 0.0, amp, seed, n);
        float side = f0.x < boltKink(k - 1.0, -R, 0.0, amp, seed, n).x ? -1.0 : 1.0;
        float a = mix(0.75, 1.05, hash(vec2(seed, k + 2.0)));
        float c = cos(a), s = side * sin(a);
        vec2 f = mat2(c, s, -s, c) * (p - f0);
        float fl = R * mix(0.16, 0.26, hash(vec2(seed, k)));
        d = min(d, bolt(f, 0.0, fl, fl * 0.18, w0 * 0.45, 0.2, seed + 7.0 + k, 3.0));
    }
    d = max(d, p.y - tip);
    vec4 c = boltOver(vec4(0.0), d, ow, w0, on);
    if (burst && u.age > 0.06) {
        float k = clamp((u.age - 0.06) / 0.5, 0.0, 1.0);
        float up = mix(0.45, 1.0, smoothstep(1.7, 0.6, abs(atan(p.x, -p.y))));
        vec4 s = starburst(p / up, min(R * 0.3, 20.0), k, u.seed + 3.0);
        // Hollow, inked round its hole.
        float l = length(p);
        s = over(s * cover(l - hole), u.cRubber.rgb, cover(ink(R) * 0.5 - abs(l - hole)) * step(0.01, s.a));
        c = s + c * (1.0 - s.a);
    }
    return c;
}

vec4 arc(vec2 p, float R) {
    // A zigzag along the item's x axis, its kinks re-rolling as it flickers,
    // thinning toward its tail (-R).
    float on = flicker(0.3, 0.75);
    float slot = floor(u.age * 14.0);
    vec2 q = vec2(p.y, p.x);
    float w = clamp(R * 0.08, 1.0, 2.4) * (1.0 - 0.4 * u.age);
    float d = bolt(q, -R, R, R * 0.28, 0.3, w, u.seed * 10.0 + slot, 4.0);
    return boltOver(vec4(0.0), d, ink(R) * 0.8, w, on);
}

vec4 glint(vec2 p, float R) {
    // A four-pointed twinkle with concave sides, popping out and shrinking.
    float s = R * pop(0.25) * (1.0 - smoothstep(0.4, 1.0, u.age));
    if (s < 0.5)
        return vec4(0.0);
    vec2 q = abs(rot(p, 0.6 * u.age)) / s;
    float f = sqrt(q.x) + sqrt(q.y) - 1.0;
    float d = f * s * 0.45;
    vec4 c = over(vec4(0.0), u.cGlow.rgb, cover(1.2 - d));
    return over(c, u.cCore.rgb, cover(-d));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.size;
    float R = u.size * 0.5 - 1.0;
    vec4 c = u.kind < 0.5 ? spark(p, R) : u.kind < 1.5 ? smoke(p, R) : u.kind < 2.5 ? starburst(p, R, u.age, u.seed)
           : u.kind < 3.5 ? strike(p, R, true) : u.kind < 4.5 ? arc(p, R) : u.kind < 5.5 ? glint(p, R)
           : strike(p, R, false);
    fragColor = c * u.qt_Opacity;
}
