#version 440
#extension GL_GOOGLE_include_directive : enable
// Polar night: aurora curtains ripple over moonlit glacier peaks and are mirrored
// in a still polar sea. An ice city of domes and a tall tower glows warm on the
// far shore, faceted icebergs drift, both mirrored too, a canoe carries a lantern
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

// Aurora over the sky at q: rgb, and how strongly it shows (0..1).
vec4 aurora(vec2 q, float aspect) {
    vec4 best = vec4(0.0);
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float yb = 0.55 + 0.05 * fi + 0.07 * sin(q.x * 2.1 + fi * 1.9) + 0.035 * sin(q.x * 5.3 + fi * 3.7);
        float hgt = (0.2 + 0.08 * fi) * (0.6 + 0.6 * vnoise(vec2(q.x * 3.0, fi * 4.0)));
        float rel = (q.y - yb) / hgt;
        if (rel < 0.0 || rel > 1.8)
            continue;
        float span = smoothstep(0.05 + 0.4 * fi, 0.35 + 0.4 * fi, q.x) * smoothstep(aspect - 0.1 * fi, aspect - 0.5 - 0.2 * fi, q.x);
        // A smooth curtain in flat tiers, brightest at its lower edge and fading
        // through fainter ones toward its top, with thin rays of light rising
        // through it and past it, each dying out at its own height.
        float ray = band(vnoise(vec2(q.x * 130.0 + fi * 13.0, fi)), 0.72);
        float rayTop = 1.0 + 0.75 * vnoise(vec2(q.x * 45.0 + fi * 7.0, fi + 9.0));
        // The faint tier is the same curtain drawn taller, so it thins out at its
        // ends as the curtain does.
        float s1 = pow(max(0.0, 1.0 - rel / 1.3), 1.3) * span * (1.0 - 0.2 * fi);
        float rn = 0.6 * vnoise(vec2(q.x * 130.0 + fi * 13.0, fi)) + 0.4 * vnoise(vec2(q.x * 390.0, fi + 3.0));
        vec4 c = vec4(rgb(56, 156, 170), s1 > 0.12 ? 0.3 : 0.0);
        if (rel > 1.0) {
            // Thinning as it rises, so each ends in a point.
            float up = (rel - 1.0) / max(rayTop - 1.0, 1e-3);
            float thin = band(rn, 0.7 + 0.25 * up) * step(0.45, vnoise(vec2(q.x * 18.0, fi + 5.0)));
            float k = thin * step(0.3, span) * step(up, 1.0) * (up < 0.45 ? 0.3 : 0.16);
            if (k > c.a)
                c = vec4(rgb(84, 214, 176), k);
        } else {
            float s0 = pow(1.0 - rel, 1.3) * span * (1.0 - 0.2 * fi);
            vec3 cc = s0 > 0.55 ? rgb(150, 250, 200) : (s0 > 0.3 ? rgb(84, 214, 176) : rgb(56, 156, 170));
            cc = mix(cc, s0 > 0.55 ? rgb(214, 255, 236) : rgb(140, 240, 200), ray * 0.7 * smoothstep(1.0, 0.2, rel));
            cc = mix(cc, rgb(214, 255, 236), cover(0.03 - rel) * step(0.3, s0));
            float k = s0 > 0.3 ? 1.0 : (s0 > 0.12 ? 0.55 : 0.0);
            // The rays carry the faint tiers up with them.
            k = max(k, band(rn, 0.7) * step(0.12, s1) * (s0 > 0.04 ? 0.55 : 0.3));
            if (k > c.a)
                c = vec4(cc, k);
        }
        if (c.a > best.a)
            best = c;
    }
    return best;
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

// A faceted iceberg around x = c on the waterline, `w` half wide, `ht` tall; its
// faces lit by the moon or in shade, mirrored in the water below.
vec3 berg(vec3 col, vec2 q, float c, float w, float ht, float seed, float water) {
    float dx = (q.x - c) / w;
    if (abs(dx) > 1.0)
        return col;
    float k = floor((dx + 1.0) * 3.0);
    float f0 = hash(vec2(k, seed)), f1 = hash(vec2(k + 1.0, seed));
    float tf = fract((dx + 1.0) * 3.0);
    float prof = mix(f0, f1, tf) * 0.5 + 0.5;
    float h = water + ht * prof * pow(1.0 - abs(dx), 0.5);
    bool litFace = f1 < f0;
    vec3 face = litFace ? rgb(214, 232, 244) : rgb(110, 150, 186);
    if (q.y >= water) {
        col = mix(col, face, below(h, q.y));
    } else {
        float my = 2.0 * water - q.y + 0.004 * sin(q.y * 400.0);
        col = mix(col, mix(face, rgb(16, 36, 56), 0.55), below(h, my) * cover(q.y - water + ht * 0.8));
    }
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
        vec4 a = aurora(q, aspect);
        col = mix(col, a.rgb, a.a);
        // The moon and its halo.
        float dm = length(q - moon);
        col = mix(col, mix(col, rgb(180, 210, 230), 0.12), cover(0.12 - dm));
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
        vec4 a = aurora(m, aspect);
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
    col = berg(col, q, aspect * 0.12, 0.11, 0.09, 1.0, HORIZON - 0.02);
    col = berg(col, q, aspect * 0.86, 0.15, 0.13, 2.0, HORIZON - 0.04);
    col = berg(col, q, aspect * 0.72, 0.05, 0.04, 3.0, HORIZON - 0.09);

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
