#version 440
#extension GL_GOOGLE_include_directive : enable
// Ember dusk: a lopsided volcano erupts at dusk, its plume heaving up in billows lit
// from the crater below and spreading into a ceiling of ash banks whose undersides
// catch the glow. Lava runs from the crater down gullies between its spurs, their
// crests lit by it, into a pool at its foot and a river that winds through the
// valley toward the viewer, crusted with drifting plates. Across the valley a
// temple of tiered crimson roofs stands on its cliff against the low sun, drawn in
// rings through a sky banded from crimson to gold; lanterns mark the stair up to
// it. Crags frame the foreground, rimmed by the river's light, lava fountains from
// the crater, and embers drift up at every depth.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
} u;
#include "../../effects/common/common.glsl"
#include "../landscape.glsl"

float PX;                                   // one pixel, in q
const vec2 CRATER = vec2(0.6, 0.62);
const float FLOOR = 0.3;                    // where the valley floor meets the far side

// Coverage of a signed distance in q, without derivatives, so it is safe anywhere.
float fill(float d) {
    return smoothstep(PX, -PX, d);
}

// Smooth maximum of two distances, rounding the corner where they meet by k.
float smax(float a, float b, float k) {
    float h = clamp(0.5 - 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) + k * h * (1.0 - h);
}

// Five-stop sky ramp, horizon to zenith.
vec3 sky(float t) {
    vec3 a = rgb(250, 192, 98), b = rgb(242, 128, 56), c = rgb(198, 60, 42);
    vec3 d = rgb(118, 26, 34), e = rgb(52, 14, 22);
    if (t < 0.2) return mix(a, b, t / 0.2);
    if (t < 0.45) return mix(b, c, (t - 0.2) / 0.25);
    if (t < 0.72) return mix(c, d, (t - 0.45) / 0.27);
    return mix(d, e, (t - 0.72) / 0.28);
}

// The main cone's skyline: a long concave flank to the left, a steeper one to the
// right, its summit broken into two rims round the crater, the left one higher.
float coneTop(float x) {
    float dx = x - CRATER.x;
    float h = CRATER.y + 0.006 - (dx < 0.0 ? 0.47 : 0.6) * pow(max(abs(dx + 0.004) - 0.034, 0.0), 0.68);
    h += 0.008 * smoothstep(0.02, -0.04, dx);
    float dd = (dx - 0.002) / 0.024;
    h -= 0.016 * max(0.0, 1.0 - dd * dd);
    return h + (vnoise(vec2(x * 38.0, 2.0)) - 0.5) * 0.012 + (vnoise(vec2(x * 130.0, 3.0)) - 0.5) * 0.004;
}

// A spur standing in front of the cone: its apex, its slopes left and right.
float spurTop(float x, vec2 apex, float kl, float kr, float seed) {
    float dx = x - apex.x;
    return apex.y - (dx < 0.0 ? kl : kr) * pow(abs(dx), 1.25)
         + (vnoise(vec2(x * 44.0, seed)) - 0.5) * 0.012 + (vnoise(vec2(x * 140.0, seed + 1.0)) - 0.5) * 0.004;
}

// Where q lies among the ridges running down from an apex, spaced 1 / freq apart
// at unit drop and spreading as they fall: x the ridge cell's coordinate, y where
// its crest sits in it (0..1), z the cell's width in q.
vec3 ridges(vec2 q, vec2 apex, float freq, float seed) {
    float sc = pow(apex.y - q.y + 0.03, 0.75) / freq;
    float g = (q.x - apex.x) / sc + 0.7 * (vnoise(vec2(q.y * 6.0, seed)) - 0.5) + 0.25 * (vnoise(vec2(q.y * 19.0, seed + 2.0)) - 0.5);
    // Unevenly spaced: the cells stretched and squeezed in turn.
    g += 0.32 * sin(g * 1.7 + seed);
    float pk = mix(0.25, 0.75, hash(vec2(floor(g), seed)));
    return vec3(g, pk, sc);
}

// A rock face below an apex, cut by ridges: their faces toward the sun (right) lit,
// the others shaded, and the whole darker left of its spine; its crests rimmed
// where light catches them.
vec3 rockFace(vec2 q, vec2 apex, float freq, float seed, vec3 shade, vec3 mid, vec3 lit, vec3 rim, float rimAmt) {
    vec3 r = ridges(q, apex, freq, seed);
    float cell = floor(r.x), f = fract(r.x);
    float spine = (vnoise(vec2(q.y * 9.0, seed + 4.0)) - 0.5) * 0.06;
    bool sunny = q.x - apex.x > spine;
    // Each ridge rises out of the face at its own height below the apex, its lit
    // side opening out of a point.
    float start = apex.y - mix(0.03, 0.2, hash(vec2(cell, seed + 3.0)));
    float open = clamp((start - q.y) / 0.1, 0.0, 1.0);
    bool started = open > 0.0;
    bool facing = started && f > mix(1.0, r.y, sqrt(open));
    vec3 c = facing ? (sunny ? lit : mid) : (sunny ? mid : shade);
    // The crest, a line along the facing side, only on some ridges.
    float on = step(0.5, hash(vec2(cell, seed + 7.0))) * (started ? 1.0 : 0.0);
    float pk = mix(1.0, r.y, sqrt(open));
    c = mix(c, rim, fill((f - pk) * r.z - 0.0024) * step(pk, f) * on * rimAmt);
    return c;
}

// The distance from q to lava channel n down the cone's gully n, and how far down it is.
vec2 channel(vec2 q, float n) {
    vec3 r = ridges(q, CRATER, 4.5, 11.0);
    return vec2(abs(r.x - n) * r.z, CRATER.y - q.y);
}

// ── The plume: billows heaving up from the crater, leaning with the wind ──
const int PUFFS = 30;

// The plume's axis at height y.
float plumeX(float y) {
    float t = clamp((y - CRATER.y) / 0.3, 0.0, 1.2);
    return CRATER.x + 0.04 * t + 0.24 * t * t;
}
const int FRONT = 18;

vec3 puff(int i) {
    float fi = float(i);
    float t = fi / float(PUFFS - 1);
    vec2 h = hash2(vec2(fi, 41.0));
    float y = CRATER.y + 0.025 + 0.34 * t;
    float r = mix(0.026, 0.12, t) * mix(0.75, 1.2, h.y);
    vec2 c = vec2(plumeX(y) + (h.x - 0.5) * mix(0.025, 0.2, t), y);
    return vec3(c, r);
}

// The distance to the edge of the plume's billows from 'from' on (the higher first,
// so the lower stand in front); from 0 a core fills the gaps between them.
float plumeDist(vec2 q, int from) {
    float d = 1e5;
    for (int i = from; i < PUFFS; i++) {
        vec3 o = puff(PUFFS - 1 - i);
        d = min(d, length(q - o.xy) - o.z);
    }
    if (from == 0) {
        float t = clamp((q.y - CRATER.y) / 0.3, 0.0, 1.2);
        d = min(d, abs(q.x - plumeX(q.y)) - mix(0.012, 0.09, t));
    }
    return smax(d, CRATER.y - 0.004 - q.y, 0.01);
}

// ── The river: from the pool at the volcano's foot it swings across the valley and
//    toward the viewer, widening as it nears ──
const int RIVER = 48;

// Its course, point i of nine.
vec2 rp(int i) {
    if (i <= 0) return vec2(0.58, 0.297);
    if (i == 1) return vec2(0.7, 0.285);
    if (i == 2) return vec2(0.9, 0.264);
    if (i == 3) return vec2(1.02, 0.234);
    if (i == 4) return vec2(0.93, 0.186);
    if (i == 5) return vec2(0.78, 0.124);
    if (i == 6) return vec2(0.83, 0.052);
    if (i == 7) return vec2(1.02, -0.02);
    return vec2(1.14, -0.08);
}

// The point t (0..1) along it: a Catmull-Rom spline through its course.
vec2 riverPoint(float t) {
    float s = clamp(t, 0.0, 0.9999) * 8.0;
    int i = int(floor(s));
    float f = fract(s);
    vec2 p0 = rp(i - 1), p1 = rp(i), p2 = rp(i + 1), p3 = rp(i + 2);
    return 0.5 * (2.0 * p1 + (p2 - p0) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (3.0 * p1 - p0 - 3.0 * p2 + p3) * f * f * f);
}

// Its half width at a height: narrow far off, broad near.
float riverWidth(float y) {
    return 0.004 + 0.07 * pow(clamp((FLOOR - y) / FLOOR, 0.0, 1.2), 1.5);
}

// A temple of tiered roofs standing on base, s its scale: dark walls with lit
// windows, crimson roofs with gold-trimmed eaves that turn up at the tips.
vec3 temple(vec3 col, vec2 q, vec2 base, float s) {
    vec3 wall = rgb(36, 13, 16), roof = rgb(104, 22, 24), roofLit = rgb(150, 38, 30), trim = rgb(240, 172, 74), glow = rgb(255, 190, 96);
    vec2 p = (q - base) / s;
    if (abs(p.x) > 4.0 || p.y < -0.2 || p.y > 6.5)
        return col;
    float e = PX / s;
    // A wall along the cliff's edge, crenellated, with a gate.
    float wallIn = smoothstep(e, -e, abs(p.x) - 3.6) * smoothstep(-e, e, p.y) * smoothstep(e, -e, p.y - 0.42 - 0.12 * step(0.5, fract(p.x * 2.2)));
    col = mix(col, wall, wallIn);
    col = mix(col, glow, smoothstep(e, -e, abs(p.x) - 0.14) * smoothstep(e, -e, p.y - 0.3) * wallIn);
    // Halls: a tall pagoda in the middle, a lower one on each side.
    for (int w = -1; w <= 1; w++) {
        float fw = float(w);
        vec2 o = p - vec2(fw * 2.2, 0.35);
        int tiers = w == 0 ? 4 : 2;
        float sc = w == 0 ? 1.0 : 0.72;
        for (int i = 0; i < 4; i++) {
            if (i >= tiers)
                break;
            float fi = float(i);
            float y0 = fi * 0.95 * sc;
            float ww = (1.0 - 0.2 * fi) * sc;
            float ax = abs(o.x);
            float hall = smoothstep(e, -e, ax - ww) * smoothstep(-e, e, o.y - y0) * smoothstep(e, -e, o.y - y0 - 0.5 * sc);
            col = mix(col, wall, hall);
            float wx = fract(o.x / (0.3 * sc) + 0.5) - 0.5;
            float win = smoothstep(e, -e, abs(wx) - 0.08) * smoothstep(e, -e, abs(o.y - y0 - 0.24 * sc) - 0.11 * sc) * smoothstep(e, -e, ax - ww + 0.12);
            col = mix(col, glow, hall * win);
            float ry = o.y - (y0 + 0.46 * sc);
            float rw = (ww + 0.4 * sc) - ry * 1.7;
            float eave = 0.2 * sc * pow(clamp(ax / (ww + 0.4 * sc), 0.0, 1.0), 5.0);
            float roofIn = smoothstep(e, -e, ax - rw) * smoothstep(-e, e, ry - eave) * smoothstep(e, -e, ry - 0.34 * sc);
            col = mix(col, o.x < 0.0 ? roofLit : roof, roofIn);
            col = mix(col, trim, roofIn * smoothstep(e * 1.5, -e * 1.5, abs(ry - eave - 0.035) - 0.03));
        }
    }
    // A spire with a gold finial over the pagoda.
    float ty = p.y - 4.05;
    float tw = 0.11 * clamp(1.0 - ty / 1.1, 0.0, 1.0);
    col = mix(col, roof, smoothstep(e, -e, abs(p.x) - tw) * smoothstep(-e, e, ty) * smoothstep(e, -e, ty - 1.1));
    col = mix(col, trim, smoothstep(e, -e, length(p - vec2(0.0, 5.25)) - 0.09));
    return col;
}

// An ash bank hanging from the ceiling, k far (0) to near (2): its billowed underside
// lit by the glow below, a rim of light along its edge.
vec3 ashBank(vec3 col, vec2 q, int k, float hb, float heat, float sunLit) {
    float fk = float(k);
    float inBank = cover(q.y - hb);
    vec3 body = k == 0 ? rgb(88, 24, 28) : k == 1 ? rgb(62, 18, 24) : rgb(40, 12, 17);
    vec3 lit = mix(k == 0 ? rgb(146, 44, 36) : k == 1 ? rgb(112, 32, 32) : rgb(84, 24, 26), rgb(206, 80, 42), heat * (1.0 - 0.25 * fk));
    lit = mix(lit, rgb(234, 124, 62), sunLit * (1.0 - 0.45 * fk));
    vec3 rim = mix(rgb(212, 90, 46), rgb(255, 176, 90), max(heat, sunLit) * (1.0 - 0.3 * fk));
    float hu = hb + 0.016 + 0.022 * billows(q.x + fk * 5.3, 6.0 + fk * 2.0, 80.0 + fk);
    vec3 c = mix(lit, body, cover(q.y - hu));
    c = mix(c, rim, 1.0 - cover(q.y - hb - 0.0035));
    return mix(col, c, inBank);
}

// The underside of ash bank k at x: few broad billows with smaller ones on them,
// sagging where the plume feeds it, rising off the top toward the sun.
float bankEdge(float x, int k) {
    float fk = float(k);
    // Where each bank lies, its ends receding up into the ceiling.
    float x0 = k == 0 ? 0.15 : k == 1 ? -0.3 : 1.05;
    float x1 = k == 0 ? 2.0 : k == 1 ? 1.25 : 2.0;
    float base = (k == 0 ? 0.775 : k == 1 ? 0.83 : 0.885) + 0.05 * (fbm(vec2(x * 0.9, fk * 7.0 + 1.0)) - 0.5);
    base -= (0.06 - 0.012 * fk) * exp(-pow((x - plumeX(0.92)) / 0.28, 2.0));
    base += 0.22 * (smoothstep(x0 + 0.25, x0 - 0.05, x) + smoothstep(x1 - 0.25, x1 + 0.05, x));
    return base - (0.05 - 0.006 * fk) * billows(x + fk * 3.1, 2.8 + 1.0 * fk, 70.0 + fk);
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    PX = 1.0 / u.resolution.y;
    float aspect = u.resolution.x / u.resolution.y;
    vec2 sun = vec2(aspect * 0.8, 0.47);
    float ds = length(q - sun);

    // ── Sky: flat bands, bowing up round the sun ──
    float t = clamp((q.y - FLOOR) / (1.0 - FLOOR), 0.0, 1.0);
    t = pow(t, 0.8) - 0.12 * exp(-ds * 2.8) + (fbm(vec2(q.x * 1.2, q.y * 4.0)) - 0.5) * 0.04;
    vec3 col = sky(steps(clamp(t, 0.0, 1.0), 11.0));

    // The low sun in rings, streaks of ash drawn across it.
    col = mix(col, mix(col, rgb(255, 176, 84), 0.16), cover(0.24 - ds));
    col = mix(col, mix(col, rgb(255, 192, 104), 0.28), cover(0.158 - ds));
    col = mix(col, rgb(255, 184, 92), cover(0.102 - ds));
    col = mix(col, rgb(255, 226, 160), cover(0.074 - ds));
    float slit = band(fbm(vec2(q.x * 2.6, q.y * 38.0) + vec2(3.0, 0.0)), 0.62) * smoothstep(0.43, 0.46, q.y) * (1.0 - smoothstep(0.6, 0.64, q.y));
    col = mix(col, mix(rgb(150, 40, 36), rgb(232, 110, 56), exp(-abs(q.x - sun.x) * 3.0)), slit * 0.85);

    // ── The ash ceiling, far banks first; the plume heaves up in front of them
    //    and into the nearest ──
    float heat = exp(-abs(q.x - plumeX(0.85)) * 1.8);
    float sunLit = exp(-abs(q.x - sun.x) * 2.4);
    col = mix(col, rgb(30, 10, 14), cover(q.y - 0.94 - 0.03 * billows(q.x, 2.0, 66.0)));
    col = ashBank(col, q, 0, bankEdge(q.x, 0), heat, sunLit);
    col = ashBank(col, q, 1, bankEdge(q.x, 1), heat, sunLit);

    // The plume, lit as one body from the crater below: light along its edges
    // toward the crater and a rim right at them, the front billows lit along their
    // own edges and shading what lies behind them, the glow fading as it rises.
    float dAll = plumeDist(q, 0);
    if (dAll < PX * 2.0) {
        vec2 toLight = normalize(CRATER - q);
        float warm = smoothstep(0.95, 0.68, q.y);
        vec3 pDark = mix(rgb(40, 13, 18), rgb(58, 18, 22), warm);
        vec3 pMid = mix(rgb(70, 21, 25), rgb(120, 36, 30), warm);
        vec3 pLit = mix(rgb(132, 40, 32), rgb(222, 96, 46), warm);
        vec3 pRim = mix(rgb(204, 86, 44), rgb(255, 184, 90), warm);
        int from = plumeDist(q, FRONT) < 0.0 ? FRONT : 0;
        float lb = from == 0 ? 0.04 : 0.024;
        float dl = min(plumeDist(q + toLight * lb, from), plumeDist(q + toLight * lb * 0.6, from) + lb * 0.4);
        float dsh = plumeDist(q - toLight * 0.05, 0);
        vec3 sc = pMid;
        sc = mix(sc, pDark, 1.0 - fill(dsh));
        if (from == 0)
            sc = mix(sc, mix(sc, pDark, 0.6), fill(plumeDist(q + toLight * 0.009, FRONT)));
        sc = mix(sc, pLit, 1.0 - fill(dl));
        float toward = 1.0 - fill(plumeDist(q + toLight * 0.006, 0));
        sc = mix(sc, pRim, (1.0 - fill(dAll + 0.003)) * toward);
        col = mix(col, sc, fill(dAll));
    }
    // A fountain of lava out of the crater, in ragged tongues.
    vec2 fq = (q - CRATER - vec2(0.002, -0.004)) / vec2(0.014, 0.034);
    float tongue = length(vec2(fq.x * (1.0 + fq.y), fq.y)) - 1.0 + 0.8 * (vnoise(vec2(q.x * 160.0, q.y * 40.0)) - 0.5);
    float fl = fill(tongue * 0.02) * step(CRATER.y - 0.01, q.y);
    col = mix(col, rgb(240, 110, 46), fl);
    col = mix(col, rgb(255, 206, 110), fl * fill((tongue + 0.45) * 0.02));
    col = ashBank(col, q, 2, bankEdge(q.x, 2), heat, sunLit);

    // ── Far ranges, hazed with the dusk, rimmed toward the sun ──
    for (int k = 0; k < 2; k++) {
        float fk = float(k);
        float h = FLOOR + 0.03 - 0.012 * fk + (0.075 - 0.02 * fk) * ridge(q.x + fk * 4.0, 2.4 + fk, 50.0 + fk);
        h -= 0.05 * exp(-abs(q.x - sun.x) * 6.0) * (1.0 - fk);
        vec3 c = k == 0 ? rgb(196, 86, 56) : rgb(140, 46, 40);
        vec3 rim = k == 0 ? rgb(244, 150, 80) : rgb(220, 104, 58);
        col = mix(col, mix(rim, c, cover(h - 0.004 - q.y)), below(h, q.y));
    }

    // ── The volcano: the cone, a shoulder on its right flank and a crag on its
    //    left, each cut by ridges ──
    float cone = below(coneTop(q.x), q.y);
    if (cone > 0.0) {
        vec3 c = rockFace(q, CRATER, 3.4, 11.0, rgb(44, 14, 19), rgb(70, 22, 24), rgb(112, 34, 30), rgb(232, 112, 56), 1.0);
        // Lava down three gullies from the crater into the pool at its foot, the
        // right one cooling to a stop halfway; each rims the rock beside it.
        for (int i = 0; i < 3; i++) {
            float n = i == 0 ? 0.0 : i == 1 ? -1.0 : 1.0;
            vec3 r = ridges(q, CRATER, 3.4, 11.0);
            float d = abs(r.x - n) * r.z;
            float drop = CRATER.y - q.y;
            float stop = i == 2 ? 0.17 : 1.0;
            float w = (i == 0 ? 0.003 + 0.013 * drop : 0.0022 + 0.008 * drop) * smoothstep(stop, stop - 0.05, drop);
            float on = step(0.012, drop);
            c = mix(c, rgb(210, 84, 44), fill(d - w - 0.004) * on);
            c = mix(c, rgb(66, 19, 20), fill(d - w - 0.0016) * on);
            c = mix(c, rgb(232, 84, 38), fill(d - w) * on);
            c = mix(c, rgb(250, 140, 52), fill(d - w * 0.55) * on);
            c = mix(c, rgb(255, 210, 112), fill(d - w * 0.2) * on);
        }
        col = mix(col, c, cone);
    }
    vec2 shoulder = vec2(0.87, 0.452), crag = vec2(0.3, 0.488);
    float sh = spurTop(q.x, shoulder, 2.3, 1.3, 20.0);
    float inSh = below(sh, q.y);
    if (inSh > 0.0) {
        vec3 c = rockFace(q, shoulder, 4.0, 21.0, rgb(52, 16, 20), rgb(84, 26, 26), rgb(128, 40, 32), rgb(244, 140, 72), 1.0);
        c = mix(c, rgb(236, 128, 64), 1.0 - below(sh - 0.004, q.y));
        col = mix(col, c, inSh);
    }
    float cr = spurTop(q.x, crag, 2.0, 2.1, 30.0);
    float inCr = below(cr, q.y);
    if (inCr > 0.0) {
        vec3 c = rockFace(q, crag, 4.0, 31.0, rgb(36, 12, 16), rgb(56, 18, 21), rgb(92, 28, 26), rgb(214, 96, 50), 1.0);
        c = mix(c, rgb(200, 84, 46), (1.0 - below(cr - 0.004, q.y)) * step(crag.x - 0.02, q.x));
        col = mix(col, c, inCr);
    }

    // ── The cliff across the valley, the temple on it against the sun ──
    float cliffTop = 0.372 - 0.03 * smoothstep(1.58, 1.68, q.x) + (vnoise(vec2(q.x * 30.0, 6.0)) - 0.5) * 0.008;
    float face = 1.24 + (0.372 - q.y) * 0.3 + (vnoise(vec2(q.y * 40.0, 8.0)) - 0.5) * 0.02;
    float cliff = below(cliffTop, q.y) * cover(q.x - face);
    if (cliff > 0.0) {
        float cv = vnoise(vec2(q.x * 26.0, q.y * 4.0));
        vec3 cc = mix(rgb(40, 13, 16), rgb(30, 10, 13), band(cv, 0.55));
        cc = mix(cc, rgb(200, 84, 46), 1.0 - cover(q.x - face - 0.004));
        cc = mix(cc, rgb(232, 132, 66), 1.0 - below(cliffTop - 0.004, q.y));
        col = mix(col, cc, cliff);
    }
    col = temple(col, q, vec2(sun.x + 0.01, cliffTop - 0.002), 0.04);

    // ── The valley floor, banded by distance, lit by the river in steps ──
    float floorTop = FLOOR + 0.006 * lobes(q.x, 7.0, 5.0);
    float ground = below(floorTop, q.y);
    if (ground > 0.0) {
        // The nearest point of the river, measured in its widths, and how far along it.
        float best = 1e3, rd = 1.0, rw = 0.01, along = 0.0, alongAt = 0.0;
        vec2 a = riverPoint(0.0);
        for (int i = 1; i <= RIVER; i++) {
            vec2 b = riverPoint(float(i) / float(RIVER));
            vec2 ab = b - a;
            float h = clamp(dot(q - a, ab) / dot(ab, ab), 0.0, 1.0);
            vec2 c = a + ab * h;
            float wm = riverWidth(c.y);
            float d = length(q - c);
            if (d / wm < best) {
                best = d / wm;
                rd = d;
                rw = wm;
                alongAt = along + length(ab) * h / wm;
            }
            along += length(ab) / riverWidth((a.y + b.y) * 0.5);
            a = b;
        }
        // The pool at the volcano's foot, where its lava gathers.
        vec2 pool = (q - vec2(0.565, FLOOR - 0.003)) / vec2(0.08, 0.006);
        float pd = (length(pool) - 1.0) * 0.006;
        float dist = clamp((FLOOR - q.y) / FLOOR, 0.0, 1.0);
        vec3 g = mix(rgb(96, 32, 30), rgb(38, 13, 16), steps(pow(dist, 0.7), 5.0));
        float glowD = min((rd - rw) / (0.008 + 0.03 * dist), pd / 0.006);
        g = mix(g, rgb(112, 36, 30), 1.0 - band(glowD, 1.0));
        g = mix(g, rgb(168, 56, 36), 1.0 - band(glowD, 0.45));
        col = mix(col, g, ground);
        // The lava: bands from red to gold, plates of crust drifting on its cooler
        // edges with gold showing in the gaps, and a crust levee along its banks.
        float s = min(best, length(pool));
        float wob = (vnoise(vec2(alongAt * 1.4, 3.0)) - 0.5) * 0.3;
        float sw = min(best, 0.45 + 0.55 * length(pool)) + wob;
        vec3 lava = rgb(226, 74, 36);
        lava = mix(lava, rgb(248, 130, 48), 1.0 - band(sw, 0.62));
        lava = mix(lava, rgb(255, 200, 100), 1.0 - band(sw, 0.28));
        vec2 pp = vec2(alongAt * 1.6, s * 2.2);
        float edge = voronoiEdge(pp, 1.0, 0.85);
        float plates = band(edge, 0.09) * band(s + 0.25 * vnoise(pp * 0.7), 0.45);
        lava = mix(lava, rgb(74, 22, 20), plates);
        lava = mix(lava, rgb(150, 46, 30), plates * (1.0 - band(edge, 0.16)));
        lava = mix(lava, rgb(64, 18, 18), band(s, 0.9));
        col = mix(col, lava, (1.0 - band(s, 1.0)) * ground);
    }


    // ── Foreground: crags on either side, rimmed by the river's light ──
    float fc = 0.25 * pow(max(1.0 - q.x / 0.62, 0.0), 1.3) + 0.035 * ridge(q.x, 5.0, 91.0) * step(q.x, 0.6) - 0.02;
    float inFc = below(fc, q.y);
    if (inFc > 0.0) {
        vec3 c = rockFace(q, vec2(0.06, 0.27), 5.0, 93.0, rgb(24, 9, 11), rgb(36, 12, 14), rgb(58, 18, 18), rgb(206, 88, 46), 1.0);
        c = mix(c, rgb(214, 92, 48), 1.0 - below(fc - 0.005, q.y));
        col = mix(col, c, inFc);
    }
    float rc = 0.17 * pow(max(1.0 - (aspect - q.x) / 0.42, 0.0), 1.2) + 0.03 * ridge(q.x, 6.0, 95.0) * step(aspect - 0.42, q.x) - 0.015;
    float inRc = below(rc, q.y);
    if (inRc > 0.0) {
        vec3 c = rockFace(q, vec2(aspect - 0.04, 0.18), 5.0, 97.0, rgb(24, 9, 11), rgb(36, 12, 14), rgb(58, 18, 18), rgb(206, 88, 46), 1.0);
        c = mix(c, rgb(214, 92, 48), 1.0 - below(rc - 0.005, q.y));
        col = mix(col, c, inRc);
    }

    // ── Embers drifting up from the lava with the wind, small far off and large
    //    near, thickest over the river and the crater ──
    for (int i = 0; i < 110; i++) {
        float fi = float(i);
        vec2 h = hash2(vec2(fi, 4.2));
        float near = pow(hash(vec2(fi, 9.0)), 3.0);
        float rise = h.y * h.y;
        vec2 src = i < 40 ? vec2(CRATER.x, CRATER.y) : riverPoint(hash(vec2(fi, 6.0)));
        vec2 e = src + vec2((h.x - 0.35) * 0.5 + rise * 0.4, rise * (i < 40 ? 0.3 : 0.5));
        if (i >= 90)
            e = vec2(h.x * aspect, 0.05 + 0.6 * h.y);
        float r = mix(0.0013, 0.0065, near);
        float d = length((q - e) * vec2(1.0, mix(1.0, 0.6, near)));
        float fade = 1.0 - 0.6 * rise;
        col = mix(col, rgb(240, 110, 48), fill(d - r) * fade);
        col = mix(col, rgb(255, 212, 132), fill(d - r * 0.5) * fade);
    }

    fragColor = vec4(col, 1.0);
}
