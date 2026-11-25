#version 440
#extension GL_GOOGLE_include_directive : enable
// Polar night: folded aurora curtains, rays rising off them, hang over moonlit
// glacier peaks and are mirrored in a still polar sea. An ice city of domes and a
// tall tower glows warm on the far shore, lopsided icebergs drift, both mirrored too, a canoe carries a lantern
// home, and snow falls over a drifted bank in the foreground.
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

// The base line of aurora ribbon i at s (0..1 along it, left to right): it
// sways back and forth as it runs, folding over itself where it doubles back.
vec2 ribbonBase(float s, int i) {
    if (i == 0)
        return vec2(mix(1.0, 1.9, s) + 0.035 * sin(s * 16.0 + 3.0) * (0.6 + vnoise(vec2(s * 4.0, 1.0))),
                    mix(0.49, 0.53, s) + 0.012 * sin(s * 7.0 + 0.4));
    if (i == 1)
        return vec2(mix(0.36, 1.92, s) + 0.11 * sin(s * 13.0 + 4.1) * (0.5 + vnoise(vec2(s * 3.0, 2.0))),
                    mix(0.6, 0.86, s * s) + 0.025 * sin(s * 9.0 + 2.0));
    return vec2(mix(0.5, 1.88, s) + 0.17 * sin(s * 10.0 + 0.6) * (0.55 + 0.7 * vnoise(vec2(s * 2.5, 3.0))),
                mix(0.84, 0.74, s) - 0.17 * 4.0 * s * (1.0 - s) * (1.0 - 0.4 * s) + 0.02 * sin(s * 8.0 + 5.0));
}

// Aurora light at q: x the total glow; y the height within the curtain (0 at its
// lower edge, 1 near its top), and z the strength of the ray there, of the
// brightest sheet at q.
vec3 auroraGlow(vec2 q) {
    float total = 0.0, best = 0.0;
    vec3 g = vec3(0.0, 2.0, 0.0);
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float span = i == 0 ? 0.9 : (i == 1 ? 1.56 : 1.38);
        float x0 = i == 0 ? 1.0 : (i == 1 ? 0.36 : 0.5);
        float tall = i == 0 ? 0.05 : (i == 1 ? 0.09 : 0.13);
        float lean = 0.08 * (fi - 1.0);
        float s0 = (q.x - x0) / span;
        float m = 0.32 / span;
        float lo = clamp(s0 - m, 0.0, 1.0), hi = clamp(s0 + m, 0.0, 1.0);
        float ds = (hi - lo) / 80.0;
        vec2 b = ribbonBase(lo, i);
        float fPrev = b.x + lean * (q.y - b.y) - q.x;
        // Every place the sheet crosses this column: each is a layer of light.
        for (int k = 1; k <= 80; k++) {
            float s = lo + ds * float(k);
            vec2 bb = ribbonBase(s, i);
            float f = bb.x + lean * (q.y - bb.y) - q.x;
            if (fPrev * f <= 0.0 && fPrev != f) {
                float sr = s - ds * f / (f - fPrev);
                vec2 base = ribbonBase(sr, i);
                float hgt = tall * (0.65 + 0.7 * vnoise(vec2(sr * 6.0, fi + 4.0)));
                float rel = (q.y - base.y) / hgt;
                if (rel >= 0.0 && rel < 2.5) {
                    // Seen edge-on where it folds, the sheet glows brighter.
                    float slope = abs(f - fPrev) / ds / span;
                    float edgeOn = clamp(inversesqrt(max(slope, 0.05)), 1.0, 1.4);
                    float ends = smoothstep(0.0, 0.16, sr) * smoothstep(1.0, 0.8, sr);
                    // Its top drapes in slow, gentle waves.
                    float drape = rel * (0.75 + 0.45 * vnoise(vec2(sr * 22.0, fi + 9.0)) + 0.12 * vnoise(vec2(sr * 45.0, fi + 17.0)))
                                + rel * rel * 0.5 * (vnoise(vec2(sr * 13.0, fi + 5.0)) - 0.4);
                    // A few broad, soft rays of uneven width and spacing, each fading
                    // out at its own height; lost where the fold packs them too close.
                    float rf = 28.0 * sr / (1.0 - 0.25 * fi) + fi * 7.3;
                    rf += 1.2 * vnoise(vec2(rf * 0.25, fi + 2.0));
                    float cell = floor(rf);
                    float hb = hash(vec2(cell, fi + 11.0)), hw = hash(vec2(cell, fi + 12.0)), hl = hash(vec2(cell, fi + 13.0));
                    float across = abs(fract(rf) - 0.5 - 0.25 * (hw - 0.5)) / mix(0.22, 0.42, hw);
                    float ray = (1.0 - smoothstep(0.0, 1.0, across)) * max(0.0, hb * 1.6 - 0.6);
                    ray *= exp(-rel / mix(0.8, 2.2, hl)) * smoothstep(0.25, 0.6, slope) * ends;
                    float glow = (exp(-2.0 * drape) + 0.3 * exp(-70.0 * rel)) * ends * edgeOn * (i == 0 ? 0.6 : (i == 1 ? 0.8 : 1.0));
                    total += glow;
                    if (glow > best) {
                        best = glow;
                        g.y = rel;
                        g.z = ray;
                    }
                }
            }
            fPrev = f;
        }
    }
    g.x = total;
    return g;
}

// The aurora at q in flat tiers of light, from the glow g: rgb, and how strongly
// it shows (0..1). A thin lit rim along its lower edge, then light green, green,
// teal higher and a faint violet fringe at the top, with broad rays of light
// rising through it and fading out in steps.
vec4 auroraTiers(vec3 g) {
    float t1 = band(g.x + 0.04 * g.z, 0.11), t2 = band(g.x + 0.04 * g.z, 0.15);
    float t3 = band(g.x, 0.32), t4 = band(g.x, 0.66), t5 = band(g.x, 1.2);
    float ray1 = band(g.z, 0.3 + 0.2 * min(g.y, 1.5)) * t2, ray2 = band(g.z, 0.55 + 0.3 * min(g.y, 1.5)) * t2;
    vec3 c = rgb(150, 112, 214);
    float a = 0.28 * t1;
    c = mix(c, rgb(50, 160, 164), t2);
    a = mix(a, 0.42, t2);
    c = mix(c, rgb(84, 212, 166), t3);
    a = mix(a, 0.75, t3);
    c = mix(c, rgb(118, 232, 178), t4);
    a = mix(a, 0.9, t4);
    c = mix(c, mix(c, rgb(190, 250, 220), 0.22), ray1);
    c = mix(c, mix(c, rgb(190, 250, 220), 0.22), ray2);
    a = mix(a, min(a + 0.1, 1.0), ray1);
    c = mix(c, rgb(176, 246, 210), t5);
    a = mix(a, 1.0, t5);
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

// A lopsided, faceted iceberg peaking at x = c on the waterline, reaching `wl` to
// the left and `wr` to the right, `ht` tall: a face lit by the moon (left), a
// half-lit one and one in shade, split by ridges slanting down from the peak,
// mirrored in the water below.
vec3 berg(vec3 col, vec2 q, float c, float wl, float wr, float ht, float seed, float water) {
    float dx = q.x - c;
    if (dx < -wl || dx > wr)
        return col;
    float t = dx < 0.0 ? -dx / wl : dx / wr;
    float prof = clamp((1.0 - t) * (1.0 + 0.7 * zig(dx / (wl + wr) * 6.0, seed)), 0.0, 1.0);
    float h = water + ht * pow(prof, 0.85);
    float y = q.y >= water ? q.y : 2.0 * water - q.y + 0.004 * sin(q.y * 400.0);
    float down = (water + ht - y) / ht;
    float ridge = (0.1 + 0.25 * hash(vec2(seed, 1.0))) * wr * down;
    vec3 face = dx < ridge ? rgb(214, 232, 244) : (dx < ridge + (0.35 + 0.2 * hash(vec2(seed, 2.0))) * wr * down ? rgb(140, 176, 206) : rgb(98, 136, 174));
    if (q.y >= water)
        col = mix(col, face, below(h, q.y));
    else
        col = mix(col, mix(face, rgb(16, 36, 56), 0.55), below(h, y) * cover(q.y - water + ht * 0.8));
    return col;
}

// How much of the ice city's silhouette covers p, for its reflection: the shelf it
// stands on, the domes, the tower and its spire, and the wall, as main() draws them.
float citySilhouette(vec2 p, float cx0, float cx1, float aspect) {
    if (p.x < cx0 - 0.03 || p.x > cx1 + 0.03)
        return 0.0;
    float shelf = HORIZON + 0.012;
    float inX = cover(p.x - cx0) * cover(cx1 - p.x);
    float c = below(shelf + 0.03 + 0.006 * step(0.5, fract(p.x / 0.008)), p.y) * inX;
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        vec2 dc = vec2(mix(cx0 + 0.04, cx1 - 0.04, fi / 5.0) + 0.01 * hash(vec2(fi, 1.0)), shelf + 0.03);
        c = max(c, cover(0.028 + 0.016 * hash(vec2(fi, 2.0)) - length(p - dc)));
    }
    float tx = aspect * 0.53, ty = p.y - shelf;
    c = max(c, cover(0.02 * (1.0 - ty / 0.22) - abs(p.x - tx)) * cover(ty) * cover(0.12 - ty));
    c = max(c, cover(0.009 * (1.0 - (ty - 0.12) / 0.05) - abs(p.x - tx)) * cover(ty - 0.12) * cover(0.17 - ty));
    return c * cover(p.y - HORIZON + 0.002);
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    float aspect = u.resolution.x / u.resolution.y;
    float minR = 1.3 / u.resolution.y;
    float aa = 0.75 / u.resolution.y;
    vec2 moon = vec2(aspect * 0.15, 0.82);
    float e = 0.01;
    // The ice city's ends on the far shore.
    float cx0 = aspect * 0.36, cx1 = aspect * 0.66;

    vec3 col;
    if (q.y >= HORIZON) {
        // Sky, lighter toward the horizon, then stars and the aurora.
        float t = clamp((q.y - HORIZON) / (1.0 - HORIZON), 0.0, 1.0);
        col = mix(mix(rgb(32, 66, 90), rgb(14, 34, 56), steps(min(t * 2.0, 1.0), 5.0)),
                  rgb(5, 11, 22), steps(clamp(t * 1.5 - 0.5, 0.0, 1.0), 5.0));
        float stars = max(starField(q, 0.012, 0.35, 1.0, 0.0011, minR, aa),
                          starField(q + 0.37, 0.03, 0.45, 7.0, 0.0019, minR, aa));
        col = mix(col, rgb(226, 238, 246), stars * smoothstep(0.42, 0.7, q.y));
        vec4 a = aurora(q, 1.0 / u.resolution.y);
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

        // The ice city on the far shore: a crenellated wall, domes, and a tower.
        if (q.x > cx0 - 0.02 && q.x < cx1 + 0.02) {
            float shelf = HORIZON + 0.012 + 0.004 * vnoise(vec2(q.x * 40.0, 2.0));
            col = mix(col, rgb(150, 186, 214), below(shelf, q.y) * cover(q.x - cx0) * cover(cx1 - q.x));
            // Domes behind the wall.
            for (int i = 0; i < 6; i++) {
                float fi = float(i);
                vec2 dc = vec2(mix(cx0 + 0.04, cx1 - 0.04, fi / 5.0) + 0.01 * hash(vec2(fi, 1.0)), shelf + 0.03);
                float dr = 0.028 + 0.016 * hash(vec2(fi, 2.0));
                vec2 o = q - dc;
                float dome = cover(dr - length(o)) * cover(o.y);
                col = mix(col, o.x < -dr * 0.2 ? rgb(214, 232, 244) : rgb(128, 164, 196), dome);
                col = mix(col, rgb(255, 196, 120), dome * cover(0.0035 - length(o - vec2(dr * 0.3, dr * 0.25))));
            }
            // The tower: a tapering shaft with a pointed cap and lit windows.
            float tx = aspect * 0.53;
            float ty = q.y - shelf;
            float tw = 0.02 * (1.0 - ty / 0.22);
            float tower = cover(tw - abs(q.x - tx)) * cover(ty) * cover(0.12 - ty);
            col = mix(col, q.x < tx - tw * 0.3 ? rgb(220, 236, 246) : rgb(124, 160, 194), tower);
            float spireIn = cover(0.009 * (1.0 - (ty - 0.12) / 0.05) - abs(q.x - tx)) * cover(ty - 0.12) * cover(0.17 - ty);
            col = mix(col, rgb(84, 124, 170), spireIn);
            col = mix(col, rgb(255, 196, 120), tower * cover(0.002 - abs(q.x - tx)) * cover(0.006 - abs(fract(ty / 0.035) * 0.035 - 0.017)));
            // The wall, with crenellations and warm lamps along it.
            float crenel = step(0.5, fract(q.x / 0.008));
            float wallTop = shelf + 0.03 + 0.006 * crenel;
            float wall = below(wallTop, q.y) * cover(q.x - cx0) * cover(cx1 - q.x);
            col = mix(col, rgb(168, 200, 226), wall);
            col = mix(col, rgb(108, 144, 180), wall * cover(shelf + 0.012 - q.y));
            col = mix(col, rgb(255, 190, 110), wall * cover(0.0025 - abs(fract(q.x / 0.045) * 0.045 - 0.022)) * cover(0.004 - abs(q.y - shelf - 0.02)));
        }
    } else {
        // The sea: lighter toward the horizon, mirroring the sky in broken bands.
        float t = clamp((HORIZON - q.y) / HORIZON, 0.0, 1.0);
        col = mix(rgb(22, 48, 70), rgb(8, 20, 34), steps(t, 6.0));
        float ripple = 0.006 * sin(q.y * 520.0 + q.x * 30.0) * (0.3 + t);
        vec2 m = vec2(q.x + ripple, 2.0 * HORIZON - q.y);
        float breakup = band(vnoise(vec2(q.x * 12.0, q.y * 260.0)), 0.35);
        vec4 a = auroraTiers(auroraGlow(m));
        col = mix(col, mix(a.rgb, rgb(16, 40, 60), 0.5), a.a * 0.45 * breakup);
        // Mirrored mountains, dark.
        float h0 = 0.36 + 0.2 * ridge(m.x + 1.0, 2.4, 3.0);
        col = mix(col, rgb(18, 38, 60), below(h0, m.y) * 0.8 * breakup);
        // The ice city, mirrored faintly and broken by the swell.
        col = mix(col, rgb(56, 88, 118), citySilhouette(m, cx0, cx1, aspect) * 0.45 * band(vnoise(vec2(q.x * 10.0, q.y * 300.0)), 0.3));
        // The moon's path, in broken dashes.
        float path = cover(0.035 * (1.0 - t * 0.4) - abs(q.x - moon.x + 0.01 * sin(q.y * 90.0)));
        float dash = band(vnoise(vec2(q.x * 70.0, q.y * 300.0)), 0.55);
        col = mix(col, rgb(200, 222, 238), path * dash * (1.0 - 0.5 * t));
        // The city's lights trail across the water, one under each lamp on the wall.
        for (int i = 0; i < 16; i++) {
            float lx = (ceil((cx0 - 0.022) / 0.045) + float(i)) * 0.045 + 0.022;
            if (lx > cx1)
                break;
            float streak = cover(0.0014 - abs(q.x - lx)) * cover(q.y - HORIZON + 0.07 + 0.02 * hash(vec2(float(i), 3.0)));
            col = mix(col, rgb(255, 190, 110), streak * band(vnoise(vec2(lx * 50.0, q.y * 420.0)), 0.45) * 0.75);
        }
        // Long swells.
        col = mix(col, rgb(40, 74, 100), band(vnoise(vec2(q.x * 5.0, q.y * 180.0)), 0.82) * 0.6);
    }

    // Icebergs on the waterline, with their reflections.
    col = berg(col, q, aspect * 0.1, 0.08, 0.15, 0.085, 1.0, HORIZON - 0.02);
    col = berg(col, q, aspect * 0.87, 0.19, 0.1, 0.14, 2.0, HORIZON - 0.04);
    col = berg(col, q, aspect * 0.71, 0.03, 0.065, 0.04, 3.0, HORIZON - 0.09);

    // A canoe with a lantern, gliding home.
    vec2 cn = vec2(aspect * 0.45, 0.17);
    vec2 co = (q - cn) / vec2(0.075, 0.014);
    // Hull: flat-topped, its ends sweeping up; lit along the gunwale by the lantern.
    float hull = cover(1.0 - length(vec2(co.x, min(co.y, 0.0) * 1.0))) * cover(0.25 + 0.9 * co.x * co.x * co.x * co.x - co.y) * cover(co.y + 1.0);
    col = mix(col, rgb(70, 52, 46), hull);
    col = mix(col, rgb(196, 140, 92), hull * cover(co.y - 0.0 - 0.9 * co.x * co.x * co.x * co.x + 0.12));
    // A paddler's silhouette.
    vec2 fig = q - cn - vec2(-0.02, 0.012);
    col = mix(col, rgb(24, 30, 40), cover(0.007 - length(fig * vec2(1.0, 0.6))) * cover(fig.y));
    col = mix(col, rgb(24, 30, 40), cover(0.0045 - length(fig - vec2(0.0, 0.022))));
    col = mix(col, rgb(24, 30, 40), cover(0.0012 - abs(fig.x - 0.012 - (fig.y - 0.01) * 0.5)) * cover(fig.y + 0.02) * cover(0.03 - fig.y));
    col = mix(col, rgb(255, 200, 120), cover(0.004 - length(q - cn - vec2(0.045, 0.018))));
    col = mix(col, mix(col, rgb(255, 200, 120), 0.18), cover(0.02 - length(q - cn - vec2(0.045, 0.018))));
    // Its wake: two short broken lines spreading back from the stern, fading.
    vec2 stern = cn + vec2(-0.07, -0.012);
    float back = stern.x - q.x;
    if (back > 0.0 && back < 0.2) {
        float fadeW = 1.0 - back / 0.2;
        for (int i = 0; i < 2; i++) {
            float spread = i == 0 ? 0.1 : -0.16;
            float line = cover(0.0013 * (0.5 + fadeW) - abs(q.y - stern.y - spread * back));
            float dash = step(0.38, vnoise(vec2(back * 90.0, float(i) * 5.0)));
            col = mix(col, rgb(96, 138, 168), line * dash * fadeW);
        }
    }

    // A snow bank in the foreground, shaded on its far side.
    float sb = 0.04 + 0.1 * pow(max(q.x / aspect - 0.45, 0.0) / 0.55, 1.3) + 0.012 * billows(q.x, 5.0, 2.0);
    col = mix(col, rgb(120, 152, 184), below(sb, q.y));
    col = mix(col, rgb(206, 224, 238), below(sb - 0.008, q.y) * cover(q.y - sb + 0.04));
    float sb2 = 0.02 + 0.05 * pow(max(0.4 - q.x / aspect, 0.0) / 0.4, 1.5) + 0.01 * billows(q.x + 3.0, 7.0, 4.0);
    col = mix(col, rgb(120, 152, 184), below(sb2, q.y));
    col = mix(col, rgb(206, 224, 238), below(sb2 - 0.006, q.y) * cover(q.y - sb2 + 0.03));

    // Falling snow.
    for (int i = 0; i < 70; i++) {
        vec2 h = hash2(vec2(float(i), 2.4));
        vec2 f = vec2(h.x * aspect, h.y);
        float r = mix(0.0012, 0.003, hash(vec2(float(i), 7.0)));
        col = mix(col, rgb(226, 238, 246), cover(r - length(q - f)) * 0.8);
    }
    fragColor = vec4(col, 1.0);
}
