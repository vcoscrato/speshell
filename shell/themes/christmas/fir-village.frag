#version 440
#extension GL_GOOGLE_include_directive : enable
// Fir village on Christmas Eve: a snowed-in village of steep-roofed cottages lies in
// a valley under a full moon, its windows lit and smoke curling from its chimneys.
// In the square stands a giant fir, its boughs heavy with snow, strung with swags of
// fairy lights and hung with baubles, a gold star glowing in rings on its top. Snowy
// ridges rise behind under the moonlight, a path lit by lanterns leads in between
// drifts, smaller firs stand at the edges, and snow falls near and far.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
} u;
#include "../../effects/common/common.glsl"
#include "../landscape.glsl"

float PX;       // one pixel, in q
vec2 MOON;

// Coverage of a signed distance in q, without derivatives, so it is safe anywhere.
float fill(float d) {
    return smoothstep(PX, -PX, d);
}

// Five-stop night ramp, horizon to zenith.
vec3 sky(float t) {
    vec3 a = rgb(112, 146, 150), b = rgb(54, 90, 98), c = rgb(28, 56, 62), d = rgb(16, 34, 38), e = rgb(9, 19, 19);
    if (t < 0.16) return mix(a, b, t / 0.16);
    if (t < 0.4) return mix(b, c, (t - 0.16) / 0.24);
    if (t < 0.7) return mix(c, d, (t - 0.4) / 0.3);
    return mix(d, e, (t - 0.7) / 0.3);
}

// A five-pointed star of radius r, its inner corners rf of the way in.
float sdStar5(vec2 p, float r, float rf) {
    const vec2 k1 = vec2(0.809016994, -0.587785252);
    const vec2 k2 = vec2(-k1.x, k1.y);
    p.x = abs(p.x);
    p -= 2.0 * max(dot(k1, p), 0.0) * k1;
    p -= 2.0 * max(dot(k2, p), 0.0) * k2;
    p.x = abs(p.x);
    p.y -= r;
    vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
    float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
    return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

// ── Mountains ──

// A range of snowy mountains on the line `base`, about `cell` apart, each in one of
// three depths so the nearer stand in front of the farther: lopsided, with a lower
// summit on one shoulder and a frayed crest. Faces toward the moon are lit and the
// rest in shade with ribs of rock; a rim of moonlight runs along the lit slopes.
vec3 range(vec3 col, vec2 q, float base, float cell, float tall, float seed, vec3 lit, vec3 shade, vec3 rock, vec3 rim) {
    if (q.y > base + tall * 1.3)
        return col;
    float g = floor(q.x / cell);
    for (int z = 0; z < 3; z++) {
        for (int k = -2; k <= 2; k++) {
            float c = g + float(k);
            if (floor(hash(vec2(c, seed + 5.0)) * 3.0) != float(z))
                continue;
            float h0 = hash(vec2(c, seed)), h1 = hash(vec2(c, seed + 1.0));
            float h2 = hash(vec2(c, seed + 2.0)), h3 = hash(vec2(c, seed + 3.0));
            float cx = (c + 0.2 + 0.6 * h0) * cell;
            float ht = tall * mix(0.45, 1.0, h1) * mix(0.8, 1.0, float(z) / 2.0);
            float wl = cell * mix(0.8, 1.5, h2), wr = cell * mix(0.8, 1.5, h3);
            float d = q.x - cx;
            float hp = pow(max(0.0, 1.0 - (d < 0.0 ? -d / wl : d / wr)), 1.25);
            // The shoulder summit, on the gentler side.
            float so = h2 > h3 ? -0.45 * wl : 0.45 * wr;
            float hs = mix(0.5, 0.72, h0) * pow(max(0.0, 1.0 - abs(d - so) / (0.4 * cell)), 1.5);
            float prof = max(hp, hs);
            float h = base - 0.02 + ht * prof + (zig(q.x / 0.008, seed + c) * 0.005 + zig(q.x / 0.0028, seed + c + 1.0) * 0.0018) * smoothstep(0.0, 0.3, prof);
            if (q.y > h + PX * 2.0)
                continue;
            // The spine runs down from each summit, leaning and wandering.
            float sx = hp >= hs ? cx : cx + so;
            float sy = base - 0.02 + ht * (hp >= hs ? 1.0 : mix(0.5, 0.72, h0));
            float spine = sx + (sy - q.y) * (0.35 + 0.3 * h3) + (vnoise(vec2(q.y * 50.0, seed + c)) - 0.5) * 0.025;
            bool onLit = q.x < spine;
            vec3 m = onLit ? lit : shade;
            float rib = vnoise(vec2((q.x - spine) * 60.0 + q.y * 25.0, q.y * 6.0 + c));
            m = mix(m, rock, onLit ? 0.0 : band(rib, 0.7) * smoothstep(0.0, 0.03, h - q.y));
            m = mix(m, rim, onLit ? fill(h - q.y - 0.0026) : 0.0);
            col = mix(col, m, fill(q.y - h));
        }
    }
    return col;
}

// ── Firs ──

// The geometry of tier i of a fir (0 the top) at height x: the hem at the axis, the
// apex, and the reach left and right.
vec4 firTier(float i, float n, vec2 b, float h, float w, float seed) {
    float trunk = h * 0.07;
    float span = h - trunk;
    float f = (i + 1.0) / n;
    float hem = b.y + trunk + span * (1.0 - f) + span / n * 0.3 * (hash(vec2(i, seed)) - 0.5);
    float apex = i < 0.5 ? b.y + h : hem + span / n * mix(1.8, 2.2, hash(vec2(i, seed + 1.0)));
    float reach = w * mix(0.24, 1.0, pow(f, 1.1)) * mix(0.86, 1.12, hash(vec2(i, seed + 2.0)));
    float lop = 0.3 * (hash(vec2(i, seed + 3.0)) - 0.5);
    return vec4(hem, apex, reach * (1.0 + lop), reach * (1.0 - lop));
}

// The x of a fir's trunk at height y: leaning a little and wandering.
float firAxis(float y, vec2 b, float h, float w, float seed) {
    float t = (y - b.y) / h;
    return b.x + w * (0.05 * (hash(vec2(seed, 9.0)) - 0.5) * t * 2.0 + 0.025 * sin(t * 5.0 + seed));
}

// Tier i's outline at x: its hem there (the bough tips hang in teeth of uneven
// length, drooping toward the ends), the top of its slant, and x across it (-1 at
// the left tip, 1 at the right).
vec3 tierShape(vec4 t, float i, float x, float axis, float w, float seed) {
    float dx = x - axis;
    float reach = dx < 0.0 ? t.z : t.w;
    float s = dx / reach;
    float as = abs(s);
    float th = t.y - t.x;
    float sp = th / 2.0;
    float uu = dx / w * mix(9.0, 12.0, hash(vec2(i, seed + 4.0))) + i * 3.7 + 0.5 * vnoise(vec2(dx / w * 4.0, i + seed));
    float f = fract(uu);
    float tooth = pow(1.0 - abs(2.0 * f - 1.0), 1.6) * mix(0.35, 1.0, hash(vec2(floor(uu), seed + i * 7.0)));
    float hem = t.x - sp * (0.55 * as * as + 0.32 * tooth * smoothstep(0.0, 0.25, as));
    float tip = t.x - sp * 0.75;
    float top = t.y + (tip - t.y) * pow(min(as, 1.0), 0.75);
    return vec3(hem, top, s);
}

struct Fir {
    vec3 col;       // premultiplied
    float a;
    float tier;     // the tier in front at q, or -1
    float s;
};

// A fir on its foot b, h tall and w half wide at the foot, of n tiers: drooping
// boughs, each tier lopsided and the higher in front, lit on the moon's side, in
// shadow under the tier above, with snow along their tops.
Fir fir(vec2 q, vec2 b, float h, float w, float n, float seed, vec3 gLit, vec3 gMid, vec3 gShade, vec3 sLit, vec3 sShade, vec3 bark) {
    Fir r;
    r.col = vec3(0.0);
    r.a = 0.0;
    r.tier = -1.0;
    r.s = 0.0;
    if (abs(q.x - b.x) > w * 1.25 || q.y < b.y - 0.01 || q.y > b.y + h + 0.01)
        return r;
    float axis = firAxis(q.y, b, h, w, seed);
    float hemUp = 1e3;
    float sUp = 9.0;
    for (int k = 0; k < 12; k++) {
        float i = float(k);
        if (i >= n)
            break;
        vec4 t = firTier(i, n, b, h, w, seed);
        vec3 sh = tierShape(t, i, q.x, axis, w, seed);
        float reach = sh.z < 0.0 ? t.z : t.w;
        // Needles fraying the slant.
        float fray = (t.y - t.x) * 0.035 * zig((q.x - axis) / (w * 0.03), seed + i) * smoothstep(0.05, 0.3, abs(sh.z));
        float inside = fill(sh.x - q.y) * fill(q.y - sh.y - fray) * fill((abs(sh.z) - 1.0) * reach);
        if (inside > 0.0) {
            float th = t.y - t.x;
            float e = PX / reach;
            // Lit toward the moon, shaded away, the bands frayed like needles.
            float lu = -sh.z + 0.12 * (vnoise(vec2(q.y / (th * 0.12), i + seed)) - 0.5);
            vec3 g = mix(gShade, gMid, smoothstep(-0.3 - e, -0.3 + e, lu));
            g = mix(g, gLit, smoothstep(0.42 - e, 0.42 + e, lu));
            // Snow lying in clumps along the top of the boughs, deepest toward the tips but
            // never deeper than two fifths of the bough, so green shows under it to the tip.
            float clump = smoothstep(0.22, 0.5, vnoise(vec2((q.x - axis) / (w * 0.07), i * 5.3 + seed)));
            float snowT = min(th * (0.08 + 0.12 * lobes(q.x / (w * 0.13), 1.0, seed + i)), (sh.y - sh.x) * 0.4)
                * smoothstep(0.2, 0.5, abs(sh.z)) * clump;
            float snow = fill(sh.y - snowT - q.y);
            vec3 sc = mix(sShade, sLit, smoothstep(-0.15 - e, -0.15 + e, lu));
            g = mix(g, sc, snow);
            // The shadow of the tier above, following its teeth.
            float shadow = step(sUp, 1.0) * fill(hemUp - th * 0.13 - q.y);
            g = mix(g, gShade, shadow * (1.0 - snow));
            g = mix(g, sShade * 0.8, shadow * snow);
            r.col += (1.0 - r.a) * inside * g;
            if (r.tier < 0.0 && inside > 0.5) {
                r.tier = i;
                r.s = sh.z;
            }
            r.a += (1.0 - r.a) * inside;
            if (r.a > 0.999)
                return r;
        }
        hemUp = sh.x;
        sUp = abs(sh.z);
    }
    // The trunk under the lowest boughs.
    float dx = q.x - axis;
    float trunk = fill(abs(dx) - w * 0.065) * fill(b.y - q.y) * fill(q.y - b.y - h * 0.2);
    vec3 tc = mix(bark, bark * 0.6, step(0.0, dx));
    r.col += (1.0 - r.a) * trunk * tc;
    r.a += (1.0 - r.a) * trunk;
    return r;
}

vec3 drawFir(vec3 col, Fir f) {
    return col * (1.0 - f.a) + f.col;
}

// ── Cottages ──

// The top of the chimney of a cottage (see cottage()).
vec2 chimneyTop(vec2 b, vec4 dims, float side, float cf) {
    return vec2(b.x + side * (dims.x * 0.5 + cf * dims.y), b.y + dims.z + dims.w * 1.32);
}

// A window centered on c, half size hs, lit or dark: a frame, a cross of glazing
// bars, a sill of snow, and warm light round it on the wall.
vec3 window(vec3 col, vec2 p, vec2 c, vec2 hs, bool lit, vec3 wallC, vec3 frame, vec3 snow) {
    vec2 d = abs(p - c);
    float glowD = max(d.x - hs.x * 1.9, d.y - hs.y * 1.6);
    if (lit)
        col = mix(col, mix(col, rgb(243, 199, 102), 0.22), fill(glowD));
    float fr = fill(max(d.x - hs.x * 1.22, d.y - hs.y * 1.15));
    col = mix(col, frame, fr);
    float glass = fill(max(d.x - hs.x, d.y - hs.y));
    vec3 gc = lit ? rgb(250, 210, 128) : rgb(38, 58, 70);
    col = mix(col, gc, glass);
    float bars = fill(min(d.x, d.y) - hs.x * 0.09) * glass;
    col = mix(col, frame, bars);
    float sill = fill(max(d.x - hs.x * 1.4, abs(p.y - (c.y - hs.y * 1.25)) - hs.y * 0.14));
    return mix(col, snow, sill);
}

// A cottage on its front corner b, seen from a little to the side: its gable end gw
// wide beside its long side lw wide (dims), walls wh high under a gable rh high, the
// gable to the left (side 1, facing the moon) or right (-1). Its walls are `wall`,
// its roof heaped with snow, its windows lit or dark, and a chimney stands cf along
// the ridge.
vec3 cottage(vec3 col, vec2 q, vec2 b, vec4 dims, float side, float cf, vec3 wall, float seed, vec3 hz, float haze) {
    float gw = dims.x, lw = dims.y, wh = dims.z, rh = dims.w;
    vec2 p = vec2((q.x - b.x) * side, q.y - b.y);
    float ov = gw * 0.12;
    if (p.x < -ov * 2.0 || p.x > gw + lw + ov * 2.0 || p.y < -0.004 || p.y > wh + rh * 1.6)
        return col;
    vec3 m = col;
    float cov = 0.0;
    vec3 gableC = side > 0.0 ? wall * 1.18 : wall * 0.68;
    vec3 longC = side > 0.0 ? wall * 0.8 : wall * 0.95;
    vec3 frame = wall * 0.45;
    vec3 snowLit = rgb(222, 232, 232), snowMid = rgb(184, 202, 210), snowShade = rgb(128, 152, 166);
    float k = rh / (gw * 0.5);
    // The long wall, and the gable end with its triangle.
    float inLong = fill(max(max(gw - p.x, p.x - gw - lw), max(-p.y, p.y - wh)));
    m = mix(m, longC, inLong);
    float gy = wh + rh - k * abs(p.x - gw * 0.5);
    float inGable = fill(max(max(-p.x, p.x - gw), max(-p.y, p.y - gy)));
    m = mix(m, gableC, inGable);
    cov = max(cov, max(inLong, inGable));
    // Windows on the long side, and a door; one on the gable, and one in its peak.
    float nw = max(1.0, floor(lw / (wh * 0.62)));
    float two = step(1.15, wh / gw);
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        if (fi >= nw)
            break;
        float x = gw + lw * (fi + 0.5) / nw;
        bool door = fi == floor(hash(vec2(seed, 3.0)) * nw) && hash(vec2(seed, 4.0)) < 0.6 && lw > wh * 0.9;
        if (door) {
            vec2 dd = abs(p - vec2(x, wh * 0.27));
            m = mix(m, frame, fill(max(dd.x - wh * 0.13, dd.y - wh * 0.27)));
            m = mix(m, wall * 0.3, fill(max(dd.x - wh * 0.1, dd.y - wh * 0.25)));
            // A wreath on it, tied with a red bow.
            float wr = length(p - vec2(x, wh * 0.36));
            m = mix(m, rgb(46, 92, 62), fill(abs(wr - wh * 0.055) - wh * 0.025));
            m = mix(m, rgb(200, 54, 60), fill(length(p - vec2(x, wh * 0.29)) - wh * 0.022));
        } else {
            for (int r = 0; r < 2; r++) {
                if (r == 1 && two < 0.5)
                    break;
                float y = two > 0.5 ? (r == 0 ? wh * 0.3 : wh * 0.72) : wh * 0.48;
                bool lit = hash(vec2(seed + fi, float(r) + 7.0)) < 0.72;
                m = mix(m, window(m, p, vec2(x, y), vec2(wh * 0.1, wh * (two > 0.5 ? 0.11 : 0.15)), lit, longC, frame, snowMid), inLong);
            }
        }
    }
    bool gLit = hash(vec2(seed, 5.0)) < 0.8;
    m = mix(m, window(m, p, vec2(gw * 0.5, two > 0.5 ? wh * 0.5 : wh * 0.45), vec2(gw * 0.11, wh * 0.14), gLit, gableC, frame, snowMid), inGable);
    if (rh > gw * 0.55)
        m = mix(m, window(m, p, vec2(gw * 0.5, wh + rh * 0.36), vec2(gw * 0.06, gw * 0.07), hash(vec2(seed, 6.0)) < 0.6, gableC, frame, snowMid), inGable);
    // The roof over the long side: a slab of snow from the eaves to the ridge.
    float y0 = wh - ov * 0.7, y1 = wh + rh;
    float xl = gw - (p.y - wh) / rh * gw * 0.5;
    float inSlab = fill(max(max(xl - p.x, p.x - xl - lw - ov), max(y0 - p.y, p.y - y1)));
    // Its eave: a dark board under the snow, lumps of snow hanging over it.
    float board = y0 + ov * 0.4;
    float lump = ov * 0.45 * lobes(p.x / (gw * 0.11), 1.0, seed + 2.0);
    vec3 slab = mix(snowMid, frame, fill(p.y - board) * fill(board - lump - p.y));
    m = mix(m, slab, inSlab);
    cov = max(cov, inSlab);
    // Snow heaped along the ridge.
    float ridgeX0 = gw * 0.5, ridgeX1 = gw * 0.5 + lw + ov;
    float rs = ov * (0.6 + 0.5 * lobes(p.x / (gw * 0.16), 1.0, seed + 8.0));
    float inRidge = fill(max(max(ridgeX0 - p.x, p.x - ridgeX1 - rs * 0.5), max(y1 - ov * 0.2 - p.y, p.y - y1 - rs)));
    m = mix(m, snowLit, inRidge);
    cov = max(cov, inRidge);
    // The chimney, bricks under a cap of snow.
    float cx = gw * 0.5 + cf * lw, cw = gw * 0.09;
    float ctop = wh + rh * 1.32;
    float inCh = fill(max(abs(p.x - cx) - cw, max(wh + rh * 0.5 - p.y, p.y - ctop)));
    vec3 brick = mix(rgb(96, 46, 44), rgb(132, 64, 54), step(p.x * side, cx * side));
    m = mix(m, brick, inCh);
    float cap = fill(max(abs(p.x - cx) - cw * 1.35, abs(p.y - ctop - cw * 0.25) - cw * 0.45));
    m = mix(m, snowLit, cap);
    cov = max(cov, max(inCh, cap));
    // The gable's roof edges: boards under a thick rim of snow.
    vec2 apex = vec2(gw * 0.5, wh + rh);
    for (int s = 0; s < 2; s++) {
        float sx = s == 0 ? -1.0 : 1.0;
        vec2 dir = normalize(vec2(sx, -k));
        vec2 nrm = vec2(-dir.y, dir.x) * -sx;
        if (nrm.y < 0.0)
            nrm = -nrm;
        float len = (gw * 0.5 + ov) * length(vec2(1.0, k));
        float along = dot(p - apex, dir);
        float off = dot(p - apex, nrm);
        float inSeg = fill(-along + ov * 0.2) * fill(along - len);
        float thick = ov * (0.55 + 0.45 * lobes(along / (gw * 0.12), 1.0, seed + sx * 3.0));
        float board = fill(abs(off + ov * 0.15) - ov * 0.18) * inSeg;
        float sn = fill(max(-off, off - thick)) * inSeg;
        vec3 sc = (sx < 0.0) == (side > 0.0) ? snowLit : mix(snowMid, snowShade, 0.4);
        m = mix(m, frame, board);
        m = mix(m, sc, sn);
        cov = max(cov, max(board, sn));
    }
    return mix(col, mix(m, hz, haze), cov);
}

// Smoke rising h from a chimney top c: a ribbon that widens, sways, and drifts with
// the breeze as it climbs, lit on the moon's side, breaking into wisps that thin
// away.
vec3 smoke(vec3 col, vec2 q, vec2 c, float h, float w0, float seed, vec3 lit, vec3 shade) {
    float t = (q.y - c.y) / h;
    if (t < 0.0 || t > 1.0)
        return col;
    float xc = c.x + h * (0.22 * t * t + 0.045 * t * sin(t * 6.5 + seed) + 0.015 * sin(t * 15.0 + seed * 2.0) * t);
    float w = w0 * (1.0 + 3.2 * t) * (0.8 + 0.4 * vnoise(vec2(t * 7.0, seed)));
    float dx = q.x - xc;
    float body = fill(abs(dx) - w);
    // Wisps breaking off as it thins.
    float holes = vnoise(vec2(dx / w * 1.3 + seed, q.y / (w0 * 2.5)));
    body *= fill(t * 0.95 - 0.12 - holes);
    float a = mix(0.85, 0.0, smoothstep(0.15, 1.0, t));
    vec3 sc = dx < -w * 0.2 ? lit : shade;
    return mix(col, sc, body * a);
}

// ── The great fir's finery ──

// Its swags of fairy lights, on the tier in front at q (f): a string looping from
// bough to bough across the tier, warm bulbs along it, each ringed with its light.
vec3 lights(vec3 col, vec2 q, Fir f, vec2 b, float h, float w, float n, float seed) {
    if (f.tier < 0.5 || f.tier > n - 1.5)
        return col;
    float i = f.tier;
    vec4 t = firTier(i, n, b, h, w, seed);
    float axis = firAxis(q.y, b, h, w, seed);
    float sp = (t.y - t.x) / 2.0;
    float swags = 3.0 + step(0.5, hash(vec2(i, seed + 20.0)));
    float tilt = (hash(vec2(i, seed + 21.0)) - 0.5) * 0.5;
    float reachL = t.z, reachR = t.w;
    // y of the string at s across the tier.
    #define STRING(s) (t.x - sp * 0.55 * (s) * (s) + sp * (0.62 + tilt * (s)) - sp * 0.34 * 4.0 * fract(((s) + 0.92) / 1.84 * swags) * (1.0 - fract(((s) + 0.92) / 1.84 * swags)))
    float dx = q.x - axis;
    float s = dx / (dx < 0.0 ? reachL : reachR);
    if (abs(s) < 0.92)
        col = mix(col, rgb(18, 30, 26), fill(abs(q.y - STRING(s)) - PX * 0.7) * 0.8);
    float ds = 1.84 / (swags * mix(3.0, 3.6, hash(vec2(i, seed + 22.0))));
    float j0 = floor((s + 0.92) / ds);
    float rb = w * 0.014;
    for (int k = -1; k <= 1; k++) {
        float j = j0 + float(k);
        float sj = -0.92 + (j + 0.5 + 0.3 * (hash(vec2(j, i + seed)) - 0.5)) * ds;
        if (abs(sj) > 0.92)
            continue;
        vec2 c = vec2(axis + sj * (sj < 0.0 ? reachL : reachR), STRING(sj));
        float d = length(q - c);
        float hb = hash(vec2(j, i + seed + 30.0));
        vec3 bc = hb < 0.55 ? rgb(252, 212, 116) : hb < 0.85 ? rgb(250, 236, 204) : rgb(240, 154, 104);
        col = mix(col, mix(col, bc, 0.22), fill(d - rb * 2.1));
        col = mix(col, bc, fill(d - rb));
    }
    #undef STRING
    return col;
}

// Its baubles, cranberry and gold, each hanging under a bough tip: lit toward the
// moon, a crescent of shade away from it, a glint, and a little cap.
vec3 baubles(vec3 col, vec2 q, vec2 b, float h, float w, float n, float seed) {
    for (int k = 2; k < 12; k++) {
        float i = float(k);
        if (i >= n)
            break;
        vec4 t = firTier(i, n, b, h, w, seed);
        float sp = (t.y - t.x) / 2.0;
        for (int m = 0; m < 2; m++) {
            float hm = hash(vec2(i * 3.0 + float(m), seed + 40.0));
            float s = (m == 0 ? -1.0 : 1.0) * mix(0.3, 0.8, hm) * (mod(i, 2.0) < 1.0 ? 1.0 : -1.0);
            if (m == 1 && hm < 0.35)
                continue;
            float r = w * mix(0.05, 0.068, hash(vec2(i, float(m) + seed + 41.0)));
            float x = firAxis(t.x, b, h, w, seed) + s * (s < 0.0 ? t.z : t.w);
            vec2 c = vec2(x, t.x - sp * 0.55 * s * s - sp * 0.2 - r);
            vec2 p = q - c;
            if (dot(p, p) > r * r * 9.0)
                continue;
            bool gold = hash(vec2(i, float(m) + seed + 42.0)) < 0.4;
            vec3 lit = gold ? rgb(246, 206, 120) : rgb(214, 66, 74);
            vec3 mid = gold ? rgb(206, 152, 70) : rgb(168, 40, 54);
            vec3 dark = gold ? rgb(132, 92, 44) : rgb(100, 22, 38);
            float d = length(p);
            vec3 bc = mix(dark, mid, fill(length(p + vec2(r * 0.28, -r * 0.22)) - r * 0.92));
            bc = mix(bc, lit, fill(length(p + vec2(r * 0.42, -r * 0.4)) - r * 0.5));
            bc = mix(bc, rgb(242, 238, 228), fill(length((p + vec2(r * 0.42, -r * 0.42)) * vec2(1.0, 1.4)) - r * 0.16));
            col = mix(col, rgb(18, 30, 26), fill(abs(p.x) - PX * 0.6) * step(r, p.y) * step(p.y, r * 1.5));
            col = mix(col, bc, fill(d - r));
            col = mix(col, rgb(206, 160, 84), fill(max(abs(p.x) - r * 0.28, abs(p.y - r * 1.02) - r * 0.16)));
        }
    }
    return col;
}

// The gold star on its top c, r its radius: faceted, each point lit on the side
// toward the moon, glowing in rings.
vec3 topStar(vec3 col, vec2 q, vec2 c, float r) {
    vec2 p = q - c;
    float d = length(p);
    col = mix(col, mix(col, rgb(243, 199, 102), 0.05), fill(d - r * 3.4));
    col = mix(col, mix(col, rgb(243, 199, 102), 0.08), fill(d - r * 2.4));
    col = mix(col, mix(col, rgb(246, 212, 130), 0.14), fill(d - r * 1.65));
    float sd = sdStar5(p, r, 0.46);
    float a = atan(p.x, p.y);
    float facet = (floor(a / 0.6283185) + 0.5) * 0.6283185;
    float l = cos(facet + 0.8);
    vec3 sc = mix(rgb(178, 120, 52), rgb(232, 180, 86), step(-0.3, l));
    sc = mix(sc, rgb(254, 230, 160), step(0.55, l));
    return mix(col, sc, fill(sd));
}

// ── The square ──

// The path's middle and half width at height y, from the foreground to the square
// at its end e.
vec2 path(float y, vec2 e, float aspect) {
    float f = clamp(y / e.y, 0.0, 1.0);
    return vec2(mix(aspect * 0.42, e.x, f) + 0.09 * sin(f * 3.1416) * (1.0 - f * 0.4), mix(0.13, 0.028, pow(f, 0.8)));
}

// A lantern on a post at foot b, s tall: a dark post, a hooded lantern with a warm
// flame, rings of its light round it, and a pool of it on the snow.
vec3 lantern(vec3 col, vec2 q, vec2 b, float s) {
    vec2 p = (q - b) / s;
    if (abs(p.x) > 3.5 || p.y < -0.6 || p.y > 2.0)
        return col;
    float e = PX / s;
    float pool = length(p * vec2(0.7, 2.6));
    col = mix(col, mix(col, rgb(243, 199, 102), 0.18), smoothstep(1.0 + e * 2.0, 1.0 - e * 2.0, pool));
    vec2 lc = vec2(0.0, 1.22);
    float halo = length(p - lc);
    col = mix(col, mix(col, rgb(243, 199, 102), 0.12), smoothstep(0.7 + e, 0.7 - e, halo));
    col = mix(col, mix(col, rgb(243, 199, 102), 0.2), smoothstep(0.42 + e, 0.42 - e, halo));
    vec3 iron = rgb(22, 30, 32);
    float post = smoothstep(e, -e, abs(p.x) - 0.035) * step(0.0, p.y) * step(p.y, 1.05);
    col = mix(col, iron, post);
    float box = smoothstep(e, -e, max(abs(p.x) - 0.12 + (p.y - 1.05) * 0.12, abs(p.y - 1.2) - 0.15));
    col = mix(col, iron, box);
    float flame = smoothstep(e, -e, max(abs(p.x) - 0.08 + (p.y - 1.05) * 0.1, abs(p.y - 1.2) - 0.11));
    col = mix(col, rgb(252, 214, 130), flame);
    float hood = smoothstep(e, -e, max(abs(p.x) - 0.17 + (p.y - 1.35) * 1.2, abs(p.y - 1.4) - 0.06));
    col = mix(col, iron, hood);
    float cap = smoothstep(e, -e, length((p - vec2(0.0, 1.47)) * vec2(1.0, 1.8)) - 0.13) * step(1.44, p.y);
    return mix(col, rgb(214, 226, 228), cap);
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    PX = 1.0 / u.resolution.y;
    float aspect = u.resolution.x / u.resolution.y;
    MOON = vec2(aspect * 0.2, 0.79);
    float dm = length(q - MOON);
    float horizon = 0.42;

    // ── Sky in flat bands, a glow low over the ridges, stars overhead ──
    float t = clamp((q.y - horizon) / (1.0 - horizon), 0.0, 1.0);
    t = pow(t, 0.8) - 0.1 * exp(-dm * 3.0) + (fbm(vec2(q.x * 1.2, q.y * 4.0)) - 0.5) * 0.04;
    vec3 col = sky(steps(clamp(t, 0.0, 1.0), 11.0));
    float stars = max(starField(q, 0.022, 0.1, 1.0, 0.0016, PX * 0.9, PX),
                      starField(q + 0.31, 0.05, 0.22, 7.0, 0.0026, PX, PX));
    col = mix(col, rgb(242, 238, 228), stars * smoothstep(0.55, 0.8, q.y) * smoothstep(0.1, 0.3, dm));

    // ── The moon in rings of light, its seas faint on its face ──
    col = mix(col, mix(col, rgb(196, 220, 214), 0.08), fill(dm - 0.25));
    col = mix(col, mix(col, rgb(206, 226, 218), 0.1), fill(dm - 0.165));
    col = mix(col, mix(col, rgb(222, 234, 224), 0.16), fill(dm - 0.105));
    vec3 mc = rgb(246, 238, 222);
    vec2 mp = (q - MOON) / 0.068;
    float seas = fbm(mp * 1.6 + 3.0);
    mc = mix(mc, rgb(224, 218, 204), band(seas, 0.55));
    mc = mix(mc, rgb(210, 206, 194), band(seas, 0.66));
    col = mix(col, mc, fill(dm - 0.068));

    // ── Snowy mountains far off, and nearer ridges billowing under the moon ──
    col = range(col, q, horizon, 0.42, 0.22, 3.0, rgb(130, 160, 166), rgb(82, 110, 122), rgb(68, 92, 104), rgb(184, 204, 204));
    float r1 = horizon - 0.02 + 0.045 * billows(q.x + 0.3, 2.6, 7.0);
    col = mix(col, rgb(102, 130, 142), below(r1, q.y));
    float u1 = r1 - 0.03 + 0.02 * billows(q.x + 2.1, 5.0, 8.0);
    col = mix(col, rgb(84, 112, 126), below(u1, q.y) * below(r1, q.y));
    col = mix(col, rgb(196, 214, 214), below(r1, q.y) * (1.0 - below(r1 - 0.004, q.y)));
    // Pines darken the foot of the slopes.
    float fx = q.x / 0.007 + 0.4 * vnoise(vec2(q.x * 30.0, 3.0));
    float fc = floor(fx);
    float fy = horizon - 0.04 + 0.012 * vnoise(vec2(q.x * 5.0, 4.0));
    float fh = 0.008 + 0.014 * hash(vec2(fc, 2.0)) * step(0.25, hash(vec2(fc, 5.0)));
    float pine = fill(abs(fract(fx) - 0.5) * 0.007 - (fy + fh - q.y) * 0.28) * fill(q.y - fy - fh);
    col = mix(col, rgb(22, 44, 42), max(pine, fill(q.y - fy)));

    // ── The far snowfield, with cottages at its edge ──
    vec3 hz = rgb(112, 142, 150);
    vec3 smLit = rgb(196, 212, 214), smShade = rgb(126, 150, 162);
    float hA = horizon - 0.045 + 0.006 * billows(q.x, 9.0, 21.0);
    col = mix(col, rgb(146, 172, 180), below(hA, q.y));
    col = mix(col, rgb(196, 212, 214), below(hA, q.y) * (1.0 - below(hA - 0.004, q.y)));
    col = cottage(col, q, vec2(0.27, 0.364), vec4(0.03, 0.04, 0.022, 0.028), 1.0, 0.6, rgb(150, 70, 66), 1.0, hz, 0.35);
    col = cottage(col, q, vec2(0.36, 0.368), vec4(0.024, 0.016, 0.024, 0.034), -1.0, 0.3, rgb(170, 150, 120), 2.0, hz, 0.35);
    col = cottage(col, q, vec2(0.6, 0.362), vec4(0.034, 0.056, 0.024, 0.024), 1.0, 0.7, rgb(90, 120, 118), 3.0, hz, 0.35);
    col = cottage(col, q, vec2(0.74, 0.366), vec4(0.026, 0.03, 0.022, 0.034), 1.0, 0.4, rgb(176, 130, 80), 4.0, hz, 0.35);
    col = cottage(col, q, vec2(1.48, 0.364), vec4(0.03, 0.04, 0.023, 0.028), -1.0, 0.5, rgb(150, 70, 66), 5.0, hz, 0.35);
    col = cottage(col, q, vec2(1.6, 0.368), vec4(0.026, 0.026, 0.026, 0.03), 1.0, 0.5, rgb(170, 150, 120), 6.0, hz, 0.35);
    col = smoke(col, q, chimneyTop(vec2(0.6, 0.362), vec4(0.034, 0.056, 0.024, 0.024), 1.0, 0.7), 0.1, 0.003, 1.0, smLit, smShade);
    col = smoke(col, q, chimneyTop(vec2(1.48, 0.364), vec4(0.03, 0.04, 0.023, 0.028), -1.0, 0.5), 0.09, 0.003, 2.0, smLit, smShade);

    // A bank of snow, and the middle row of cottages.
    float hB = 0.34 + 0.014 * billows(q.x + 0.6, 5.0, 22.0);
    col = mix(col, rgb(134, 160, 170), below(hB, q.y));
    col = mix(col, rgb(116, 142, 154), below(hB - 0.02 + 0.012 * billows(q.x + 3.1, 8.0, 23.0), q.y));
    col = mix(col, rgb(204, 218, 220), below(hB, q.y) * (1.0 - below(hB - 0.005, q.y)));
    col = cottage(col, q, vec2(0.15, 0.296), vec4(0.054, 0.066, 0.042, 0.052), 1.0, 0.65, rgb(140, 62, 60), 11.0, hz, 0.18);
    col = cottage(col, q, vec2(0.36, 0.302), vec4(0.044, 0.01, 0.05, 0.064), 1.0, 0.5, rgb(168, 150, 124), 12.0, hz, 0.18);
    col = cottage(col, q, vec2(0.66, 0.294), vec4(0.056, 0.084, 0.04, 0.042), 1.0, 0.25, rgb(84, 112, 112), 13.0, hz, 0.18);
    col = cottage(col, q, vec2(0.94, 0.3), vec4(0.042, 0.03, 0.046, 0.04), -1.0, 0.6, rgb(170, 122, 76), 14.0, hz, 0.18);
    col = cottage(col, q, vec2(1.58, 0.296), vec4(0.056, 0.064, 0.048, 0.05), -1.0, 0.35, rgb(110, 84, 70), 15.0, hz, 0.18);
    col = cottage(col, q, vec2(1.66, 0.3), vec4(0.04, 0.03, 0.036, 0.05), 1.0, 0.5, rgb(140, 62, 60), 16.0, hz, 0.18);
    col = smoke(col, q, chimneyTop(vec2(0.15, 0.296), vec4(0.054, 0.066, 0.042, 0.052), 1.0, 0.65), 0.15, 0.004, 3.0, smLit, smShade);
    col = smoke(col, q, chimneyTop(vec2(0.66, 0.294), vec4(0.056, 0.084, 0.04, 0.042), 1.0, 0.25), 0.14, 0.004, 4.0, smLit, smShade);
    col = smoke(col, q, chimneyTop(vec2(1.58, 0.296), vec4(0.056, 0.064, 0.048, 0.05), -1.0, 0.35), 0.14, 0.004, 5.0, smLit, smShade);

    // The nearer ground the square lies on, its light warm round the great fir.
    float hC = 0.262 + 0.016 * billows(q.x + 1.4, 3.6, 24.0);
    col = mix(col, rgb(124, 150, 162), below(hC, q.y));
    col = mix(col, rgb(108, 134, 148), below(hC - 0.022 + 0.014 * billows(q.x + 5.3, 6.0, 25.0), q.y));
    col = mix(col, rgb(206, 220, 222), below(hC, q.y) * (1.0 - below(hC - 0.005, q.y)));
    vec2 tb = vec2(aspect * 0.655, 0.2);
    float th = 0.66, tw = 0.25, tn = 8.0;
    float glow = length((q - tb) * vec2(0.6, 2.4));
    col = mix(col, mix(col, rgb(243, 199, 102), 0.1), fill(glow - 0.11) * fill(q.y - 0.27));
    col = mix(col, mix(col, rgb(243, 199, 102), 0.1), fill(glow - 0.065) * fill(q.y - 0.27));

    // ── The great fir and its finery ──
    Fir great = fir(q, tb, th, tw, tn, 3.0, rgb(66, 116, 88), rgb(36, 76, 60), rgb(20, 46, 40), rgb(232, 238, 234), rgb(146, 170, 180), rgb(70, 46, 38));
    col = drawFir(col, great);
    col = lights(col, q, great, tb, th, tw, tn, 3.0);
    col = baubles(col, q, tb, th, tw, tn, 3.0);
    col = topStar(col, q, vec2(firAxis(tb.y + th, tb, th, tw, 3.0), tb.y + th + 0.016), 0.034);

    // ── Cottages round the square ──
    col = cottage(col, q, vec2(0.36, 0.214), vec4(0.086, 0.11, 0.066, 0.08), 1.0, 0.7, rgb(150, 62, 62), 21.0, hz, 0.0);
    col = cottage(col, q, vec2(0.68, 0.226), vec4(0.062, 0.028, 0.084, 0.074), 1.0, 0.5, rgb(176, 160, 134), 22.0, hz, 0.0);
    col = cottage(col, q, vec2(1.62, 0.2), vec4(0.09, 0.07, 0.07, 0.066), -1.0, 0.3, rgb(90, 120, 116), 23.0, hz, 0.0);
    col = smoke(col, q, chimneyTop(vec2(0.36, 0.214), vec4(0.086, 0.11, 0.066, 0.08), 1.0, 0.7), 0.22, 0.006, 6.0, smLit, smShade);
    col = smoke(col, q, chimneyTop(vec2(1.62, 0.2), vec4(0.09, 0.07, 0.07, 0.066), -1.0, 0.3), 0.2, 0.006, 7.0, smLit, smShade);

    // ── The path in, between drifts, lanterns along it ──
    vec2 pe = vec2(tb.x - 0.05, 0.205);
    vec2 pth = path(q.y, pe, aspect);
    float pxc = pth.x, pw = pth.y;
    float onPath = fill(abs(q.x - pxc) - pw) * fill(q.y - 0.205);
    col = mix(col, rgb(100, 126, 140), onPath);
    col = mix(col, rgb(88, 114, 128), onPath * band(vnoise(vec2((q.x - pxc) / pw * 3.0, q.y * 60.0)), 0.68));
    // Its edges: the bank on its right catches the moon.
    col = mix(col, rgb(196, 212, 214), fill(abs(q.x - pxc - pw) - PX * 2.5 - pw * 0.04) * fill(q.y - 0.205));
    col = mix(col, rgb(70, 94, 108), fill(abs(q.x - pxc + pw) - PX * 2.0 - pw * 0.03) * fill(q.y - 0.205));
    vec2 la = path(0.13, pe, aspect), lb = path(0.045, pe, aspect);
    col = lantern(col, q, vec2(la.x + la.y * 1.25, 0.13), 0.05);
    col = lantern(col, q, vec2(lb.x - lb.y * 1.2, 0.045), 0.085);

    // ── Drifts in the foreground, with firs framing the edges ──
    float hL = 0.1 + 0.07 * smoothstep(0.55, 0.0, q.x) + 0.025 * billows(q.x + 0.2, 4.0, 31.0);
    float lm = fill(q.x - (pxc - pw * 1.1)) ;
    col = mix(col, rgb(58, 82, 96), below(hL, q.y) * lm);
    col = mix(col, rgb(46, 68, 82), below(hL - 0.04 + 0.02 * billows(q.x + 1.7, 7.0, 32.0), q.y) * lm);
    col = mix(col, rgb(160, 182, 190), below(hL, q.y) * (1.0 - below(hL - 0.006, q.y)) * lm);
    float hR = 0.08 + 0.08 * smoothstep(aspect - 0.6, aspect, q.x) + 0.022 * billows(q.x + 0.9, 4.5, 33.0);
    float rm = fill((pxc + pw * 1.1) - q.x);
    col = mix(col, rgb(58, 82, 96), below(hR, q.y) * rm);
    col = mix(col, rgb(46, 68, 82), below(hR - 0.04 + 0.02 * billows(q.x + 2.9, 7.0, 34.0), q.y) * rm);
    col = mix(col, rgb(160, 182, 190), below(hR, q.y) * (1.0 - below(hR - 0.006, q.y)) * rm);
    vec3 eLit = rgb(38, 72, 60), eMid = rgb(24, 50, 44), eShade = rgb(14, 32, 30), esLit = rgb(176, 196, 202), esShade = rgb(98, 122, 136), eBark = rgb(40, 30, 28);
    col = drawFir(col, fir(q, vec2(0.075, 0.14), 0.56, 0.13, 7.0, 11.0, eLit, eMid, eShade, esLit, esShade, eBark));
    col = drawFir(col, fir(q, vec2(0.235, 0.12), 0.3, 0.075, 6.0, 12.0, eLit, eMid, eShade, esLit, esShade, eBark));
    col = drawFir(col, fir(q, vec2(aspect - 0.07, 0.12), 0.46, 0.115, 7.0, 13.0, eLit, eMid, eShade, esLit, esShade, eBark));
    col = drawFir(col, fir(q, vec2(aspect - 0.2, 0.1), 0.2, 0.055, 5.0, 14.0, eLit, eMid, eShade, esLit, esShade, eBark));

    // ── Snow falling, far flakes small and dim, near ones large ──
    for (int l = 0; l < 4; l++) {
        float fl = float(l);
        float cell = 0.03 + 0.024 * fl;
        vec2 sq = q + vec2(0.37 * fl + 0.1 * q.y, 0.53 * fl);
        vec2 g = floor(sq / cell);
        vec2 hh = hash2(g + fl * 13.0);
        if (hash(g + fl * 7.0 + 0.5) < 0.42 - 0.04 * fl) {
            vec2 c = (g + 0.2 + 0.6 * hh) * cell;
            float r = (0.0011 + 0.0011 * fl) * mix(0.6, 1.3, hh.y);
            col = mix(col, mix(rgb(176, 198, 204), rgb(242, 238, 228), fl / 3.0), fill(length(sq - c) - r) * mix(0.6, 0.92, fl / 3.0));
        }
    }

    fragColor = vec4(col, 1.0);
}
