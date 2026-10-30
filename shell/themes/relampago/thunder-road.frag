#version 440
#extension GL_GOOGLE_include_directive : enable
// Thunder road: a two-lane desert highway runs straight to the horizon at dusk.
// Red mesas and buttes stand along it, lit orange on the sunset side, while a
// thunderstorm towers over the left and a bolt strikes the plain. Telephone poles
// march along the road, a neon arrow glows at a roadside stop, saguaros stand in
// the scrub, and the tail lights of something very fast streak away down the
// right lane.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
} u;
#include "../../effects/common/common.glsl"
#include "../landscape.glsl"

const float HORIZON = 0.37;

// Five-stop dusk ramp, horizon to zenith.
vec3 sky(float t) {
    vec3 a = rgb(255, 190, 96), b = rgb(242, 116, 62), c = rgb(186, 58, 82), d = rgb(92, 38, 98), e = rgb(30, 22, 60);
    if (t < 0.18) return mix(a, b, t / 0.18);
    if (t < 0.4) return mix(b, c, (t - 0.18) / 0.22);
    if (t < 0.68) return mix(c, d, (t - 0.4) / 0.28);
    return mix(d, e, (t - 0.68) / 0.32);
}

// Where a bolt that falls from y0 to y1 around a line from x0 to x1 is at height y:
// kinked by a coarse zig and a fine one.
float boltX(float y, float x0, float x1, float y0, float y1, float amp, float seed) {
    return mix(x0, x1, (y0 - y) / (y0 - y1)) + amp * (zig(y / 0.035, seed) + 0.45 * zig(y / 0.011, seed + 3.0));
}

// The distance from p to that bolt, straight runs between the corners where either
// zig kinks, and how far along it p is (0..1 from the top).
vec2 boltDist(vec2 p, float x0, float x1, float y0, float y1, float amp, float seed) {
    float d = 1e3;
    float k0 = floor(p.y / 0.011);
    for (int j = -2; j <= 2; j++) {
        float ya = (k0 + float(j)) * 0.011, yb = ya + 0.011;
        vec2 a = vec2(boltX(ya, x0, x1, y0, y1, amp, seed), ya);
        vec2 b = vec2(boltX(yb, x0, x1, y0, y1, amp, seed), yb);
        // At most one coarse corner falls between two fine ones.
        float ym = ceil(ya / 0.035) * 0.035;
        if (ym < yb) {
            vec2 m = vec2(boltX(ym, x0, x1, y0, y1, amp, seed), ym);
            d = min(d, min(sdSeg(p, a, m), sdSeg(p, m, b)));
        } else {
            d = min(d, sdSeg(p, a, b));
        }
    }
    return vec2(d, (y0 - p.y) / (y0 - y1));
}

// A mesa or butte: flat-topped with steep walls above a talus skirt, lopsided, and
// sometimes carrying a narrower second tier. Returns its height at x (< 0 outside)
// and where x sits across it (-1 left wall .. 1 right wall) in .y.
struct Mesa { float cx; float wl; float wr; float ht; float tier; float tilt; };

Mesa mesaAt(float c, float cell, float tall, float seed) {
    Mesa m;
    float h0 = hash(vec2(c, seed)), h1 = hash(vec2(c, seed + 1.0)), h2 = hash(vec2(c, seed + 2.0));
    float h3 = hash(vec2(c, seed + 3.0)), h4 = hash(vec2(c, seed + 4.0));
    float w = cell * mix(0.08, 0.46, h1 * h1);
    m.cx = (c + 0.2 + 0.6 * h0) * cell;
    m.wl = w * mix(0.7, 1.3, h3);
    m.wr = w * mix(0.7, 1.3, h4);
    // Narrow ones stand tall as buttes and spires; broad ones sit low.
    m.ht = tall * mix(0.45, 1.0, h2) * mix(1.25, 0.6, smoothstep(0.1, 0.4, w / cell));
    m.tier = hash(vec2(c, seed + 5.0)) < 0.35 ? mix(0.25, 0.5, h0) : 0.0;
    m.tilt = (hash(vec2(c, seed + 6.0)) - 0.5) * 0.25;
    if (hash(vec2(c, seed + 7.0)) < 0.25)
        m.ht = -1.0;
    return m;
}

vec2 mesaTop(Mesa m, float x) {
    float d = x - m.cx;
    float w = d < 0.0 ? m.wl : m.wr;
    float r = abs(d) / w;
    if (m.ht < 0.0 || r > 1.6)
        return vec2(-1.0, 0.0);
    // Cliff wall to r = 1, then a talus slope out to 1.6.
    float wall = 1.0 - smoothstep(0.92, 1.0, r);
    float talus = 0.42 * pow(max(0.0, 1.0 - (r - 0.9) / 0.7), 1.6) * step(0.9, r);
    float h = m.ht * max(wall * (1.0 + m.tilt * d / w), talus);
    // A narrower upper tier, and crags along the rim.
    if (m.tier > 0.0)
        h += m.ht * m.tier * (1.0 - smoothstep(0.42, 0.48, abs(d + 0.2 * w * m.tilt) / w)) * wall;
    h += (vnoise(vec2(d * 90.0, m.cx * 13.0)) - 0.5) * 0.012 * step(r, 1.0)
       + (vnoise(vec2(d * 300.0, m.cx * 7.0)) - 0.5) * 0.004;
    return vec2(h, clamp(d / w, -1.0, 1.0));
}

// Signed distance to a saguaro at base b (q units) of height h: a trunk and up to
// two arms that bend up at a rounded elbow.
float saguaro(vec2 q, vec2 b, float h, float seed) {
    vec2 p = q - b;
    float w = h * 0.075;
    float d = sdSeg(p, vec2(0.0, -w), vec2(0.0, h - w)) - w;
    for (int i = 0; i < 2; i++) {
        float side = i == 0 ? -1.0 : 1.0;
        if (seed > 2.5 && hash(vec2(seed, float(i))) < 0.3)
            continue;
        float ay = h * mix(0.3, 0.5, hash(vec2(seed, float(i) + 4.0)));
        float ax = side * h * mix(0.2, 0.27, hash(vec2(seed, float(i) + 6.0)));
        float top = ay + h * mix(0.2, 0.36, hash(vec2(seed, float(i) + 8.0)));
        float aw = w * 0.78;
        float elbow = abs(ax) * 0.45;
        float arm = min(sdSeg(p, vec2(0.0, ay), vec2(ax - side * elbow, ay)),
                        sdSeg(p, vec2(ax, ay + elbow), vec2(ax, top)));
        // The elbow: a quarter circle joining the two.
        vec2 e = p - vec2(ax - side * elbow, ay + elbow);
        if (e.y < 0.0 && e.x * side > 0.0)
            arm = min(arm, abs(length(e) - elbow));
        d = min(d, arm - aw);
    }
    return d;
}

// ── The storm's tower of billows (see stormDist) ──
const int PUFFS = 34;
const int MID = 11;         // where the middle and the front puffs start among them
const int FRONT = 22;
float PX;                   // one pixel, in q

// Coverage of a signed distance in q, without derivatives, so it is safe anywhere.
float fill(float d) {
    return smoothstep(PX, -PX, d);
}

// Smooth maximum of two distances, rounding the corner where they meet by k.
float smax(float a, float b, float k) {
    float h = clamp(0.5 - 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) + k * h * (1.0 - h);
}

// The tower's height at x: tallest over the left, falling away to the right.
float stormTop(float x) {
    return 0.95 - 0.27 * smoothstep(0.4, 0.8, x);
}

// Its flat underside at x, lumpy with small billows hanging from it.
float stormBelly(float x) {
    return 0.6 + 0.012 * vnoise(vec2(x * 9.0, 1.0)) - 0.007 * lobes(x, 11.0, 3.0);
}

// Billow i: its center and radius in z, the higher first, so the lower stand in front.
vec3 stormPuff(int i) {
    float fi = float(i);
    float t = 1.0 - fi / float(PUFFS - 1);
    float x = mix(-0.08, 0.72, hash(vec2(fi, 11.0)));
    float r = mix(0.06, 0.11, hash(vec2(fi, 13.0))) * mix(1.0, 0.55, smoothstep(0.3, 0.78, x)) * mix(0.8, 1.0, t);
    float y = mix(0.6 + r * 0.35, stormTop(x) - r * 0.75, t);
    return vec3(x, y, r);
}

// The distance to the edge of the tower's billows from `from` on, its underside cut
// off with a rounded corner. From 0 it is the whole tower: a core under its top that
// fills the gaps between the billows, and small billows along its top that make its
// outline lumpy.
float stormDist(vec2 q, int from) {
    float d = 1e5;
    if (from == 0) {
        d = max(q.y - stormTop(q.x) + 0.06, q.x - 0.68);
        for (int k = 0; k < 18; k++) {
            vec2 h = hash2(vec2(float(k), 31.0));
            float x = mix(-0.06, 0.76, (float(k) + 0.2 + 0.6 * h.x) / 18.0);
            float r = mix(0.03, 0.055, h.y) * mix(1.0, 0.65, smoothstep(0.3, 0.78, x));
            d = min(d, length(q - vec2(x, stormTop(x) - r * 0.9)) - r);
        }
    }
    for (int i = from; i < PUFFS; i++) {
        vec3 o = stormPuff(i);
        d = min(d, length(q - o.xy) - o.z);
    }
    return smax(d, stormBelly(q.x) - q.y, 0.02);
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    PX = 1.0 / u.resolution.y;
    float aspect = u.resolution.x / u.resolution.y;
    vec2 sun = vec2(aspect * 0.78, HORIZON + 0.035);
    float ds = length((q - sun) * vec2(1.0, 1.15));
    float vpx = aspect * 0.5;

    // ── Sky: flat dusk bands bowing up around the sun, stars overhead ──
    float t = clamp((q.y - HORIZON) / (1.0 - HORIZON), 0.0, 1.0);
    t = pow(t, 0.85) - 0.12 * exp(-ds * 2.6) + (fbm(vec2(q.x * 1.1, q.y * 3.0)) - 0.5) * 0.05;
    vec3 col = sky(steps(clamp(t, 0.0, 1.0), 11.0));
    for (int i = 0; i < 2; i++) {
        vec2 cell = floor(q * (90.0 + 70.0 * float(i)));
        vec2 h = hash2(cell + float(i) * 17.0);
        vec2 sp = (cell + 0.2 + 0.6 * h) / (90.0 + 70.0 * float(i));
        float tw = hash(cell + 3.1);
        float star = cover(mix(0.0006, 0.0014, tw) - length(q - sp)) * step(0.93, h.x) * smoothstep(0.78, 0.95, q.y);
        col = mix(col, rgb(255, 238, 214), star * 0.85);
    }
    // The sun, half sunk, in rings of glow and with streaks of cloud across it.
    col = mix(col, mix(col, rgb(255, 214, 120), 0.35), cover(0.16 - ds));
    col = mix(col, mix(col, rgb(255, 228, 150), 0.5), cover(0.095 - ds));
    float disk = cover(0.06 - ds);
    vec3 sunCol = mix(rgb(255, 232, 160), rgb(255, 160, 72), steps(clamp((sun.y + 0.06 - q.y) / 0.12, 0.0, 1.0), 3.0));
    col = mix(col, sunCol, disk);
    float slit = band(fbm(vec2(q.x * 3.0, q.y * 46.0)), 0.6) * smoothstep(HORIZON + 0.01, HORIZON + 0.03, q.y)
               * (1.0 - smoothstep(HORIZON + 0.13, HORIZON + 0.16, q.y));
    col = mix(col, mix(rgb(176, 64, 80), rgb(255, 150, 90), exp(-abs(q.x - sun.x) * 3.0)), slit * 0.85);

    // ── The thunderstorm: a cumulonimbus of billows heaped over the left, flat
    //    underneath, its anvil spreading across the sky. It is shaded from the
    //    sunset (right, low), rimmed where the light catches it, and lit from
    //    within where the bolt leaves it ──
    float bx0 = 0.5;                               // where the bolt leaves the cloud
    float base = 0.6 + 0.012 * vnoise(vec2(q.x * 9.0, 1.0));
    float storm = 0.0;

    // The anvil: a flat sheet spread along the top, its scalloped underside lit by
    // the sunset, thinning to a point on the right.
    float aTop = 0.992 + 0.008 * vnoise5(vec2(q.x * 4.0, 7.0)) - 0.035 * smoothstep(0.7, 1.45, q.x);
    float aBot = 0.885 + 0.075 * smoothstep(0.35, 1.45, q.x) - 0.016 * billows(q.x, 9.0, 21.0);
    float anvil = cover(q.y - aBot) * cover(aTop - q.y);
    if (anvil > 0.0) {
        float v = (q.y - aBot) / max(aTop - aBot, 1e-3);
        float wisp = (vnoise5(vec2(q.x * 7.0, q.y * 40.0)) - 0.5) * 0.25;
        vec3 ac = mix(rgb(70, 46, 92), rgb(40, 28, 62), band(v + wisp, 0.35));
        ac = mix(ac, rgb(30, 22, 52), band(v + wisp, 0.75));
        ac = mix(ac, rgb(150, 76, 110), cover(0.007 - (q.y - aBot)));
        ac = mix(ac, rgb(214, 116, 120), cover(0.0025 - (q.y - aBot)) * smoothstep(0.3, 1.0, q.x));
        col = mix(col, ac, anvil);
        storm = anvil;
    }

    // The tower of billows, lit as one body in flat tones, not billow by billow: by
    // the sunset low on the right, light along its edge toward the sun and a rim of
    // it right at the edge, shade along the edge away, the middle and front billows
    // lit along their own edges and shading what lies behind them. Higher up it sits in the
    // deepening dusk, lower down it catches the sunset, and round where the bolt
    // leaves it glows from within.
    float dAll = stormDist(q, 0);
    if (dAll < PX * 2.0) {
        vec2 toSun = normalize(vec2(1.0, -0.22));
        float warm = smoothstep(0.9, 0.62, q.y);
        vec3 dark = mix(rgb(34, 26, 56), rgb(56, 36, 72), warm);
        vec3 midc = mix(rgb(64, 46, 90), rgb(104, 56, 94), warm);
        vec3 litc = mix(rgb(112, 70, 116), rgb(180, 84, 96), warm);
        vec3 rimc = mix(rgb(180, 102, 128), rgb(250, 152, 104), warm);
        // Glowing from within round the bolt: the billows nearest it light up whole,
        // their tones shifted toward lilac in two steps, the shading kept.
        vec2 on = vec2(-1.0);
        for (int i = 0; i < PUFFS; i++) {
            vec3 o = stormPuff(i);
            if (length(q - o.xy) < o.z)
                on = o.xy;
        }
        float glow = exp(-length((on - vec2(bx0, 0.62)) * vec2(1.0, 1.4)) * 6.0);
        float g1 = step(0.38, glow), g2 = step(0.62, glow);
        dark = mix(mix(dark, rgb(78, 62, 126), g1), rgb(106, 88, 162), g2);
        midc = mix(mix(midc, rgb(110, 92, 162), g1), rgb(146, 128, 200), g2);
        litc = mix(mix(litc, rgb(160, 140, 210), g1), rgb(212, 198, 244), g2);

        int from = stormDist(q, FRONT) < 0.0 ? FRONT : stormDist(q, MID) < 0.0 ? MID : 0;
        float lb = from == 0 ? 0.022 : 0.014;
        // Lit near its edge toward the sun, unless the way there crosses deep
        // through a billow, which would light slivers inside notches of the edge.
        float dl = min(stormDist(q + toSun * lb, from), stormDist(q + toSun * lb * 0.6, from) + lb * 0.4);
        float dsh = stormDist(q - toSun * 0.04, 0);
        vec3 sc = midc;
        sc = mix(sc, dark, 1.0 - fill(dsh));
        if (from < FRONT)
            sc = mix(sc, mix(sc, dark, 0.6), fill(stormDist(q + toSun * 0.008, from == 0 ? MID : FRONT)));
        sc = mix(sc, litc, 1.0 - fill(dl));
        float sunward = 1.0 - fill(stormDist(q + toSun * 0.006, 0));
        sc = mix(sc, rimc, (1.0 - fill(dAll + 0.003)) * sunward);
        float tower = fill(dAll);
        col = mix(col, sc, tower);
        storm = max(storm, tower);
    }
    // The underside, glowing with the sunset beneath.
    float belly = stormBelly(q.x);
    col = mix(col, rgb(214, 96, 92), fill(q.y - belly - 0.006) * fill(belly - q.y) * fill(dAll));

    // ── The bolt: from the cloud base down to the plain, branching ──
    float boltTop = base;
    vec2 bolt = boltDist(q, bx0, aspect * 0.24, boltTop, HORIZON - 0.012, 0.05, 1.0);
    float halo = 0.0;
    float core = 0.0;
    if (bolt.y > 0.0 && bolt.y < 1.0) {
        core = cover(0.0034 - bolt.x);
        halo = exp(-bolt.x / 0.012);
    }
    // Branches: shorter, thinner forks off the main channel.
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float yb = boltTop - (0.06 + 0.15 * hash(vec2(fi, 21.0))) * (boltTop - HORIZON);
        float len = (0.06 + 0.08 * hash(vec2(fi, 22.0)));
        float side = mod(fi, 2.0) < 1.0 ? -1.0 : 1.0;
        // Rooted on the main channel, less its own kink there.
        float xb = boltX(yb, bx0, aspect * 0.24, boltTop, HORIZON - 0.012, 0.05, 1.0)
                 - 0.02 * (zig(yb / 0.035, 7.0 + fi) + 0.45 * zig(yb / 0.011, 10.0 + fi));
        vec2 br = boltDist(q, xb, xb + side * len * 0.9, yb, yb - len, 0.02, 7.0 + fi);
        if (br.y > 0.0 && br.y < 1.0) {
            float w = 0.0016 * (1.0 - br.y);
            core = max(core, cover(w - br.x));
            halo = max(halo, 0.6 * (1.0 - br.y) * exp(-br.x / 0.008));
        }
    }
    col = mix(col, mix(col, rgb(255, 150, 60), 0.6), band(halo, 0.25) * 0.7);
    col = mix(col, rgb(255, 214, 70), band(halo, 0.55));
    col = mix(col, rgb(255, 252, 232), core);
    // Where it strikes, a flash on the plain.
    float strike = exp(-length((q - vec2(aspect * 0.24, HORIZON)) * vec2(1.0, 4.0)) * 24.0);

    // ── Mesas and buttes, far to near, losing their dusk haze as they come closer.
    //    The faces toward the sun are lit orange; strata band their walls. They part
    //    around the sun and the road. ──
    for (int layer = 0; layer < 3; layer++) {
        float fl = float(layer);
        float cell = 0.32 + 0.24 * fl;
        float tall = 0.05 + 0.055 * fl;
        float seed = 31.0 + fl * 9.0;
        float lx = q.x + fl * 5.3;
        vec3 shade = layer == 0 ? rgb(112, 56, 96) : layer == 1 ? rgb(118, 46, 58) : rgb(84, 28, 36);
        vec3 mid = layer == 0 ? rgb(146, 70, 98) : layer == 1 ? rgb(164, 66, 58) : rgb(150, 50, 42);
        vec3 lit = layer == 0 ? rgb(196, 98, 96) : layer == 1 ? rgb(222, 108, 66) : rgb(232, 112, 56);
        vec3 rim = layer == 0 ? rgb(232, 136, 106) : rgb(255, 176, 96);
        float baseY = HORIZON - 0.004 * fl;
        float yb = q.y - baseY;
        float g = floor(lx / cell);
        for (int k = -2; k <= 2; k++) {
            float c = g + float(k);
            Mesa m = mesaAt(c, cell, tall, seed);
            float sx = m.cx - fl * 5.3;
            // Lower near the sun and the road's vanishing point.
            m.ht *= mix(0.25, 1.0, smoothstep(0.05, 0.22, abs(sx - sun.x)));
            m.ht *= mix(0.0, 1.0, smoothstep(0.06, 0.2, abs(sx - vpx)));
            vec2 mt = mesaTop(m, lx);
            float f = mt.x - yb;
            if (f < -0.004)
                continue;
            float side = sign(sun.x - sx);
            float l = mt.y * side + (vnoise(vec2(lx * 120.0, q.y * 20.0)) - 0.5) * 0.35;
            vec3 tc = mix(shade, mid, band(l, -0.35));
            tc = mix(tc, lit, band(l, 0.45));
            // Strata: horizontal bands across the walls, broken here and there.
            float strata = fract(yb / (0.012 + 0.004 * fl) + 0.3 * vnoise(vec2(lx * 30.0, c)));
            tc = mix(tc, tc * 0.82, band(strata, 0.7) * step(0.0, f - 0.006) * (layer > 0 ? 0.8 : 0.4));
            // The sunlit rim along the top of the facing wall.
            tc = mix(tc, rim, cover(0.003 - f) * step(0.3, mt.y * side));
            col = mix(col, tc, cover(f));
        }
        // Dusk haze settles between the ranges.
        col = mix(col, rgb(226, 120, 96), below(baseY + 0.01 + 0.012 * billows(q.x + fl * 2.0, 5.0, 60.0 + fl), q.y) * (0.35 - 0.1 * fl));
    }

    // ── The desert plain, banded by distance, with scrub and the strike's flash ──
    if (q.y < HORIZON) {
        float z = 1.0 / max(HORIZON - q.y, 1e-4);         // depth
        float dist = clamp((HORIZON - q.y) / HORIZON, 0.0, 1.0);
        vec3 ground = mix(rgb(214, 118, 82), rgb(146, 66, 48), steps(pow(dist, 0.6), 6.0));
        // Long dunes of shadow, flattened by distance.
        float dune = vnoise(vec2(q.x * z * 0.12, z * 0.25));
        ground = mix(ground, ground * 0.92, band(dune, 0.6));
        // Scrub: dark tufts, smaller with distance.
        vec2 sc = vec2(q.x * z * 0.9, z * 1.2);
        vec2 cell = floor(sc);
        vec2 h = hash2(cell + 9.0);
        vec2 c = cell + 0.25 + 0.5 * h;
        float tuft = cover(0.1 - length((sc - c) * vec2(1.0, 1.4))) * step(0.6, hash(cell + 2.0));
        ground = mix(ground, rgb(110, 56, 48), tuft * 0.6);
        ground = mix(ground, rgb(255, 214, 140), strike * 0.8);
        col = mix(col, ground, cover(HORIZON - q.y));

        // ── The road: straight to the horizon, edge lines and a dashed center line ──
        float halfW = 0.52 * (HORIZON - q.y) + 0.0006;
        float rx = (q.x - vpx) / halfW;                    // -1..1 across the road
        float road = cover((1.0 - abs(rx)) * halfW);
        vec3 asphalt = mix(rgb(70, 52, 70), rgb(44, 36, 50), steps(dist, 4.0));
        // A sheen of sky on the far stretch.
        asphalt = mix(asphalt, rgb(170, 88, 92), smoothstep(0.35, 0.0, dist) * 0.5);
        asphalt = mix(asphalt, asphalt * 0.82, band(vnoise(vec2(rx * 6.0, z * 0.6)), 0.66) * 0.7);
        float lineW = 0.022;
        float edge = band(abs(rx), 0.9) * (1.0 - band(abs(rx), 0.9 + lineW * 1.6));
        asphalt = mix(asphalt, rgb(232, 214, 200), edge * 0.85);
        float dash = step(0.45, fract(z * 0.55));
        float center = (1.0 - band(abs(rx), lineW)) * dash;
        asphalt = mix(asphalt, rgb(255, 200, 44), center);
        // Tail lights streaking away in the right lane, one red, its twin, and a
        // yellow trail between them.
        for (int i = 0; i < 3; i++) {
            float lane = i == 0 ? 0.38 : i == 1 ? 0.62 : 0.5;
            float w = i == 2 ? 0.014 : 0.02;
            float trail = (1.0 - band(abs(rx - lane), w)) * smoothstep(0.02, 0.5, dist) * smoothstep(1.0, 0.75, dist);
            asphalt = mix(asphalt, i == 2 ? rgb(255, 196, 60) : rgb(255, 64, 54), trail * (i == 2 ? 0.55 : 0.85));
            asphalt = mix(asphalt, mix(asphalt, rgb(255, 120, 80), 0.4), (1.0 - band(abs(rx - lane), w * 3.0)) * smoothstep(0.02, 0.5, dist) * smoothstep(1.0, 0.75, dist) * 0.35);
        }
        // Gravel shoulders.
        float shoulder = cover((1.18 - abs(rx)) * halfW) * (1.0 - road);
        col = mix(col, mix(rgb(160, 92, 70), rgb(118, 64, 52), steps(dist, 3.0)), shoulder);
        col = mix(col, asphalt, road);
    }

    // ── Telephone poles marching along the left side, two wires sagging between
    //    the ends of their crossarms ──
    for (int i = 0; i < 10; i++) {
        float zi = 1.8 + float(i) * 1.5;                   // depth of pole i
        float dy = 1.0 / zi;                               // its foot below the horizon
        float x = vpx - 0.52 * dy * 2.1;
        float h = 0.75 * dy;
        float w = max(0.0008, 0.008 * dy);
        float top = HORIZON - dy + h;
        float pole = cover(w - abs(q.x - x)) * cover(q.y - (HORIZON - dy)) * cover(top - q.y);
        float arm = cover(w * 0.7 - abs(q.y - (top - 0.06 * h))) * cover(h * 0.16 - abs(q.x - x));
        col = mix(col, rgb(42, 22, 36), max(pole, arm));
        // The wires to the next pole out, sagging toward the middle.
        float zn = zi + 1.5, dn = 1.0 / zn;
        float xn = vpx - 0.52 * dn * 2.1;
        float tn = HORIZON - dn + 0.75 * dn;
        for (int k = 0; k < 2; k++) {
            float e = k == 0 ? -1.0 : 1.0;
            float xa = x + e * h * 0.14, xb = xn + e * 0.75 * dn * 0.14;
            float s = (q.x - xa) / (xb - xa);
            if (s > 0.0 && s < 1.0) {
                float wy = mix(top - 0.06 * h, tn - 0.06 * 0.75 * dn, s) - 0.05 * (dy - dn) * 4.0 * s * (1.0 - s);
                col = mix(col, rgb(42, 22, 36), cover(max(0.0005, 0.0011 * dy) - abs(q.y - wy)));
            }
        }
    }

    // ── A roadside stop on the right: a low diner with a lit band of windows, and
    //    a neon arrow on a tall post pointing at it, a bolt on its board ──
    {
        float dy = 0.075;
        vec2 b = vec2(vpx + 0.52 * dy * 1.6, HORIZON - dy);
        float bw = 0.11, bh = 0.03;
        vec2 d = q - b;
        float diner = cover(d.x) * cover(bw - d.x) * cover(d.y) * cover(bh - d.y);
        // A rounded, chrome-trimmed roof line.
        float roof = cover(0.004 - abs(d.y - bh)) * cover(d.x + 0.004) * cover(bw + 0.004 - d.x);
        col = mix(col, rgb(76, 34, 52), diner);
        float win = step(0.3, fract(d.x / 0.014)) * cover(d.y - 0.009) * cover(0.021 - d.y) * diner;
        col = mix(col, rgb(255, 210, 128), win);
        col = mix(col, rgb(255, 120, 96), roof);
        // A glow of the windows on the ground in front.
        col = mix(col, rgb(236, 140, 92), cover(-d.y) * smoothstep(-0.012, 0.0, d.y) * cover(d.x) * cover(bw - d.x) * 0.35);
        // The post, and the arrow board on it with a chevron head pointing left.
        vec2 sp = vec2(b.x + bw + 0.035, b.y);
        float post = cover(0.0022 - abs(q.x - sp.x)) * cover(q.y - sp.y) * cover(sp.y + 0.14 - q.y);
        col = mix(col, rgb(48, 26, 40), post);
        vec2 a = q - vec2(sp.x - 0.05, sp.y + 0.12);
        float board = max(abs(a.y) - 0.02, max(-a.x, a.x - 0.09));
        float head = max(abs(a.y) - (a.x + 0.04), a.x);
        float arrowD = min(board, head);
        col = mix(col, rgb(255, 96, 80), 0.4 * exp(-max(arrowD, 0.0) / 0.008) * cover(arrowD));
        col = mix(col, rgb(116, 22, 36), cover(-arrowD));
        col = mix(col, rgb(255, 96, 80), cover(0.0018 - abs(arrowD + 0.0035)));
        // Bulbs chasing along the board.
        float bulbs = cover(0.0022 - length(vec2(fract(a.x / 0.011) * 0.011 - 0.0055, abs(a.y) - 0.0145))) * step(0.004, a.x) * step(a.x, 0.086);
        col = mix(col, rgb(255, 232, 150), bulbs);
        // The bolt, in neon yellow.
        vec2 bp = a - vec2(0.046, 0.0);
        // A Z of two slanted strokes, the lower one stepped right at the kink.
        float upper = max(abs(bp.x - 0.002 - (bp.y - 0.006) * 0.6) - 0.0032, abs(bp.y - 0.005) - 0.007);
        float lower = max(abs(bp.x + 0.002 - (bp.y + 0.006) * 0.6) - 0.0032, abs(bp.y + 0.005) - 0.007);
        float boltSign = cover(-min(upper, lower));
        col = mix(col, rgb(255, 222, 80), boltSign);
    }

    // ── Saguaros: a few out in the scrub, two big ones near ──
    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float dy = i == 0 ? 0.3 : i == 1 ? 0.28 : 0.02 + 0.05 * hash(vec2(fi, 3.0));
        // The small ones stand off to the left, clear of the roadside stop.
        float side = i == 1 ? 1.0 : -1.0;
        float off = i == 0 ? 5.0 : i == 1 ? 3.2 : 4.5 + 6.0 * hash(vec2(fi, 5.0));
        vec2 b = vec2(vpx + side * 0.52 * dy * off, HORIZON - dy);
        float h = 1.0 * dy * (i < 2 ? 1.1 : 0.9);
        float d = saguaro(q, b, h, fi + 1.0);
        vec3 cc = i < 2 ? rgb(46, 24, 34) : rgb(84, 40, 52);
        col = mix(col, cc, cover(-d));
        // A sunlit edge on the side toward the sun, and ribs down the trunk.
        float lit = saguaro(q + vec2(0.012 * h, 0.0), b, h, fi + 1.0);
        col = mix(col, i < 2 ? rgb(170, 70, 56) : rgb(196, 92, 70), cover(-d) * cover(lit) * 0.9);
    }

    // ── Dust in the warm air, lit by the sun low over the plain ──
    for (int i = 0; i < 46; i++) {
        vec2 h = hash2(vec2(float(i), 4.7));
        vec2 f = vec2(h.x * aspect, HORIZON - 0.1 + 0.32 * h.y);
        float near = hash(vec2(float(i), 2.0));
        col = mix(col, rgb(255, 214, 150), cover(mix(0.0012, 0.0032, near) - length(q - f)) * 0.75);
    }
    fragColor = vec4(col, 1.0);
}
