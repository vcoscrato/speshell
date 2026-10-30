#version 440
#extension GL_GOOGLE_include_directive : enable
// Cloud sea at dawn: an air temple on the tallest of a cluster of stone spires,
// prayer flags strung to its neighbour, above a sea of sunlit clouds. The sun
// rises behind thin streaks of high cloud through an indigo-to-saffron sky, a
// flock crosses its light, and a wind-bent pine on a ledge sheds leaves.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
} u;
#include "../../effects/common/common.glsl"
#include "../landscape.glsl"

// Five-stop sky ramp.
vec3 sky(float t) {
    vec3 a = rgb(252, 214, 150), b = rgb(242, 164, 84), c = rgb(196, 112, 106);
    vec3 d = rgb(98, 78, 118), e = rgb(36, 40, 74);
    if (t < 0.25) return mix(a, b, t / 0.25);
    if (t < 0.5) return mix(b, c, (t - 0.25) / 0.25);
    if (t < 0.75) return mix(c, d, (t - 0.5) / 0.25);
    return mix(d, e, (t - 0.75) / 0.25);
}

// A stone spire around x = c rising to `top`: lit on its sun-facing left side,
// with darker strata, a saffron rim on the lit edge, and a level summit `plateau` wide.
vec3 spire(vec3 col, vec2 q, float c, float top, float w, float plateau, float seed,
           vec3 lit, vec3 shade, vec3 rim) {
    float dx = q.x - c + (vnoise(vec2(q.y * 9.0, seed)) - 0.5) * w * 0.35;
    float side = max(abs(dx) - plateau, 0.0) / w;
    float h = top - pow(side, 1.5) * 0.9 * top + (vnoise(vec2(q.x * 80.0, seed)) - 0.5) * 0.006;
    float inside = below(h, q.y) * cover(1.0 - side);
    if (inside <= 0.0)
        return col;
    float ridgeLine = (vnoise(vec2(q.y * 14.0, seed + 1.0)) - 0.5) * w * 0.5;
    vec3 rock = dx < ridgeLine ? lit : shade;
    float strata = vnoise(vec2(q.x * 8.0, q.y * 70.0 + seed));
    rock = mix(rock, shade * 0.8, band(strata, 0.78) * 0.7);
    // Sun-facing edge: a thin line inside the silhouette, where the spire is
    // side = sideEdge wide at this height.
    float sideEdge = min(pow(max(top - q.y, 0.0) / (0.9 * top), 1.0 / 1.5), 1.0);
    rock = mix(rock, rim, cover(0.0035 - (sideEdge - side) * w) * step(dx, 0.0));
    return mix(col, rock, inside);
}

// An air temple standing on (c, base), `s` its overall scale.
vec3 temple(vec3 col, vec2 q, vec2 base, float s, vec3 wall, vec3 wallShade, vec3 roof,
            vec3 roofLit, vec3 glow) {
    vec2 p = (q - base) / s;
    float ax = abs(p.x);
    // Tiers of wall, each under a roof whose eaves turn up at the tips.
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        float y0 = fi * 0.9;
        float ww = 0.9 - 0.42 * fi;
        float wallIn = cover(ww - ax) * cover(p.y - y0) * cover(y0 + 0.45 - p.y);
        col = mix(col, p.x < -ww * 0.15 ? wall : wallShade, wallIn);
        // Glowing windows.
        float wx = fract(p.x / 0.3 + 0.5) - 0.5;
        float win = cover(0.11 - abs(wx)) * cover(0.12 - abs(p.y - y0 - 0.22)) * cover(ww - 0.12 - ax);
        col = mix(col, glow, wallIn * win);
        float ry = p.y - (y0 + 0.4);
        float rw = (ww + 0.38) - ry * 1.15;
        float eave = 0.16 * pow(clamp(ax / (ww + 0.38), 0.0, 1.0), 6.0);
        float roofIn = cover(rw - ax) * cover(ry - eave) * cover(0.36 - ry);
        col = mix(col, p.x < 0.0 ? roofLit : roof, roofIn);
    }
    // The central tower: a tall slender cone with a saffron finial.
    float ty = p.y - 1.66;
    float tw = 0.2 * pow(clamp(1.0 - ty / 1.5, 0.0, 1.0), 1.3);
    col = mix(col, p.x < 0.0 ? roofLit : roof, cover(tw - ax) * cover(ty) * cover(1.5 - ty));
    col = mix(col, glow, cover(0.07 - length(p - vec2(0.0, 3.2))));
    // Two corner towers.
    for (int k = 0; k < 2; k++) {
        float sx = k == 0 ? -1.0 : 1.0;
        vec2 o = p - vec2(sx * 0.95, 0.8);
        float cw = 0.12 * clamp(1.0 - o.y / 0.8, 0.0, 1.0);
        col = mix(col, sx < 0.0 ? roofLit : roof, cover(cw - abs(o.x)) * cover(o.y) * cover(0.8 - o.y));
    }
    return col;
}

// A bird of span s at c, wings beating at phase ph.
float bird(vec2 q, vec2 c, float s, float ph) {
    vec2 p = (q - c) / s;
    float ax = abs(p.x);
    if (ax > 1.0)
        return 0.0;
    float y = (0.5 * sin(ph) + 0.2) * ax - 0.35 * ax * ax;
    return cover((0.14 * (1.0 - ax) + 0.04) - abs(p.y - y)) ;
}

// A leaf of length s at c, turned by a: two flat halves, lit and shaded.
vec3 leaf(vec3 col, vec2 q, vec2 c, float s, float a, vec3 lit, vec3 shade) {
    vec2 p = rot(q - c, a) / s;
    float d = length(p * vec2(1.0, 2.6)) - 1.0;
    if (d > 0.3)
        return col;
    return mix(col, p.y > 0.0 ? lit : shade, cover(-d * s));
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    float aspect = u.resolution.x / u.resolution.y;
    vec2 sun = vec2(aspect * 0.3, 0.43);
    float ds = length(q - sun);

    // Sky in flat bands, warmest around the sun.
    float t = clamp((q.y - 0.36) / 0.64, 0.0, 1.0);
    t = pow(t, 0.75) - 0.12 * exp(-ds * 3.0) + (fbm(vec2(q.x * 1.2, q.y * 4.0)) - 0.5) * 0.04;
    vec3 col = sky(steps(clamp(t, 0.0, 1.0), 11.0));

    // Rays fanning from the sun.
    float ang = atan(q.y - sun.y, q.x - sun.x);
    float rays = band(vnoise(vec2(ang * 7.0, 3.0)) + 0.15 * vnoise(vec2(ang * 23.0, 8.0)), 0.66);
    col = mix(col, rgb(255, 228, 176), rays * 0.13 * exp(-ds * 2.2) * cover(q.y - 0.36));

    // High cloud streaks: violet with sunlit undersides.
    float env = smoothstep(0.5, 0.62, q.y) * (1.0 - smoothstep(0.88, 0.98, q.y));
    float n = fbm(vec2(q.x * 1.4, q.y * 13.0) + vec2(4.0, 1.0)) + 0.25 * vnoise(vec2(q.x * 6.0, q.y * 40.0));
    float nLow = fbm(vec2(q.x * 1.4, (q.y + 0.009) * 13.0) + vec2(4.0, 1.0)) + 0.25 * vnoise(vec2(q.x * 6.0, (q.y + 0.009) * 40.0));
    float streak = band(n * env, 0.56);
    float warm = exp(-abs(q.x - sun.x) * 1.4);
    col = mix(col, mix(rgb(150, 98, 128), rgb(214, 128, 118), warm), streak);
    col = mix(col, mix(rgb(232, 150, 124), rgb(255, 206, 150), warm), streak * (1.0 - band(nLow * env, 0.56)));

    // The sun, in a soft ring of light.
    col = mix(col, mix(col, rgb(255, 226, 170), 0.12), cover(0.2 - ds));
    col = mix(col, mix(col, rgb(255, 232, 186), 0.25), cover(0.12 - ds));
    col = mix(col, rgb(255, 238, 200), cover(0.062 - ds));

    // A flock crossing the light.
    for (int i = 0; i < 9; i++) {
        float fi = float(i);
        vec2 b = sun + vec2(0.1 + 0.035 * fi + 0.02 * hash(vec2(fi, 2.0)), 0.13 + 0.022 * abs(fi - 4.0) + 0.02 * hash(vec2(fi, 5.0)));
        col = mix(col, rgb(84, 56, 78), bird(q, b, mix(0.006, 0.01, hash(vec2(fi, 9.0))), fi * 1.7));
    }

    // Far spires, pale with distance.
    col = spire(col, q, aspect * 0.08, 0.5, 0.035, 0.004, 1.0, rgb(214, 150, 134), rgb(190, 128, 128), rgb(246, 196, 150));
    col = spire(col, q, aspect * 0.47, 0.44, 0.03, 0.003, 2.0, rgb(222, 160, 136), rgb(200, 138, 130), rgb(250, 206, 156));
    col = spire(col, q, aspect * 0.93, 0.52, 0.04, 0.004, 3.0, rgb(206, 140, 134), rgb(182, 120, 128), rgb(246, 196, 150));

    // Far cloud banks, bright with sun.
    float h0 = 0.36 + 0.02 * billows(q.x, 11.0, 1.0);
    float h1 = 0.32 + 0.035 * billows(q.x + 0.3, 6.5, 2.0);
    float rimSun = exp(-abs(q.x - sun.x) * 1.8);
    col = mix(col, rgb(250, 206, 156), below(h0, q.y));
    col = mix(col, rgb(236, 170, 138), below(h1, q.y));
    col = mix(col, mix(rgb(248, 196, 152), rgb(255, 230, 186), rimSun), below(h1, q.y) * (1.0 - below(h1 - 0.006, q.y)));

    // The temple spires.
    vec3 lit = rgb(158, 96, 90), shade = rgb(84, 56, 76), rim = rgb(250, 182, 96);
    float mainX = aspect * 0.74;
    col = spire(col, q, aspect * 0.635, 0.6, 0.05, 0.006, 4.0, lit, shade, rim);
    col = spire(col, q, aspect * 0.85, 0.66, 0.055, 0.008, 5.0, lit, shade, rim);
    col = spire(col, q, mainX, 0.74, 0.075, 0.062, 6.0, lit, shade, rim);
    col = temple(col, q, vec2(mainX, 0.737), 0.056, rgb(238, 220, 192), rgb(196, 166, 150),
                 rgb(52, 92, 122), rgb(96, 150, 182), rgb(255, 196, 104));

    // Prayer flags strung from the temple to the left spire, sagging between.
    vec2 fa = vec2(aspect * 0.635 + 0.004, 0.6), fb = vec2(mainX - 0.062, 0.73);
    float ft = (q.x - fa.x) / (fb.x - fa.x);
    if (ft > 0.0 && ft < 1.0) {
        float ly = mix(fa.y, fb.y, ft) - 0.05 * 4.0 * ft * (1.0 - ft);
        col = mix(col, rgb(70, 48, 62), cover(0.0012 - abs(q.y - ly)));
        float slot = floor((q.x - fa.x) / 0.011);
        float fx = (q.x - fa.x) - (slot + 0.5) * 0.011;
        float fl = 1.0 - abs(fx) / 0.0042;
        float flag = cover(fl) * cover(ly - q.y) * cover(q.y - (ly - 0.013 * fl));
        int ci = int(mod(slot, 5.0));
        vec3 fc = ci == 0 ? rgb(244, 160, 60) : ci == 1 ? rgb(244, 232, 210) : ci == 2 ? rgb(106, 176, 224)
                : ci == 3 ? rgb(196, 84, 62) : rgb(246, 204, 92);
        col = mix(col, fc, flag * step(0.04, ft) * step(ft, 0.96));
    }

    // Nearer cloud banks swallow the spires' feet, darker toward the viewer.
    float h2 = 0.27 + 0.045 * billows(q.x + 0.7, 4.2, 3.0);
    float h3 = 0.17 + 0.06 * billows(q.x + 1.3, 2.8, 4.0);
    float h4 = 0.05 + 0.08 * billows(q.x + 2.1, 1.9, 5.0);
    col = mix(col, rgb(204, 138, 134), below(h2, q.y));
    col = mix(col, mix(rgb(238, 174, 140), rgb(252, 214, 166), rimSun), below(h2, q.y) * (1.0 - below(h2 - 0.008, q.y)));
    // Each bank in two tones: shaded lobes bulge from under its lit face.
    float u2 = h2 - 0.05 + 0.03 * billows(q.x + 5.1, 6.0, 13.0);
    col = mix(col, rgb(184, 122, 128), below(u2, q.y) * below(h2, q.y));
    col = mix(col, rgb(152, 104, 124), below(h3, q.y));
    col = mix(col, mix(rgb(208, 144, 134), rgb(238, 182, 146), rimSun), below(h3, q.y) * (1.0 - below(h3 - 0.01, q.y)));
    float u3 = h3 - 0.06 + 0.04 * billows(q.x + 3.3, 4.4, 14.0);
    col = mix(col, rgb(128, 90, 116), below(u3, q.y));
    col = mix(col, rgb(98, 74, 104), below(h4, q.y));
    col = mix(col, rgb(160, 112, 124), below(h4, q.y) * (1.0 - below(h4 - 0.012, q.y)));
    float u4 = h4 - 0.07 + 0.05 * billows(q.x + 7.7, 3.0, 15.0);
    col = mix(col, rgb(78, 60, 92), below(u4, q.y));

    // A ledge in the lower left with a wind-bent pine.
    float ledge = 0.2 - pow(max(q.x - 0.05, 0.0) / 0.42, 1.6) * 0.2 + (vnoise(vec2(q.x * 40.0, 3.0)) - 0.5) * 0.012;
    col = mix(col, rgb(52, 36, 54), below(ledge, q.y) * cover(0.5 - q.x));
    col = mix(col, rgb(122, 76, 76), below(ledge, q.y) * (1.0 - below(ledge - 0.006, q.y)) * cover(0.5 - q.x));
    // Trunk: a curve leaning downwind, thinning as it climbs.
    float ty = (q.y - 0.17) / 0.3;
    if (ty > 0.0 && ty < 1.0) {
        float tx = 0.15 + 0.11 * ty * ty + 0.015 * sin(ty * 7.0);
        col = mix(col, rgb(46, 32, 46), cover(mix(0.012, 0.003, ty) - abs(q.x - tx)));
    }
    // Foliage: ragged tiers on short branches, swept downwind to the right.
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float at = 0.42 + 0.18 * fi;
        vec2 base = vec2(0.15 + 0.11 * at * at + 0.015 * sin(at * 7.0), 0.17 + 0.3 * at);
        float reach = 0.075 - 0.012 * fi;
        // The branch, rising gently downwind.
        float bt = clamp((q.x - base.x) / reach, 0.0, 1.0);
        float by = base.y + 0.012 * bt;
        col = mix(col, rgb(46, 32, 46), cover(0.0025 * (1.0 - 0.6 * bt) - abs(q.y - by)) * step(base.x, q.x) * step(q.x, base.x + reach));
        float clump = 1e3;
        for (int k = 0; k < 3; k++) {
            float fk = float(k);
            vec2 c = base + vec2((0.25 + 0.33 * fk) * reach, 0.013 + 0.004 * fk);
            vec2 p = (q - c) / vec2(reach * (0.42 - 0.06 * fk), 0.017 - 0.002 * fk);
            clump = min(clump, length(p) - 1.0 + 0.45 * (vnoise(vec2(q.x * 70.0, q.y * 30.0 + fi * 5.0 + fk)) - 0.5));
        }
        col = mix(col, rgb(50, 62, 68), cover(-clump));
        col = mix(col, rgb(96, 112, 98), cover(-clump - 0.25) * cover(q.y - base.y - 0.016));
    }

    // Leaves riding the wind across the clouds.
    for (int i = 0; i < 34; i++) {
        float fi = float(i);
        vec2 h = hash2(vec2(fi, 6.1));
        vec2 c = vec2(0.22 + h.x * (aspect - 0.3), 0.1 + 0.55 * h.y * (1.0 - 0.6 * h.x));
        float s = mix(0.004, 0.009, hash(vec2(fi, 3.0)));
        col = leaf(col, q, c, s, h.x * 9.0 + fi, rgb(246, 168, 66), rgb(196, 106, 52));
    }

    fragColor = vec4(col, 1.0);
}
