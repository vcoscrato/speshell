#version 440
#extension GL_GOOGLE_include_directive : enable
// One particle of Water's control effects, by `kind`: 0 a droplet streaming along its
// path (the item turns with it); 1 a ripple, two rings spreading, flattened by
// `squash` when it lies on a surface; 2 a crown splash, a flattened rim throwing up
// spikes tipped with drops, taller on the side it `lean`s to; 3 the jet that leaps up
// after it, leaning, its top pinching off as a drop.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float age;          // 0..1 over its life
    float seed;
    float kind;
    float size;         // px across
    float squash;       // ripples: height over width
    float arrive;       // drops: 1 to swell in and vanish where they land, 2 to vanish where they land
    float lean;         // crowns and jets: -1..1, the way the drop was going
    vec4 cWater;
    vec4 cLight;
    vec4 cFoam;
    vec4 cDeep;
} u;
#include "../common/common.glsl"

vec4 drop(vec2 p, float R) {
    // Arriving, it stays whole until it lands, swelling in first if it falls from nowhere.
    float k = u.arrive > 0.5 && u.arrive < 1.5 ? smoothstep(0.0, 0.2, u.age) : 1.0;
    p /= max(k, 0.05);
    float r = R * 0.45;
    // A round head with a tail streaming behind it.
    float tail = clamp(-p.x / (R * 0.9), 0.0, 1.0);
    float d = min(length(p - vec2(R * 0.2, 0.0)) - r,
                  max(abs(p.y) - r * (1.0 - tail), max(p.x - R * 0.2, -p.x - R * 0.9)));
    vec4 c = over(vec4(0.0), u.cDeep.rgb, cover(-d));
    c = over(c, u.cWater.rgb, cover(-d - 1.0));
    c = over(c, u.cLight.rgb, cover(-d - 1.0) * band(-p.y, r * 0.25));
    c = over(c, u.cFoam.rgb, cover(r * 0.35 - length(p - vec2(R * 0.3, -r * 0.35))));
    return c * (u.arrive > 0.5 ? step(0.05, k) : 1.0 - smoothstep(0.75, 1.0, u.age));
}

vec4 ripple(vec2 p, float R) {
    p.y /= max(u.squash, 0.1);
    vec4 c = vec4(0.0);
    for (int i = 0; i < 2; i++) {
        float a = clamp(u.age * 1.25 - float(i) * 0.25, 0.0, 1.0);
        float r = R * (0.15 + 0.85 * (1.0 - pow(1.0 - a, 2.0)));
        // Thicker toward the viewer when it lies flat.
        float w = (1.4 - float(i) * 0.4) * (u.squash < 0.9 ? 1.0 + 0.6 * clamp(p.y / r, 0.0, 1.0) : 1.0);
        float ring = cover(w - abs(length(p) - r) / max(1.0, 1.0 / u.squash * 0.5));
        float fade = (1.0 - a) * step(0.001, a);
        c = over(c, mix(u.cFoam.rgb, u.cLight.rgb, float(i)), ring * fade);
    }
    return c;
}

// Water's cel bands for a body with signed inside distance `d` and a highlight where
// `lit` is high.
vec4 waterBody(vec4 c, float d, float lit) {
    c = over(c, u.cDeep.rgb, cover(d + 1.0));
    c = over(c, u.cWater.rgb, cover(d));
    return over(c, u.cLight.rgb, cover(d) * step(0.55, lit));
}

vec4 crown(vec2 p, float R) {
    float rise = sin(3.1415927 * min(1.0, u.age * 1.25));
    float w = R * (0.45 + 0.5 * (1.0 - pow(1.0 - u.age, 2.0)));
    vec2 q = vec2(p.x, p.y / 0.32);
    // The rim, a flat ring seen from the side.
    // Ragged, and thicker where the drop drove into it.
    float a0 = atan(q.y, q.x);
    float rim = abs(length(q) - w * (1.0 + 0.12 * (vnoise(vec2(a0 * 2.0, u.seed * 30.0)) - 0.5))) * 0.32
        - (1.0 + 0.6 * max(0.0, cos(a0) * u.lean)) * (1.0 - u.age);
    float d = -rim;
    // Spikes standing on it, unevenly spaced, each its own height, leaning outward.
    float h = R * 0.8 * rise;
    float count = 7.0 + floor(hash(vec2(u.seed, 9.0)) * 5.0);
    for (int i = 0; i < 11; i++) {
        if (float(i) >= count)
            break;
        float a = (float(i) + (hash(vec2(u.seed, float(i))) - 0.5) * 0.8) / count * 6.2831853;
        float side = 1.0 + 0.6 * cos(a) * u.lean;
        float hi = h * side * (0.25 + 0.75 * pow(hash(vec2(float(i), u.seed)), 0.7));
        vec2 base = vec2(cos(a) * w, sin(a) * w * 0.32);
        float lean = cos(a) * 0.35 + u.lean * 0.15;
        float t = clamp((base.y - p.y) / max(hi, 1.0), 0.0, 1.0);
        vec2 spine = base + vec2(lean * hi * t, -hi * t);
        float sw = 1.6 * (1.0 - t * 0.7);
        d = max(d, sw - length(p - spine));
        // The drop at its tip, coming away as it falls.
        vec2 tip = base + vec2(lean * hi * 1.15, -hi * 1.1);
        d = max(d, 1.7 - length(p - tip));
    }
    float fade = 1.0 - smoothstep(0.7, 1.0, u.age);
    return waterBody(vec4(0.0), d, -p.y / max(h, 1.0) - p.x / R * 0.4) * fade;
}

vec4 jet(vec2 p, float R) {
    float base = R * 0.9;
    float up = sin(3.1415927 * min(1.0, u.age * 1.1));
    float top = base - R * 1.2 * up;
    float d = -1e3;
    // The column, wide at its foot.
    float t = clamp((base - p.y) / max(base - top, 1.0), 0.0, 1.0);
    float cw = 2.4 * (1.0 - t * 0.55);
    p.x -= u.lean * (base - p.y) * 0.3;
    if (p.y < base && p.y > top)
        d = cw - abs(p.x);
    // The drop pinched off its top, flying on, then falling back.
    float k = max(0.0, u.age - 0.32);
    vec2 dropAt = vec2(0.0, base - R * 1.2 * up - 4.0 - R * (1.6 * k - 3.2 * k * k));
    d = max(d, 2.4 * step(0.32, u.age) - length(p - dropAt));
    d = max(d, 2.8 - length(p - vec2(0.0, top)));
    return waterBody(vec4(0.0), d, step(p.x, -0.6)) * (1.0 - smoothstep(0.8, 1.0, u.age));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.size;
    float R = u.size * 0.5 - 1.0;
    vec4 c = u.kind < 0.5 ? drop(p, R) : u.kind < 1.5 ? ripple(p, R) : u.kind < 2.5 ? crown(p, R) : jet(p, R);
    fragColor = c * u.qt_Opacity;
}
