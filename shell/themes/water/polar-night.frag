#version 440
#extension GL_GOOGLE_include_directive : enable
// Polar night: an aurora hangs its curtains over moonlit glacier peaks, its hem
// glowing and its rays rising and fading, brightest where it folds, and mirrored
// in a still polar sea where the moon lays a broken path of glints. An ice town
// of domes and a slender tower glows warm on the far shore, its lamps trailing
// across the water from a wooden pier; lopsided icebergs drift, a canoe carries
// a lantern home, and snow falls over drifted banks in the foreground.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
} u;
#include "../../effects/common/common.glsl"
#include "../landscape.glsl"

const float HORIZON = 0.34;
const vec3 LAMP = vec3(1.0, 0.76, 0.46);

// A lamp's glow at distance d: two flat rings of warm light added to col, r the outer one.
vec3 glow(vec3 col, float d, float r) {
    col += vec3(0.09, 0.055, 0.0) * cover(r - d);
    return col + vec3(0.15, 0.1, 0.02) * cover(r * 0.55 - d);
}

// Aurora curtain i's hem at s (0..1 along it): its x and y, and how high its light
// reaches. The main curtain sweeps down to the right, turning almost edge-on
// where it folds; a fainter one hangs high and far, and a low one glows over
// the peaks.
vec3 hem(float s, int i) {
    if (i == 0)
        return vec3(mix(0.44, 1.82, s) + 0.07 * sin(s * 9.5 + 0.9) * (0.6 + vnoise(vec2(s * 3.0, 1.0)))
                        + 0.13 * sin((s - 0.42) * 11.0) * exp(-pow((s - 0.42) / 0.14, 2.0))
                        + 0.03 * sin((s - 0.8) * 16.0) * exp(-pow((s - 0.8) / 0.07, 2.0)),
                    mix(0.66, 0.5, s) + 0.035 * sin(s * 5.0 + 0.6) + 0.01 * sin(s * 15.0 + 2.0)
                        - 0.06 * smoothstep(0.3, 0.55, s) * smoothstep(0.75, 0.55, s)
                        + 0.03 * exp(-pow((s - 0.27) / 0.06, 2.0)),
                    0.05 + 0.045 * vnoise(vec2(s * 4.0, 7.0)));
    if (i == 1)
        return vec3(mix(1.02, 1.7, s) + 0.04 * sin(s * 12.0 + 2.0),
                    mix(0.88, 0.92, s) + 0.01 * sin(s * 7.0 + 1.0),
                    0.02 + 0.015 * vnoise(vec2(s * 5.0, 3.0)));
    return vec3(mix(0.34, 0.98, s) + 0.03 * sin(s * 8.0 + 1.0),
                0.51 + 0.02 * sin(s * 3.0 + 1.0),
                0.028 + 0.01 * vnoise(vec2(s * 4.0, 9.0)));
}

// The aurora's light at q: x, all the curtains' glow added up, as light adds
// where a curtain folds over itself or crosses another; y, the pink fringe just
// under the main curtain's hem; z, the striations' share of the glow. Each
// curtain is a sheet hung from its hem, leaning a little, glowing brightest in a
// band along the hem and fading upward, a few broad rays reaching higher, and
// brighter where it is seen edge-on.
vec3 auroraGlow(vec2 q) {
    float total = 0.0, under = 0.0, streaks = 0.0;
    for (int i = 0; i < 3; i += 2) {
        float fi = float(i);
        float strength = i == 0 ? 1.0 : 0.34;
        float span = i == 0 ? 1.38 : 0.64;
        const float lean = 0.06;
        const int N = 110;
        float ds = 1.0 / float(N);
        vec3 b = hem(0.0, i);
        float fPrev = b.x + lean * (q.y - b.y) - q.x;
        // Every place the sheet crosses this column is a layer of light.
        for (int k = 1; k <= N; k++) {
            float s = ds * float(k);
            vec3 bb = hem(s, i);
            float f = bb.x + lean * (q.y - bb.y) - q.x;
            if (fPrev * f <= 0.0 && fPrev != f) {
                float sr = s - ds * f / (f - fPrev);
                vec3 base = hem(sr, i);
                float rel = q.y - base.y;
                if (rel > -0.03 && rel < 0.4) {
                    float slope = abs(f - fPrev) / ds;
                    float edgeOn = clamp(span * 0.35 / max(slope, 0.05), 1.0, 1.9);
                    float ends = smoothstep(0.0, 0.16, sr) * smoothstep(0.97, 0.8, sr);
                    // Broad soft rays, unevenly spaced, a few reaching well above the rest.
                    float rf = sr * 13.0 + 2.0 * vnoise(vec2(sr * 4.0, fi + 2.0));
                    float cell = floor(rf);
                    float hr = hash(vec2(cell, fi + 11.0));
                    float ray = exp(-pow((fract(rf) - 0.5) / mix(0.38, 0.55, hash(vec2(cell, fi + 12.0))), 2.0));
                    // The drape: the curtain's reach swells and sinks in broad soft lobes.
                    float drape = vnoise(vec2(sr * 3.2, fi + 20.0)), lobe = vnoise(vec2(sr * 9.0, fi + 21.0));
                    float tall = base.z * (0.35 + 1.5 * drape * drape + 0.35 * lobe
                                           + (i == 0 ? 1.0 * step(0.74, hr) * (hr - 0.5) * ray : 0.0));
                    float body = rel >= 0.0 ? exp(-rel / tall) * (1.0 - smoothstep(2.6 * tall, 4.0 * tall, rel)) + 0.5 * exp(-rel / 0.014)
                                            : 1.5 * exp(rel / 0.0035);
                    body *= 0.86 + 0.28 * vnoise(vec2(sr * 24.0, fi + 22.0));
                    float light = body * edgeOn * ends * strength;
                    // Layers add, but less once bright, so a fold glows without blazing.
                    total += light * (1.0 - 0.45 * min(total, 1.0));
                    // Fine striations of uneven spacing, strongest low and gone higher up.
                    float st = smoothstep(0.4, 0.8, vnoise(vec2(sr * 120.0, fi + 30.0))) * (0.4 + vnoise(vec2(sr * 31.0, fi + 31.0)));
                    streaks += light * st * exp(-max(rel, 0.0) / (1.4 * tall));
                    if (i == 0 && rel < 0.0)
                        under = max(under, exp(rel / 0.009) * ends * min(edgeOn, 1.5) * (0.5 + 0.8 * vnoise(vec2(sr * 18.0, 3.0))));
                }
            }
            fPrev = f;
        }
    }
    return vec3(total, under, streaks / max(total, 1e-4));
}

// The aurora in flat tiers of light from its glow g: rgb, and how strongly it
// shows. A faint haze round it, violet highest, then teal, green, bright green,
// and a pale hem, with a pink fringe under it and paler striations through it.
vec4 auroraTiers(vec3 g) {
    float t0 = band(g.x, 0.1), t1 = band(g.x, 0.2), t2 = band(g.x, 0.36), t3 = band(g.x, 0.6), t4 = band(g.x, 0.95);
    vec3 c = mix(rgb(46, 150, 156), rgb(116, 94, 196), t0);
    float a = mix(0.05 * band(g.x, 0.05), 0.13, t0);
    c = mix(c, rgb(46, 150, 156), t1);
    a = mix(a, 0.4, t1);
    c = mix(c, rgb(70, 200, 156), t2);
    a = mix(a, 0.7, t2);
    c = mix(c, rgb(118, 232, 178), t3);
    a = mix(a, 0.88, t3);
    c = mix(c, rgb(200, 252, 226), t4);
    a = mix(a, 1.0, t4);
    float streak = band(g.z, 0.32) * t1 * (1.0 - t4);
    c = mix(c, mix(c, rgb(200, 252, 226), 0.2), streak);
    a = mix(a, min(a + 0.08, 1.0), streak);
    float pink = band(g.y, 0.55) * (1.0 - t2);
    c = mix(c, rgb(222, 112, 186), pink);
    a = mix(a, 0.7, pink);
    return vec4(c, a);
}

// The aurora supersampled, as its folds turn in less than a pixel.
vec4 aurora(vec2 q, float px) {
    vec4 acc = vec4(0.0);
    for (int i = 0; i < 4; i++) {
        vec2 o = (vec2(mod(float(i), 2.0), floor(float(i) / 2.0)) - 0.5) * 0.5 * px;
        vec4 c = auroraTiers(auroraGlow(q + o));
        acc += vec4(c.rgb * c.a, c.a);
    }
    return vec4(acc.rgb / max(acc.a, 1e-4), acc.a * 0.25);
}

// The main peaks of ridge(), without its small bumps, for shading by slope.
float peaks(float x, float freq, float seed) {
    float n = 1.0 - abs(2.0 * vnoise(vec2(x * freq, seed)) - 1.0);
    return n * n;
}

// Mountains with a skyline h: faces turned toward the moon (left) lit, the rest in shade.
vec3 range(vec3 col, vec2 q, float h, float hL, float hR, vec3 lit, vec3 shade, vec3 snowLit) {
    float inside = below(h, q.y);
    vec3 c = hR > hL ? lit : shade;
    // Snow on the upper slopes, catching the light where the face does.
    c = mix(c, hR > hL ? snowLit : mix(shade, snowLit, 0.35), cover(q.y - (h - 0.035 - 0.02 * vnoise(vec2(q.x * 30.0, 1.0)))));
    return mix(col, c, inside);
}

// Glints on the swell: short level dashes in rows that thin toward the horizon,
// gathered round x = cx in a path w wide at the bottom, narrowing to a quarter
// of that at the horizon, from below the horizon by from down to reach. x:
// coverage; y: how near the path's middle the glint is (1 at the middle).
vec2 glitter(vec2 q, float cx, float w, float from, float reach, float seed, float px) {
    float d = HORIZON - q.y;
    if (d <= from || d > reach)
        return vec2(0.0);
    float row = floor(log(d / 0.002) / log(1.04));
    float d0 = 0.002 * pow(1.04, row);
    float rh = d0 * 0.04;
    float yc = d0 + rh * (0.3 + 0.4 * hash(vec2(row, seed)));
    float halfW = 0.5 * w * (0.25 + 0.75 * d0 / HORIZON);
    float cw = max(rh * 6.0, 3.0 * px);
    float fadeOut = (1.0 - smoothstep(mix(from, reach, 0.6), reach, d)) * mix(0.35, 1.0, hash(vec2(row, seed + 5.0)));
    vec2 best = vec2(0.0);
    for (int k = -1; k <= 1; k++) {
        float cell = floor((q.x - cx) / cw) + float(k);
        vec3 h = vec3(hash(vec2(cell, row + seed)), hash(vec2(cell + 7.1, row + seed)), hash(vec2(cell + 3.3, row - seed)));
        float xc = cx + (cell + 0.5 + (h.y - 0.5) * 0.7) * cw;
        float off = (xc - cx) / halfW;
        if (h.x > exp(-off * off * 1.6) * fadeOut)
            continue;
        float len = cw * mix(0.15, 1.1, h.z * h.z) * (1.0 - 0.5 * min(abs(off), 1.0));
        float th = max(rh * 0.3 * mix(0.6, 1.0, h.z), 0.55 * px);
        vec2 o = vec2(q.x - xc, d - yc - rh * 0.3 * (h.y - 0.5));
        float dist = length(vec2(max(abs(o.x) - len * 0.5, 0.0), o.y)) - th;
        float c = smoothstep(px, -px, dist);
        if (c > best.x)
            best = vec2(c, 1.0 - min(abs(off), 1.0));
    }
    return best;
}

// A lopsided, faceted iceberg peaking at x = c on the waterline, reaching wl to
// the left and wr to the right, ht tall, flat-topped as far as table: a face lit
// by the moon (left), a half-lit one and one in shade, split by ridges slanting
// down from the peak, a pale rim where the swell laps it, its foot glowing teal
// under the water, and its reflection broken by the swell.
vec3 berg(vec3 col, vec2 q, float c, float wl, float wr, float ht, float table, float seed, float water) {
    float dx = q.x - c;
    if (dx < -wl * 1.15 || dx > wr * 1.15)
        return col;
    // The foot under the water, wider than the ice above it.
    float tf = dx < 0.0 ? -dx / (wl * 1.12) : dx / (wr * 1.12);
    float foot = cover(1.0 - tf) * cover(water - q.y) * cover(q.y - water + 0.018 * (1.0 - tf * tf));
    col = mix(col, rgb(50, 120, 140), foot * 0.55);
    float t = dx < 0.0 ? -dx / wl : dx / wr;
    float prof = clamp((1.0 - t) * (1.0 + 0.7 * zig(dx / (wl + wr) * 6.0, seed)), 0.0, 1.0);
    prof = min(prof * (1.0 + table * 2.0), 1.0 - table * 0.15 * abs(zig(dx * 40.0, seed + 2.0)));
    float h = water + ht * pow(clamp(prof, 0.0, 1.0), 0.85);
    bool refl = q.y < water;
    float y = refl ? 2.0 * water - q.y : q.y;
    float down = (water + ht - y) / ht;
    float ridge = (0.1 + 0.25 * hash(vec2(seed, 1.0))) * wr * down - table * wl * 0.4;
    float ridge2 = ridge + (0.35 + 0.2 * hash(vec2(seed, 2.0))) * wr * down + table * wr * 0.3;
    vec3 face = dx < ridge ? rgb(214, 232, 244) : (dx < ridge2 ? rgb(144, 180, 210) : rgb(96, 134, 172));
    // A lower facet on the lit side, turned a little from the moon.
    float ridge0 = ridge - (0.3 + 0.3 * hash(vec2(seed, 3.0))) * wl * (down - 0.35);
    face = dx < ridge0 && down > 0.35 ? rgb(184, 208, 230) : face;
    // Snow lying on a flat top catches the moon.
    face = mix(face, rgb(232, 242, 250), table * cover(y - h + 0.008));
    if (!refl) {
        col = mix(col, face, below(h, q.y));
        col = mix(col, rgb(196, 226, 238), below(h, q.y) * cover(water + 0.003 - q.y) * band(vnoise(vec2(q.x * 120.0, seed)), 0.35));
    } else {
        float swell = band(vnoise(vec2(q.x * 14.0, log(HORIZON - q.y + 0.001) * 60.0)), 0.3);
        col = mix(col, mix(face, rgb(16, 36, 56), 0.5), below(h, y) * cover(q.y - water + ht * 0.85) * swell * 0.9);
    }
    return col;
}

// A dome of ice blocks at c, of radius r: lit from the moon on the upper left in
// three tones, its courses of blocks marked, and a warm doorway at its foot if
// door is not 0, on that side.
vec3 dome(vec3 col, vec2 q, vec2 c, float r, float door, float dim) {
    vec2 o = (q - c) / r;
    float inside = cover((1.0 - length(o)) * r) * cover(o.y * r);
    if (inside <= 0.0)
        return col;
    float lit = dot(o, normalize(vec2(-0.75, 0.65)));
    vec3 tone = mix(rgb(104, 140, 178), rgb(156, 188, 214), band(lit, -0.25));
    tone = mix(tone, rgb(214, 232, 244), band(lit, 0.25));
    tone *= dim;
    // Courses of blocks, closer toward the top as the dome curves away.
    float course = abs(fract(asin(clamp(o.y, 0.0, 0.999)) / 0.32) - 0.5);
    tone = mix(tone, tone * 0.86, cover(0.06 - course) * band(0.95, length(o)));
    // A doorway: a little arched tunnel lit from within.
    vec2 dp = o - vec2(door * 0.35, 0.0);
    float hasDoor = step(0.01, abs(door));
    float arch = cover(0.22 - length(vec2(dp.x, max(dp.y - 0.18, 0.0)))) * cover(0.4 - dp.y) * hasDoor;
    tone = mix(tone, rgb(70, 92, 120), arch);
    tone = mix(tone, LAMP, cover(0.15 - length(vec2(dp.x, max(dp.y - 0.15, 0.0)))) * hasDoor);
    return mix(col, tone, inside);
}

// Where lamp i on the shore stands: its x and the height of its light.
vec2 lampAt(int i) {
    return vec2(0.68 + 0.095 * float(i) + 0.02 * hash(vec2(float(i), 5.0)), HORIZON + 0.031);
}

// The ice town on the far shore: a snow shelf, domes in two rows, a slender tower
// with lit windows and a lamp at its top, and lamps along the shore.
vec3 town(vec3 col, vec2 q, float px) {
    if (q.x < 0.6 || q.x > 1.24 || q.y > 0.56)
        return col;
    float shelf = HORIZON + 0.013 * smoothstep(0.6, 0.66, q.x) * smoothstep(1.24, 1.18, q.x) + 0.003 * vnoise(vec2(q.x * 50.0, 2.0));
    // Domes behind, dimmer and higher on the shelf.
    col = dome(col, q, vec2(0.7, shelf + 0.006), 0.026, 0.0, 0.88);
    col = dome(col, q, vec2(0.81, shelf + 0.006), 0.036, 0.0, 0.88);
    col = dome(col, q, vec2(1.07, shelf + 0.006), 0.031, 0.0, 0.88);
    col = dome(col, q, vec2(1.16, shelf + 0.006), 0.021, 0.0, 0.88);
    // The tower: a tapering shaft, a cap, a needle spire, and windows up it.
    float tx = 0.945, ty = q.y - shelf;
    float tw = 0.014 * (1.0 - ty / 0.24);
    float tower = cover(tw - abs(q.x - tx)) * cover(ty) * cover(0.15 - ty);
    col = mix(col, q.x < tx - tw * 0.25 ? rgb(220, 236, 246) : rgb(122, 158, 192), tower);
    float cap = cover(0.011 - length((q - vec2(tx, shelf + 0.15)) * vec2(1.0, 0.8))) * cover(ty - 0.15);
    col = mix(col, q.x < tx - 0.003 ? rgb(200, 222, 240) : rgb(96, 132, 172), cap);
    float spire = cover(0.003 * (1.0 - (ty - 0.158) / 0.05) - abs(q.x - tx)) * cover(ty - 0.158) * cover(0.208 - ty);
    col = mix(col, rgb(110, 146, 186), spire);
    col = glow(col, length(q - vec2(tx, shelf + 0.142)), 0.012);
    col = mix(col, LAMP, cover(0.0032 - length(q - vec2(tx, shelf + 0.142))));
    float win = cover(0.0018 - abs(q.x - tx - 0.001)) * cover(0.0045 - abs(fract(ty / 0.03) * 0.03 - 0.015)) * cover(0.12 - ty) * cover(ty - 0.03);
    col = mix(col, LAMP, tower * win);
    // Domes in front, with lit doorways.
    col = dome(col, q, vec2(0.655, shelf), 0.019, 0.6, 1.0);
    col = dome(col, q, vec2(0.75, shelf), 0.029, -0.5, 1.0);
    col = dome(col, q, vec2(0.87, shelf), 0.04, 0.45, 1.0);
    col = dome(col, q, vec2(1.015, shelf), 0.036, -0.4, 1.0);
    col = dome(col, q, vec2(1.12, shelf), 0.025, 0.5, 1.0);
    // The shelf: lit snow on top, a shaded face down to the water.
    float onShelf = below(shelf, q.y) * cover(q.y - HORIZON + 0.001);
    col = mix(col, rgb(108, 144, 178), onShelf);
    col = mix(col, rgb(196, 218, 236), onShelf * cover(q.y - shelf + 0.004));
    // Lamps on posts along the shore.
    for (int i = 0; i < 6; i++) {
        vec2 l = lampAt(i);
        float post = cover(0.0012 - abs(q.x - l.x)) * cover(q.y - shelf + 0.002) * cover(l.y - 0.002 - q.y);
        col = mix(col, rgb(40, 52, 70), post);
        vec2 lo = q - l;
        col = glow(col, length(lo), 0.009);
        col = mix(col, LAMP, cover(0.0026 - length(lo)));
    }
    return col;
}

// How much of the town's silhouette covers p, for its reflection.
float townSilhouette(vec2 p) {
    if (p.x < 0.6 || p.x > 1.24)
        return 0.0;
    float shelf = HORIZON + 0.013 * smoothstep(0.6, 0.66, p.x) * smoothstep(1.24, 1.18, p.x);
    float c = below(shelf, p.y);
    c = max(c, cover(0.04 - length(p - vec2(0.87, shelf))));
    c = max(c, cover(0.036 - length(p - vec2(1.015, shelf))));
    c = max(c, cover(0.036 - length(p - vec2(0.81, shelf + 0.006))));
    c = max(c, cover(0.031 - length(p - vec2(1.07, shelf + 0.006))));
    c = max(c, cover(0.029 - length(p - vec2(0.75, shelf))));
    c = max(c, cover(0.026 - length(p - vec2(0.7, shelf + 0.006))));
    c = max(c, cover(0.025 - length(p - vec2(1.12, shelf))));
    float ty = p.y - shelf;
    c = max(c, cover(0.014 * (1.0 - ty / 0.24) - abs(p.x - 0.945)) * cover(ty) * cover(0.16 - ty));
    return c;
}

// The pier, running out from the town's shore toward the viewer, so it widens as
// it comes: a deck of planks lit by the moon, its shaded side on posts standing
// in the water, and a lantern on a pole at its end.
vec3 pier(vec3 col, vec2 q, float px) {
    const float Y0 = HORIZON + 0.002, Y1 = HORIZON - 0.075;
    if (q.y > Y0 + 0.05 || q.y < Y1 - 0.03 || q.x < 1.08 || q.x > 1.16)
        return col;
    float t = clamp((Y0 - q.y) / (Y0 - Y1), 0.0, 1.0);
    float left = mix(1.098, 1.112, t), right = mix(1.106, 1.136, t);
    float side = mix(0.0015, 0.004, t);
    float inLen = cover(Y0 - q.y) * cover(q.y - Y1);
    // Posts under the shaded side, and their dark reflections below them.
    float pt = fract(log(Y0 - q.y + 0.01) * 5.0);
    float yPost = Y0 - (exp((floor(log(Y0 - q.y + 0.01) * 5.0) + 0.5) / 5.0) - 0.01);
    vec2 base = vec2(mix(right, left, 0.1), yPost);
    float pw = mix(0.0007, 0.0014, t);
    float post = cover(pw - abs(q.x - right + pw)) * cover(Y0 - q.y) * cover(q.y - Y1 + side * 1.5);
    col = mix(col, rgb(32, 28, 32), post * (1.0 - inLen));
    // The deck's shaded side, then its lit top with planks across it.
    float sideIn = cover(q.x - left) * cover(right + side * 0.4 - q.x) * cover(Y0 - q.y) * cover(q.y - Y1 + side);
    col = mix(col, rgb(58, 44, 40), sideIn);
    float top = cover(q.x - left) * cover(right - q.x) * inLen;
    float plank = abs(fract(log(Y0 - q.y + 0.004) * 26.0) - 0.5);
    col = mix(col, mix(rgb(150, 116, 88), rgb(112, 84, 66), cover(0.08 - plank)), top);
    col = mix(col, rgb(196, 160, 120), top * cover(left + 0.0012 - q.x));
    // The lantern on a pole at the near end.
    vec2 lp = vec2(left + 0.002, Y1 + 0.001);
    col = mix(col, rgb(34, 30, 34), cover(0.0012 - abs(q.x - lp.x)) * cover(q.y - lp.y) * cover(lp.y + 0.036 - q.y));
    vec2 lo = q - lp - vec2(0.0, 0.038);
    col = glow(col, length(lo), 0.016);
    col = mix(col, LAMP, cover(0.0035 - length(lo * vec2(1.0, 0.75))));
    return col;
}

// The canoe at cn, gliding right toward the pier: a hull sweeping up to its bow
// and stern, its gunwale lit by the lantern hung at the bow, a paddler in a
// hooded parka dipping a paddle behind, its reflection, and a wake opening in a
// broken V behind it.
vec3 canoe(vec3 col, vec2 q, vec2 cn, float px) {
    vec2 o = q - cn;
    if (o.x < -0.32 || o.x > 0.12 || o.y < -0.05 || o.y > 0.07)
        return col;
    // The wake: two lines spreading back from the stern, broken and fading.
    float back = -0.07 - o.x;
    if (back > 0.0 && back < 0.24) {
        float fadeW = 1.0 - back / 0.24;
        for (int i = 0; i < 2; i++) {
            float spread = i == 0 ? 0.07 : -0.12;
            float line = cover(mix(0.0007, 0.0016, fadeW) - abs(o.y + 0.009 - spread * back));
            float gaps = band(vnoise(vec2(back * 70.0, float(i) * 9.0)), 0.42 + 0.3 * (1.0 - fadeW));
            col = mix(col, rgb(104, 142, 170), line * gaps * fadeW * 0.9);
        }
    }
    // The hull and its reflection.
    vec2 h = o / vec2(0.075, 0.012);
    float sheer = 0.25 + 0.9 * pow(abs(h.x), 5.0);
    float keel = -1.0 + 0.95 * pow(abs(h.x), 2.6);
    float ends = cover((1.04 - abs(h.x)) * 0.075);
    float hull = cover((sheer - h.y) * 0.012) * cover((h.y - keel) * 0.012) * ends;
    float rh = -2.0 - h.y;
    float refl = cover((sheer * 0.7 - rh + 0.25) * 0.012) * cover((rh + 1.0 - keel - 1.0) * 0.012) * ends * step(h.y, -1.0);
    col = mix(col, rgb(16, 28, 42), refl * band(vnoise(vec2(q.x * 50.0, q.y * 600.0)), 0.3) * 0.9);
    col = mix(col, rgb(62, 44, 40), hull);
    float rim = hull * cover((h.y - sheer + 0.35) * 0.012);
    col = mix(col, mix(rgb(118, 84, 64), rgb(214, 156, 100), smoothstep(-0.8, 0.8, h.x)), rim);
    // The paddler, kneeling: a parka widening to its hem, a hood with a fur rim
    // lit on the lantern's side.
    vec2 f = o - vec2(-0.016, 0.003);
    float bodyW = mix(0.0085, 0.006, clamp(f.y / 0.017, 0.0, 1.0));
    float body = cover(bodyW - abs(f.x + 0.06 * f.y)) * cover(f.y) * cover(0.018 - f.y);
    vec2 hd = f - vec2(-0.0005, 0.0225);
    float hood = cover(0.0062 - length(hd * vec2(1.0, 0.92)));
    col = mix(col, rgb(38, 44, 62), max(body, hood));
    col = mix(col, rgb(70, 62, 70), body * cover(f.x + 0.06 * f.y - bodyW * 0.3));
    col = mix(col, rgb(210, 168, 118), hood * cover(length(hd) - 0.0038) * cover(hd.x + 0.0008));
    col = mix(col, rgb(20, 22, 30), cover(0.0034 - length(hd - vec2(0.0012, -0.0004))));
    // The paddle, held across the body, its shaft running down behind to the water.
    vec2 pa = vec2(-0.036, -0.012), pb = vec2(0.0, 0.03);
    col = mix(col, rgb(124, 90, 62), cover(0.0011 - sdSeg(f, pa, pb)) * step(-0.009, o.y));
    col = mix(col, rgb(124, 90, 62), cover(0.0024 - length((f - pb) * vec2(1.0, 1.4))));
    col = mix(col, rgb(104, 142, 170), cover(0.0012 - abs(length((o - vec2(-0.052, -0.012)) / vec2(1.0, 0.25)) - 0.009)) * step(o.y, -0.012));
    // The lantern on a crook over the bow, its light in flat rings.
    vec2 crook = vec2(0.056, 0.002);
    float pole = max(cover(0.001 - sdSeg(o, crook, crook + vec2(0.005, 0.032))),
                     cover(0.001 - sdSeg(o, crook + vec2(0.005, 0.032), crook + vec2(0.016, 0.03))));
    col = mix(col, rgb(30, 26, 30), pole);
    vec2 lo = o - crook - vec2(0.016, 0.021);
    col = glow(col, length(lo), 0.022);
    col = mix(col, rgb(40, 34, 36), cover(0.0042 - max(abs(lo.x) * 1.3, abs(lo.y - 0.0005))));
    col = mix(col, LAMP, cover(0.0028 - length(lo * vec2(1.2, 0.8))));
    return col;
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    float aspect = u.resolution.x / u.resolution.y;
    float pxs = 1.0 / u.resolution.y;
    float minR = 1.3 * pxs;
    float aa = 0.75 * pxs;
    vec2 moon = vec2(0.27, 0.82);
    float e = 0.01;

    vec3 col;
    if (q.y >= HORIZON) {
        // Sky, lighter toward the horizon, then stars and the aurora.
        float t = clamp((q.y - HORIZON) / (1.0 - HORIZON), 0.0, 1.0);
        col = mix(mix(rgb(32, 66, 90), rgb(14, 34, 56), steps(min(t * 2.0, 1.0), 5.0)),
                  rgb(5, 11, 22), steps(clamp(t * 1.5 - 0.5, 0.0, 1.0), 5.0));
        float stars = max(starField(q, 0.012, 0.35, 1.0, 0.0011, minR, aa),
                          starField(q + 0.37, 0.03, 0.45, 7.0, 0.0019, minR, aa));
        col = mix(col, rgb(226, 238, 246), stars * smoothstep(0.42, 0.7, q.y));
        vec4 a = aurora(q, pxs);
        col = mix(col, a.rgb, a.a);
        // The moon and its halo.
        float dm = length(q - moon);
        col = mix(col, mix(col, rgb(150, 190, 218), 0.08), cover(0.13 - dm));
        col = mix(col, mix(col, rgb(170, 204, 226), 0.12), cover(0.085 - dm));
        col = mix(col, rgb(234, 242, 248), cover(0.045 - dm));
        col = mix(col, rgb(196, 212, 226), cover(0.045 - dm) * band(vnoise((q - moon) * 60.0), 0.66));

        // Far glacier peaks, then a nearer range.
        float h0 = 0.36 + 0.2 * ridge(q.x + 1.0, 2.4, 3.0);
        float h0L = peaks(q.x - e + 1.0, 2.4, 3.0), h0R = peaks(q.x + e + 1.0, 2.4, 3.0);
        col = range(col, q, h0, h0L, h0R, rgb(92, 128, 164), rgb(44, 70, 104), rgb(176, 204, 228));
        float h1 = 0.34 + 0.11 * ridge(q.x + 4.0, 3.6, 5.0);
        float h1L = peaks(q.x - e + 4.0, 3.6, 5.0), h1R = peaks(q.x + e + 4.0, 3.6, 5.0);
        col = range(col, q, h1, h1L, h1R, rgb(56, 90, 124), rgb(26, 46, 72), rgb(140, 176, 206));
        col = town(col, q, pxs);
    } else {
        // The sea: lighter toward the horizon, its swell finer with distance.
        float d = HORIZON - q.y;
        float t = clamp(d / HORIZON, 0.0, 1.0);
        float swellY = log(d + 0.002) * 70.0;
        col = mix(rgb(22, 48, 70), rgb(8, 20, 34), steps(t, 6.0));
        float ripple = 0.004 * sin(swellY * 3.0 + q.x * 30.0) * (0.3 + t);
        vec2 m = vec2(q.x + ripple, 2.0 * HORIZON - q.y);
        float breakup = band(vnoise(vec2(q.x * 10.0 / (0.3 + t), swellY)), 0.48);
        // The aurora, mirrored in broken streaks.
        vec4 a = auroraTiers(auroraGlow(m));
        col = mix(col, a.rgb, a.a * 0.32 * breakup);
        // Mirrored mountains, dark.
        float h0 = 0.36 + 0.2 * ridge(m.x + 1.0, 2.4, 3.0);
        col = mix(col, rgb(18, 38, 60), below(h0, m.y) * 0.8 * breakup);
        float h1 = 0.34 + 0.11 * ridge(m.x + 4.0, 3.6, 5.0);
        col = mix(col, rgb(14, 30, 50), below(h1, m.y) * 0.85 * breakup);
        // The town, mirrored faintly and broken by the swell.
        col = mix(col, rgb(56, 88, 118), townSilhouette(m) * 0.5 * band(vnoise(vec2(q.x * 16.0, swellY * 1.3)), 0.3));
        // The moon's path: a faint sheen, and glints thick in its middle, sparse at its edges.
        float sheenW = 0.03 + 0.07 * t + 0.008 * sin(swellY * 0.7);
        col = mix(col, mix(col, rgb(120, 160, 192), 0.12), cover(sheenW - abs(q.x - moon.x)) * (1.0 - 0.6 * t));
        vec2 g = glitter(q, moon.x, 0.2, 0.0, HORIZON, 1.0, pxs);
        col = mix(col, mix(rgb(120, 162, 196), rgb(228, 238, 246), band(g.y, 0.55)), g.x);
        // Each lamp on the shore, and the pier's lantern, trail across the water.
        for (int i = 0; i < 6; i++) {
            vec2 gl = glitter(q, lampAt(i).x, 0.012, 0.0, 0.09, 3.0 + float(i), pxs);
            col = mix(col, LAMP, gl.x * mix(0.5, 0.9, gl.y));
        }
        vec2 gp = glitter(q, 1.114, 0.02, 0.078, 0.2, 11.0, pxs);
        col = mix(col, LAMP, gp.x * mix(0.5, 0.9, gp.y));
        vec2 gc = glitter(q, 0.872, 0.05, HORIZON - 0.157, HORIZON - 0.1, 13.0, pxs);
        col = mix(col, LAMP, gc.x * mix(0.45, 0.9, gc.y));
        // Long swells.
        col = mix(col, rgb(40, 74, 100), band(vnoise(vec2(q.x * 4.0 / (0.3 + t), swellY * 0.5)), 0.84) * 0.5);
    }

    // Icebergs on the waterline, with their reflections, the pier, and the canoe.
    col = berg(col, q, 0.17, 0.09, 0.16, 0.07, 0.6, 1.0, HORIZON - 0.02);
    col = berg(col, q, 1.55, 0.19, 0.1, 0.14, 0.0, 2.0, HORIZON - 0.045);
    col = berg(col, q, 1.27, 0.03, 0.055, 0.035, 0.0, 3.0, HORIZON - 0.1);
    col = pier(col, q, pxs);
    col = canoe(col, q, vec2(0.8, 0.17), pxs);

    // Drifted snow banks in the foreground: lobes over lobes, each with a lit rim
    // along its top and its foot in blue shadow.
    float x = q.x / aspect;
    float sb = 0.045 + 0.1 * pow(max(x - 0.42, 0.0) / 0.58, 1.3) + 0.014 * billows(q.x, 5.0, 2.0);
    float sb2 = 0.022 + 0.06 * pow(max(0.42 - x, 0.0) / 0.42, 1.5) + 0.012 * billows(q.x + 3.0, 7.0, 4.0);
    for (int i = 0; i < 2; i++) {
        float top = i == 0 ? sb : sb2;
        float lobes = top - 0.022 - 0.012 * billows(q.x + 1.7 + float(i) * 5.0, 9.0, 6.0 + float(i));
        col = mix(col, rgb(92, 124, 160), below(top, q.y));
        col = mix(col, rgb(150, 180, 210), below(top - 0.005, q.y));
        col = mix(col, rgb(214, 230, 242), below(top - 0.005, q.y) * cover(q.y - top + 0.014));
        // A nearer drift in front, its own rim lit, the hollow behind it in shadow.
        col = mix(col, rgb(118, 148, 182), below(lobes + 0.004, q.y));
        col = mix(col, rgb(176, 202, 226), below(lobes, q.y));
        col = mix(col, rgb(222, 236, 246), below(lobes, q.y) * cover(q.y - lobes + 0.008));
    }

    // Falling snow, nearer flakes larger.
    for (int i = 0; i < 80; i++) {
        vec2 h = hash2(vec2(float(i), 2.4));
        vec2 f = vec2(h.x * aspect, h.y);
        float r = mix(0.001, 0.0032, pow(hash(vec2(float(i), 7.0)), 2.0));
        col = mix(col, rgb(226, 238, 246), cover(r - length(q - f)) * 0.85);
    }
    fragColor = vec4(col, 1.0);
}
