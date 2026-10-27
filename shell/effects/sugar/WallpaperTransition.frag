#version 440
#extension GL_GOOGLE_include_directive : enable
// A curtain of glaze pouring down over the old wallpaper. Its lower edge runs ahead in
// drips of uneven width and length, each a round-tipped tongue that keeps stretching,
// and drops break off the longest and fall; it is cel-shaded, deeper toward its lower
// edge with a gloss along it. Where its wavy upper edge has passed, the new wallpaper
// shows; it slides off the bottom with the old.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float progress;     // 0..1
    float seed;         // 0..1, new drips each time
    vec4 cInk;
    vec4 cFrost;
    vec4 cFrostLight;
    vec4 cFrostShade;
    vec4 cFilm;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../common/common.glsl"

float H, W, CELL, FRONT, THICK;

// Drip k: (center x, half width, length, when it starts to stretch).
vec4 drip(float k) {
    float s = u.seed * 37.0;
    vec4 h = vec4(hash(vec2(k, s)), hash(vec2(k, s + 1.0)), hash(vec2(k, s + 2.0)), hash(vec2(k, s + 3.0)));
    return vec4((k + 0.25 + 0.5 * h.x) * CELL, CELL * mix(0.2, 0.4, h.y),
                H * mix(0.02, 0.15, h.z * h.z), mix(0.0, 0.35, h.w));
}

float tipOf(vec4 d) {
    return d.z * smoothstep(d.w, d.w + 0.45, u.progress) + d.y;
}

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    W = u.resolution.x;
    H = u.resolution.y;
    CELL = max(60.0, W / 26.0);
    THICK = H * 0.28;
    float t = u.progress;
    // From above the screen to below it, the drips' length past the bottom.
    FRONT = mix(-H * 0.05, H * 1.62 + THICK, pow(t, 1.35));

    // Distance to the lower edge, > 0 below it: the edge's wave joined smoothly to
    // the drips' tongues, capsules hanging from it, filleted where they meet.
    float db = p.y - (FRONT + 6.0 * sin(p.x / 70.0 + u.seed * 9.0) + 4.0 * sin(p.x / 23.0));
    float k1 = floor(p.x / CELL);
    for (int j = -1; j <= 1; j++) {
        vec4 d = drip(k1 + float(j));
        float L = tipOf(d);
        float dc = sdSeg(p, vec2(d.x, FRONT - d.y), vec2(d.x, FRONT + L - d.y)) - d.y;
        float k = d.y * 0.7;
        float h = max(k - abs(db - dc), 0.0) / k;
        db = min(db, dc) - h * h * k * 0.25;
    }
    float yt = FRONT - THICK + 18.0 * sin(p.x / 140.0 + u.seed * 5.0) + 8.0 * sin(p.x / 47.0 + 2.0);
    float dt = p.y - yt;                                    // > 0 below the upper edge

    // The old wallpaper, below where the curtain's top has passed, shadowed under it.
    vec4 col = texture(source, p / u.resolution) * cover(dt);
    col.rgb = mix(col.rgb, u.cInk.rgb * col.a, 0.35 * cover(db) * (1.0 - smoothstep(0.0, 10.0, db)));

    // Drops broken off the longest drips, falling.
    float k0 = floor(p.x / CELL);
    for (int j = -1; j <= 1; j++) {
        vec4 d = drip(k0 + float(j));
        if (d.z < H * 0.08)
            continue;
        float t0 = d.w + 0.32;
        float age = t - t0;
        if (age <= 0.0)
            continue;
        float tipY = FRONT + tipOf(d);
        float y = tipY + 3.5 * H * age * age + d.y * 0.6;
        vec2 q = p - vec2(d.x, y);
        // A teardrop, pointed up, stretched as it falls.
        float r = d.y * 0.42;
        float dd = length(q * vec2(1.0, 0.85)) - r;
        dd = min(dd, max(length(vec2(q.x * 2.2, 0.0)) - r * (0.8 + q.y / r * 0.5), max(-q.y - r * 1.8, q.y)));
        vec4 b = over(vec4(0.0), u.cFrostShade.rgb * 0.7, 0.7 * cover(1.2 - dd));
        b = over(b, mix(u.cFrost.rgb, u.cFrostShade.rgb, band(q.x, r * 0.2)), cover(-dd));
        b = over(b, u.cFilm.rgb, cover(r * 0.18 - length(q + vec2(r * 0.35, r * 0.25))));
        col = b + col * (1.0 - b.a);
    }

    // The curtain.
    float inside = cover(-db) * cover(dt);
    if (inside > 0.0 || (db < 3.0 && dt > -3.0)) {
        vec3 g = mix(u.cFrostLight.rgb, u.cFrost.rgb, band(dt, 26.0));
        g = mix(g, u.cFrostShade.rgb, band(db, -14.0));
        // Streaks running down it with the pour.
        float st = vnoise(vec2(p.x / 22.0, (p.y - FRONT) / 260.0 + u.seed * 7.0));
        g = mix(g, u.cFrostLight.rgb, 0.4 * band(st, 0.74) * band(dt, 26.0) * (1.0 - band(db, -14.0)));
        g = mix(g, u.cFrostShade.rgb, 0.3 * (1.0 - band(st, 0.22)) * band(dt, 26.0));
        // A gloss along the lower edge, broken into strokes.
        float gl = cover(2.2 - abs(db + 9.0)) * step(fract(p.x / 130.0 + u.seed), 0.7);
        g = mix(g, u.cFilm.rgb, 0.9 * gl);
        g = mix(g, u.cFilm.rgb, 0.7 * cover(1.6 - abs(dt - 9.0)) * step(fract(p.x / 170.0 + 0.3), 0.55));
        vec4 c = over(vec4(0.0), u.cFrostShade.rgb * 0.7, 0.7 * cover(1.5 - abs(db)) * cover(dt + 1.5));
        c = over(c, u.cFrostShade.rgb * 0.7, 0.7 * cover(1.5 - abs(dt)) * cover(-db + 1.5));
        c = over(c, g, inside);
        col = c + col * (1.0 - c.a);
    }

    fragColor = col * u.qt_Opacity;
}
