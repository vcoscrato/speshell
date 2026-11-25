#version 440
#extension GL_GOOGLE_include_directive : enable
// Frozen lake on Christmas Eve: dusk settles over a wide frozen lake ringed by
// snow-laden pine forest on gentle hills. The sun has just gone down behind the
// far hills, banding the sky from deep violet overhead to rose and gold at the
// horizon, and the first stars come out. On a small snowy island stands a
// decorated Christmas tree, lit with strings of lights and crowned with a gold
// star, its glow and lights mirrored in the ice. On the right shore a log cabin
// with a wreath on its door glows warm under string lights, smoke curling from its
// chimney; lanterns light the path from its door down to the ice, where skate
// trails loop round the island. Light snow falls.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
} u;
#include "../../effects/common/common.glsl"
#include "../landscape.glsl"

const float SHORE = 0.405;      // the far shore
const float HZ = 0.445;         // eye level, behind the far hills
float PX;                       // one pixel, in q
float WILD = 1.0;               // 1 for wild firs, 0 for the island's tidy tree
float ASPECT;
vec2 SUN;

// Coverage of a signed distance in q, without derivatives, so it is safe anywhere.
float fill(float d) {
    return smoothstep(PX, -PX, d);
}

// Six-stop dusk ramp, horizon to zenith.
vec3 sky(float t) {
    vec3 a = rgb(255, 214, 152), b = rgb(246, 170, 132), c = rgb(218, 126, 142);
    vec3 d = rgb(148, 94, 146), e = rgb(78, 64, 124), f = rgb(32, 32, 76);
    if (t < 0.12) return mix(a, b, t / 0.12);
    if (t < 0.28) return mix(b, c, (t - 0.12) / 0.16);
    if (t < 0.48) return mix(c, d, (t - 0.28) / 0.2);
    if (t < 0.72) return mix(d, e, (t - 0.48) / 0.24);
    return mix(e, f, (t - 0.72) / 0.28);
}

// The tops of the banks round the lake: the far shore, the left shore, and the
// near bank, which rises on the right into the knoll the cabin stands on.
float farBank(float x) {
    return SHORE + 0.004 + 0.016 * vnoise5(vec2(x * 2.6, 4.0));
}

float leftShore(float x) {
    return SHORE - 0.25 * pow(1.0 - smoothstep(0.0, 0.6, x), 1.4) + 0.006 * vnoise5(vec2(x * 14.0, 6.0));
}

float leftBank(float x) {
    return leftShore(x) + 0.004 + 0.045 * pow(1.0 - smoothstep(0.0, 0.62, x), 1.2) + 0.008 * vnoise5(vec2(x * 6.0, 8.0));
}

float nearBank(float x) {
    return 0.068 + 0.05 * smoothstep(0.55, 0.0, x) + 0.198 * smoothstep(1.2, 1.56, x)
         + 0.008 * billows(x, 9.0, 3.0) + 0.01 * vnoise5(vec2(x * 3.0, 5.0));
}

float bankY(int which, float x) {
    return which == 0 ? farBank(x) : which == 1 ? leftBank(x) : nearBank(x);
}

// A snow-laden fir on its foot b, h tall, w half wide at its skirt: tiers of
// boughs, each flaring out over the one below, their tips drooping at the hem,
// snow lying along each tier under the next; lopsided and leaning by its seed.
struct Fir { float cov; float trunk; float snow; float lit; float rim; };

Fir fir(vec2 q, vec2 b, float h, float w, float seed, float snowiness) {
    Fir f = Fir(0.0, 0.0, 0.0, 0.0, 0.0);
    vec2 p = q - b;
    if (p.y < -0.08 * h || p.y > h * 1.03 || abs(p.x) > w * 1.7)
        return f;
    float t = p.y / h;
    float x = p.x - (hash(vec2(seed, 1.0)) - 0.5) * 0.12 * WILD * p.y;
    float sx = SUN.x > b.x ? 1.0 : -1.0;
    float sideW = w * mix(1.0, x * sx > 0.0 ? mix(0.9, 1.15, hash(vec2(seed, 2.0))) : mix(0.8, 1.05, hash(vec2(seed, 3.0))), WILD);
    float n = mix(7.0, floor(mix(4.0, 7.0, hash(vec2(seed, 4.0)))), WILD);
    float env = max(1.0 - t, 0.0);
    float rel = clamp(abs(x) / max(sideW * env, 1e-4), 0.0, 1.6);
    float s = (t - 0.05) / 0.95 * n + mix(0.3, 0.55, WILD) * rel * rel + 0.3 * WILD * (vnoise(vec2(x / w * 6.0, seed * 3.1)) - 0.5);
    float fr = fract(s);
    float k = floor(s);
    float wd = sideW * env * mix(0.55 + 0.6 * pow(1.0 - fr, 0.8), 0.4 + 0.85 * pow(1.0 - fr, 0.8), WILD);
    // Needle tips fray the edge.
    wd *= 1.0 + mix(0.1, 0.2, WILD) * (vnoise(vec2(t * n * 7.0, seed + step(0.0, x) * 7.0)) - 0.5);
    float hem = s * 0.95 * h / n;
    f.cov = fill(abs(x) - wd) * fill(-hem) * fill(p.y - h);
    f.trunk = fill(abs(x) - w * 0.07) * fill(-p.y - 0.05 * h) * fill(p.y - 0.12 * h) * (1.0 - f.cov);
    // Snow along the upper part of each tier, its lower edge lumpy.
    float lo = mix(0.82, 0.5, snowiness) + 0.18 * (vnoise(vec2(x / w * 9.0, seed + k * 3.0)) - 0.5);
    float hi = 0.9 + 0.06 * vnoise(vec2(x / w * 5.0, seed + k));
    f.snow = band(fr, lo) * (1.0 - band(fr, hi));
    f.snow = max(f.snow, fill((1.0 - t) - 0.05) * step(0.3, snowiness));
    f.lit = smoothstep(-PX, PX, x * sx + 0.12 * wd);
    float rimW = max(PX * 1.5, 0.07 * w);
    f.rim = (1.0 - fill(abs(x) - (wd - rimW))) * step(0.0, x * sx);
    return f;
}

vec3 firColor(Fir f, vec3 nShade, vec3 nLit, vec3 sShade, vec3 sLit, vec3 rim) {
    vec3 c = mix(nShade, nLit, f.lit);
    c = mix(c, mix(sShade, sLit, f.lit), f.snow);
    return mix(c, rim, f.rim * mix(0.6, 1.0, f.snow));
}

// A stand of firs along a bank, x0..x1: the far ones first, smaller and set back.
vec3 stand(vec3 col, vec2 q, int bank, float cell, float hMin, float hMax, float seed, float x0, float x1,
           vec3 nShade, vec3 nLit, vec3 sShade, vec3 sLit, vec3 rim, vec3 trunk) {
    float g = floor(q.x / cell);
    for (int pass = 0; pass < 2; pass++) {
        for (int k = -3; k <= 3; k++) {
            float c = g + float(k);
            float h0 = hash(vec2(c, seed)), h1 = hash(vec2(c, seed + 1.0));
            float h2 = hash(vec2(c, seed + 2.0)), h3 = hash(vec2(c, seed + 3.0));
            if ((h3 < 0.45) != (pass == 0) || hash(vec2(c, seed + 5.0)) < 0.12)
                continue;
            float cx = (c + 0.1 + 0.8 * h0) * cell;
            if (cx < x0 || cx > x1)
                continue;
            if (vnoise(vec2(cx * 3.0, seed)) < 0.22)
                continue;
            float h = mix(hMin, hMax, h1 * h1) * (pass == 0 ? 0.8 : 1.0) * (bank == 1 ? mix(1.0, 0.35, smoothstep(0.0, 0.6, cx)) : 1.0);
            float w = h * mix(0.24, 0.34, h2);
            if (abs(q.x - cx) > w * 1.7)
                continue;
            vec2 b = vec2(cx, bankY(bank, cx) + (pass == 0 ? 0.2 : -0.05) * h);
            Fir f = fir(q, b, h, w, c + seed, 0.7);
            col = mix(col, trunk, f.trunk);
            col = mix(col, firColor(f, nShade, nLit, sShade, sLit, rim), f.cov);
        }
    }
    return col;
}

// Coverage of the firs of a stand, for their reflection in the ice.
float standShape(vec2 q, int bank, float cell, float hMin, float hMax, float seed, float x0, float x1) {
    float g = floor(q.x / cell);
    float cov = 0.0;
    for (int pass = 0; pass < 2; pass++) {
        for (int k = -3; k <= 3; k++) {
            float c = g + float(k);
            float h0 = hash(vec2(c, seed)), h1 = hash(vec2(c, seed + 1.0));
            float h2 = hash(vec2(c, seed + 2.0)), h3 = hash(vec2(c, seed + 3.0));
            if ((h3 < 0.45) != (pass == 0) || hash(vec2(c, seed + 5.0)) < 0.12)
                continue;
            float cx = (c + 0.1 + 0.8 * h0) * cell;
            if (cx < x0 || cx > x1)
                continue;
            if (vnoise(vec2(cx * 3.0, seed)) < 0.22)
                continue;
            float h = mix(hMin, hMax, h1 * h1) * (pass == 0 ? 0.8 : 1.0) * (bank == 1 ? mix(1.0, 0.35, smoothstep(0.0, 0.6, cx)) : 1.0);
            float w = h * mix(0.24, 0.34, h2);
            if (abs(q.x - cx) > w * 1.7)
                continue;
            vec2 b = vec2(cx, bankY(bank, cx) + (pass == 0 ? 0.2 : -0.05) * h);
            cov = max(cov, fir(q, b, h, w, c + seed, 0.7).cov);
        }
    }
    return cov;
}

// A five-pointed star of radius r, its points rf deep, as a signed distance.
float star5(vec2 p, float r, float rf) {
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

// The island's tree.
const vec2 ISLE = vec2(0.84, 0.232);    // the island's middle on the ice
const float TREE_H = 0.31, TREE_W = 0.105;
vec2 treeFoot() {
    return ISLE + vec2(0.004, 0.022);
}

// One of the tree's light bulbs: where string j's bulb i hangs, its color, and
// whether there is one.
vec3 bulbColor(float i, float j) {
    float hh = hash(vec2(i, j + 40.0));
    return hh < 0.34 ? rgb(244, 200, 104) : hh < 0.62 ? rgb(248, 232, 214) : hh < 0.88 ? rgb(228, 78, 84) : rgb(246, 156, 108);
}

// The Christmas tree: a full fir hung with strings of lights and baubles, a gold
// star on top. Mirrored (refl) it is drawn dim, its lights stretched into streaks.
vec3 xmasTree(vec3 col, vec2 q, bool refl) {
    vec2 b = treeFoot();
    float h = TREE_H, w = TREE_W;
    vec2 p = q - b;
    if (abs(p.x) > w * 1.8 || p.y < -0.06 * h || p.y > h + 0.06)
        return col;
    Fir f = fir(q, b, h, w, 7.0, 0.25);
    vec3 needles = firColor(f, rgb(26, 60, 56), rgb(50, 98, 76), rgb(150, 156, 196), rgb(240, 222, 220), rgb(255, 214, 160));
    if (refl) {
        col = mix(col, mix(col, rgb(36, 48, 70), 0.4), max(f.cov, f.trunk) * band(vnoise(vec2(q.x * 6.0, q.y * 140.0)), 0.25));
    } else {
        col = mix(col, rgb(70, 46, 46), f.trunk);
        col = mix(col, needles, f.cov);
    }
    // Strings of lights, each sagging across the front of the tree a little higher
    // to the right, as they spiral round it.
    float t = p.y / h;
    vec3 glowCol = vec3(0.0);
    float glowA = 0.0;
    for (int j = 0; j < 6; j++) {
        float fj = float(j);
        float tl = 0.15 + 0.13 * fj, tr = tl + 0.07;
        if (t < tl - 0.12 || t > tr + 0.05)
            continue;
        float xl = -w * (1.0 - tl) * 0.95, xr = w * (1.0 - tr) * 0.95;
        float uu = (p.x - xl) / (xr - xl);
        if (uu < -0.05 || uu > 1.05)
            continue;
        float sag = 0.05 * h * (1.0 - 0.5 * fj / 5.0);
        float ys = mix(tl, tr, uu) * h - sag * 4.0 * uu * (1.0 - uu);
        if (!refl)
            col = mix(col, rgb(64, 52, 40), fill(abs(p.y - ys) - PX * 0.6) * f.cov * step(0.0, uu) * step(uu, 1.0));
        float count = floor((xr - xl) / 0.0105);
        float ii = clamp(floor(uu * count), 0.0, count - 1.0);
        for (int m = -1; m <= 1; m++) {
            float bi = ii + float(m);
            if (bi < 0.0 || bi > count - 1.0)
                continue;
            float bu = (bi + 0.5 + 0.3 * (hash(vec2(bi, fj)) - 0.5)) / count;
            vec2 bc = vec2(mix(xl, xr, bu), mix(tl, tr, bu) * h - sag * 4.0 * bu * (1.0 - bu) - 0.0025);
            vec3 bcol = bulbColor(bi, fj);
            vec2 d = p - bc;
            if (refl) {
                float streak = fill(length(d * vec2(1.0, 0.3)) - 0.0022);
                col = mix(col, mix(col, bcol, 0.35), streak);
            } else {
                float r = length(d);
                float ring = fill(r - 0.0075);
                col = mix(col, mix(col, bcol, 0.22), ring);
                col = mix(col, mix(bcol, rgb(255, 246, 228), 0.25), fill(r - 0.0026));
            }
        }
    }
    // Baubles hanging among the boughs, cranberry and gold, each with a glint.
    if (!refl) {
        for (int i = 0; i < 22; i++) {
            float fi = float(i);
            vec2 hh = hash2(vec2(fi, 71.0));
            float bt = mix(0.1, 0.78, hh.y);
            vec2 bc = vec2((hh.x - 0.5) * 2.0 * 0.62 * w * (1.0 - bt), bt * h);
            float r = mix(0.0055, 0.0078, hash(vec2(fi, 72.0))) * mix(1.0, 0.75, bt);
            vec2 d = p - bc;
            if (dot(d, d) > 0.0004)
                continue;
            bool red = hash(vec2(fi, 73.0)) < 0.55;
            vec3 base = red ? rgb(204, 52, 66) : rgb(226, 170, 82);
            vec3 shade = red ? rgb(132, 30, 52) : rgb(160, 104, 56);
            float ball = fill(length(d) - r);
            vec3 bcol = mix(base, shade, fill(length(d - vec2(-0.35, 0.35) * r) - r * 1.05) < 0.5 ? 1.0 : 0.0);
            bcol = mix(bcol, rgb(242, 238, 228), fill(length(d - vec2(-0.35, 0.35) * r) - r * 0.28));
            col = mix(col, bcol, ball);
            col = mix(col, rgb(214, 170, 96), fill(abs(d.x) - r * 0.3) * fill(abs(d.y - r * 1.05) - r * 0.18));
        }
    }
    // The star, its points split into lit and shaded halves, in rings of light.
    vec2 sc = vec2(0.0, h + 0.012);
    vec2 sp = p - sc;
    float sd = star5(sp, 0.026, 0.45);
    if (refl) {
        col = mix(col, mix(col, rgb(250, 210, 120), 0.6), fill(length(sp * vec2(1.0, 0.35)) - 0.006));
    } else {
        float a = atan(sp.x, sp.y) / (TAU / 5.0);
        float half_ = fract(a + 0.5) - 0.5;
        vec3 sc2 = half_ > 0.0 ? rgb(255, 226, 150) : rgb(226, 158, 72);
        col = mix(col, sc2, fill(sd));
    }
    return col;
}

// How much of the island's snow covers p, and where its top is.
float isleTop(float x) {
    float dx = (x - ISLE.x) / 0.115;
    return ISLE.y + 0.026 * pow(max(0.0, 1.0 - dx * dx), 0.6) * (0.8 + 0.2 * billows(x, 30.0, 9.0));
}

// A lantern on a post at foot b, the post s tall: a glass box glowing warm under
// a pointed cap, lighting the air round it.
vec3 lantern(vec3 col, vec2 q, vec2 b, float s) {
    vec2 p = (q - b) / s;
    if (abs(p.x) > 1.2 || p.y < -0.2 || p.y > 2.0)
        return col;
    float e = PX / s;
    vec2 lc = vec2(0.0, 1.12);
    float r = length((p - lc) * vec2(1.0, 0.9));
    col = mix(col, mix(col, rgb(255, 210, 140), 0.1), smoothstep(e, -e, r - 0.5));
    col = mix(col, mix(col, rgb(255, 220, 156), 0.16), smoothstep(e, -e, r - 0.3));
    vec3 wood = rgb(44, 30, 40);
    float post = smoothstep(e, -e, abs(p.x) - 0.035) * smoothstep(-e, e, p.y) * smoothstep(e, -e, p.y - 0.96);
    col = mix(col, wood, post);
    float glass = smoothstep(e, -e, abs(p.x - lc.x) - 0.1) * smoothstep(e, -e, abs(p.y - lc.y) - 0.14);
    float frame = smoothstep(e, -e, abs(p.x - lc.x) - 0.13) * smoothstep(e, -e, abs(p.y - lc.y) - 0.17);
    col = mix(col, wood, frame);
    col = mix(col, rgb(255, 214, 140), glass);
    col = mix(col, rgb(255, 244, 214), glass * smoothstep(e, -e, length(p - lc) - 0.05));
    float capY = p.y - 1.29;
    float cap = smoothstep(e, -e, abs(p.x) - 0.17 * (1.0 - capY / 0.14)) * smoothstep(-e, e, capY) * smoothstep(e, -e, capY - 0.14);
    col = mix(col, wood, cap);
    col = mix(col, rgb(236, 224, 236), cap * smoothstep(-e, e, capY - 0.06));
    return col;
}

// The cabin: log walls, its gable end facing the sun, a roof heavy with snow, a
// stone chimney, warm windows, a wreath on the door, and lights along the eaves.
const vec2 CABIN = vec2(1.545, 0.258);
vec3 cabin(vec3 col, vec2 q) {
    vec2 p = q - CABIN;
    if (p.x < -0.075 || p.x > 0.15 || p.y < -0.02 || p.y > 0.13)
        return col;
    float gw = 0.058, fw = 0.125, wh = 0.058, rh = 0.036;
    // Gable end: logs, lit by the afterglow, under a peak.
    float gx = p.x + gw;
    float peak = wh + rh * (1.0 - abs(gx - gw * 0.5) / (gw * 0.5));
    float gable = fill(-gx) * fill(gx - gw) * fill(-p.y) * fill(p.y - peak);
    float log1 = fract(p.y / 0.0078);
    vec3 gc = mix(rgb(170, 104, 80), rgb(120, 70, 62), band(log1, 0.8));
    gc = mix(gc, rgb(150, 92, 76), step(wh, p.y));
    col = mix(col, gc, gable);
    // A small lit window in the gable.
    float gwin = fill(abs(gx - gw * 0.5) - 0.007) * fill(abs(p.y - wh - 0.011) - 0.007);
    col = mix(col, rgb(255, 204, 120), gwin);
    // Front wall.
    float front = fill(-p.x) * fill(p.x - fw) * fill(-p.y) * fill(p.y - wh);
    vec3 fc = mix(rgb(120, 72, 64), rgb(86, 50, 54), band(log1, 0.8));
    col = mix(col, fc, front);
    // Log ends at the corner.
    vec2 le = vec2(p.x, (fract(p.y / 0.0078) - 0.5) * 0.0078);
    col = mix(col, rgb(196, 140, 104), fill(length(le) - 0.0033) * fill(p.y - wh) * fill(-p.y));
    col = mix(col, rgb(140, 92, 76), fill(length(le) - 0.0015) * fill(p.y - wh) * fill(-p.y));
    // Windows, warm with a cross of mullions and snow on their sills.
    for (int i = 0; i < 2; i++) {
        float wx = i == 0 ? 0.027 : 0.098;
        vec2 wp = p - vec2(wx, 0.032);
        float win = fill(abs(wp.x) - 0.011) * fill(abs(wp.y) - 0.01);
        col = mix(col, rgb(70, 40, 44), fill(abs(wp.x) - 0.013) * fill(abs(wp.y) - 0.012));
        col = mix(col, mix(rgb(255, 200, 112), rgb(255, 232, 170), fill(length(wp) - 0.007)), win);
        col = mix(col, rgb(70, 40, 44), win * max(fill(abs(wp.x) - 0.0009), fill(abs(wp.y) - 0.0009)));
        col = mix(col, rgb(232, 222, 236), fill(abs(wp.x) - 0.015) * fill(abs(wp.y + 0.013) - 0.0022));
    }
    // The door, and its wreath with a red bow.
    vec2 dp = p - vec2(0.0625, 0.0);
    float door = fill(abs(dp.x) - 0.012) * fill(-dp.y) * fill(dp.y - 0.044);
    col = mix(col, rgb(70, 40, 44), fill(abs(dp.x) - 0.0135) * fill(-dp.y) * fill(dp.y - 0.0455));
    col = mix(col, mix(rgb(118, 66, 52), rgb(100, 56, 48), step(0.5, fract(dp.x / 0.008))), door);
    vec2 wr = dp - vec2(0.0, 0.03);
    float ring = fill(abs(length(wr) - 0.0058) - 0.0027);
    float leafy = vnoise(vec2(atan(wr.y, wr.x) * 4.0, 2.0));
    col = mix(col, mix(rgb(44, 92, 62), rgb(92, 146, 88), step(0.5, leafy)), ring);
    for (int i = 0; i < 6; i++) {
        float a = float(i) * 1.047 + 0.4;
        col = mix(col, rgb(226, 70, 76), fill(length(wr - 0.0058 * vec2(cos(a), sin(a))) - 0.0011));
    }
    vec2 bw = wr - vec2(0.0, -0.006);
    float bow = fill(length(vec2(abs(bw.x) - 0.0035, bw.y) * vec2(1.0, 1.6)) - 0.0028);
    bow = max(bow, fill(abs(bw.x + 0.0022 * sign(bw.x) - bw.x * 0.0) - 0.0012) * fill(abs(bw.y + 0.0055) - 0.004) * step(abs(bw.x), 0.004));
    col = mix(col, rgb(214, 56, 70), bow);
    // Snow on the roof: the front slope from the eave up to the ridge, its edge
    // overhanging, and a ledge of snow along the gable's edges.
    float ry = (p.y - wh) / rh;
    float shift = (p.y - wh) / rh * gw * 0.5;
    float rx = p.x + shift;
    float roof = fill(wh - 0.004 - p.y) * fill(p.y - wh - rh - 0.003) * fill(-(rx + 0.005)) * fill(rx - fw - 0.006);
    vec3 rc = mix(rgb(178, 170, 210), rgb(236, 222, 234), smoothstep(0.0, 1.0, ry));
    rc = mix(rc, rgb(204, 194, 222), band(vnoise(vec2(p.x * 60.0, ry * 3.0)), 0.7));
    col = mix(col, rc, roof);
    // The overhanging edge along the eave, lit along its lip.
    float lip = fill(abs(p.y - wh + 0.001) - 0.0035) * fill(-(p.x + 0.007)) * fill(p.x - fw - 0.006);
    col = mix(col, rgb(228, 216, 232), lip);
    // Barge edges of the gable.
    float dEdge = abs(p.y - peak) ;
    float barge = fill(dEdge - 0.003) * fill(-(gx + 0.004)) * fill(gx - gw - 0.002) * step(wh - 0.002, p.y);
    col = mix(col, rgb(250, 226, 212), barge);
    // The chimney, stone with a cap of snow.
    vec2 cp = p - vec2(0.088, 0.0);
    float chim = fill(abs(cp.x - 0.0) - 0.008) * fill(-(cp.y - wh - rh * 0.5)) * fill(cp.y - 0.112);
    vec3 stone = mix(rgb(118, 94, 104), rgb(88, 70, 86), step(0.0, cp.x + 0.002));
    stone = mix(stone, rgb(70, 54, 70), band(fract(cp.y / 0.007 + step(0.5, fract(cp.x / 0.008 + floor(cp.y / 0.007) * 0.5)) * 0.0), 0.86));
    col = mix(col, stone, chim);
    col = mix(col, rgb(234, 222, 234), fill(abs(cp.x) - 0.0095) * fill(abs(cp.y - 0.112) - 0.003));
    // Lights strung along the eave, sagging between the nails.
    float span = 0.021;
    float ex = p.x + 0.004;
    float si = floor(ex / span);
    float fu = fract(ex / span);
    float wy = wh - 0.006 - 0.005 * 4.0 * fu * (1.0 - fu);
    float onEave = step(0.0, ex) * step(ex, fw + 0.004);
    col = mix(col, rgb(40, 30, 36), fill(abs(p.y - wy) - PX * 0.7) * onEave);
    for (int m = -1; m <= 1; m++) {
        float bi = floor(ex / 0.0068) + float(m);
        float bx = (bi + 0.5) * 0.0068;
        if (bx < 0.0 || bx > fw + 0.004)
            continue;
        float bf = fract(bx / span);
        vec2 bc = vec2(bx - 0.004, wh - 0.006 - 0.005 * 4.0 * bf * (1.0 - bf) - 0.002);
        float hh = hash(vec2(bi, 5.0));
        vec3 bcol = hh < 0.3 ? rgb(228, 78, 84) : hh < 0.55 ? rgb(244, 200, 104) : hh < 0.8 ? rgb(134, 196, 120) : rgb(130, 176, 232);
        float r = length(p - bc);
        col = mix(col, mix(col, bcol, 0.25), fill(r - 0.005));
        col = mix(col, mix(bcol, rgb(255, 246, 230), 0.2), fill(r - 0.0019));
    }
    return col;
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    PX = 1.0 / u.resolution.y;
    ASPECT = u.resolution.x / u.resolution.y;
    SUN = vec2(ASPECT * 0.62, 0.448);
    float ds = length((q - SUN) * vec2(1.0, 1.3));

    // ── Sky: flat dusk bands bowing up round the sunset, stars overhead ──
    float t = clamp((q.y - SHORE) / (1.0 - SHORE), 0.0, 1.0);
    t = pow(t, 0.8) - 0.13 * exp(-ds * 2.4) + (fbm(vec2(q.x * 1.1, q.y * 3.5)) - 0.5) * 0.045;
    vec3 col = sky(steps(clamp(t, 0.0, 1.0), 13.0));
    float stars = max(starField(q, 0.014, 0.3, 1.0, 0.0012, PX * 1.2, PX), starField(q + 0.37, 0.034, 0.4, 7.0, 0.002, PX * 1.2, PX));
    col = mix(col, rgb(242, 236, 226), stars * smoothstep(0.66, 0.9, q.y));
    // Long streaks of cloud, violet, their undersides lit by the sunset.
    float env = smoothstep(0.58, 0.66, q.y) * (1.0 - smoothstep(0.8, 0.88, q.y));
    float n = fbm(vec2(q.x * 1.3, q.y * 14.0) + vec2(7.0, 2.0)) + 0.25 * vnoise(vec2(q.x * 6.0, q.y * 40.0));
    float nLow = fbm(vec2(q.x * 1.3, (q.y + 0.008) * 14.0) + vec2(7.0, 2.0)) + 0.25 * vnoise(vec2(q.x * 6.0, (q.y + 0.008) * 40.0));
    float streak = band(n * env, 0.58);
    float warm = exp(-abs(q.x - SUN.x) * 1.2);
    col = mix(col, mix(rgb(112, 80, 136), rgb(156, 96, 140), warm), streak);
    col = mix(col, mix(rgb(208, 128, 146), rgb(250, 178, 146), warm), streak * (1.0 - band(nLow * env, 0.58)));
    // The sun, just set, in rings of afterglow.
    col = mix(col, mix(col, rgb(255, 222, 168), 0.12), cover(0.17 - ds));
    col = mix(col, mix(col, rgb(255, 230, 182), 0.22), cover(0.13 - ds));
    col = mix(col, rgb(255, 236, 196), cover(0.056 - ds));

    // ── Far hills under snow, warmest toward the afterglow, with
    //    forests of tiny firs on them ──
    float hF = 0.43 + 0.04 * vnoise5(vec2(q.x * 1.7, 1.0)) + 0.016 * vnoise5(vec2(q.x * 5.0, 2.0));
    float glowX = exp(-abs(q.x - SUN.x) * 1.6);
    vec3 hillC = mix(rgb(204, 152, 174), rgb(242, 188, 172), step(0.45, glowX));
    col = mix(col, hillC, below(hF, q.y));
    col = mix(col, mix(rgb(236, 180, 178), rgb(255, 222, 186), step(0.45, glowX)), below(hF, q.y) * (1.0 - below(hF - 0.003, q.y)));
    {
        float cell = 0.006;
        float g = floor(q.x / cell);
        float top = 0.0;
        for (int k = -2; k <= 2; k++) {
            float c = g + float(k);
            float cx = (c + 0.5 + 0.6 * (hash(vec2(c, 61.0)) - 0.5)) * cell;
            float dens = fbm(vec2(cx * 4.0, 3.0));
            if (dens < 0.5 || hash(vec2(c, 62.0)) < 0.2)
                continue;
            float hb = 0.43 + 0.04 * vnoise5(vec2(cx * 1.7, 1.0)) + 0.016 * vnoise5(vec2(cx * 5.0, 2.0)) - 0.012 - 0.03 * hash(vec2(c, 64.0)) * dens;
            float th = mix(0.008, 0.016, hash(vec2(c, 63.0)));
            float tw = th * 0.3;
            top = max(top, below(hb + th * (1.0 - abs(q.x - cx) / tw), q.y) * cover(q.y - hb + 0.02));
        }
        col = mix(col, rgb(122, 98, 140), top);
    }

    // ── The far shore: a band of forest along the water ──
    vec3 fN = rgb(40, 46, 78), fNL = rgb(72, 66, 100), fS = rgb(146, 132, 178), fSL = rgb(232, 186, 186), fR = rgb(255, 212, 170);
    col = mix(col, rgb(206, 170, 196), below(farBank(q.x) + 0.002, q.y));
    col = stand(col, q, 0, 0.009, 0.018, 0.062, 11.0, -1.0, 9.0, fN, fNL, fS, fSL, fR, rgb(60, 50, 80));

    // ── The ice: flat bands mirroring the dusk, dusted with drifts of snow, with
    //    the shore, the tree and its glow mirrored in it, and skate trails ──
    if (q.y < SHORE + 0.004) {
        float Z = 1.0 / max(HZ - q.y, 1e-3);
        float X = (q.x - ASPECT * 0.5) * Z;
        float depth = clamp((SHORE - q.y) / (SHORE - 0.06), 0.0, 1.0);
        // The sky mirrored, in fewer and broader bands than the sky itself.
        float mt = clamp(pow(depth, 0.7) * 0.95 + 0.04 - 0.1 * exp(-abs(q.x - SUN.x) * 2.5) * (1.0 - depth), 0.0, 1.0);
        vec3 ice = mix(sky(steps(mt, 9.0)), rgb(150, 150, 198), 0.3);
        // Polished streaks running across it.
        float polish = band(vnoise(vec2(X * 0.25, Z * 0.9)), 0.62);
        ice = mix(ice, mix(ice, rgb(255, 236, 220), 0.12), polish);
        // The far shore's forest mirrored, faint and broken by the bands.
        vec2 m = vec2(q.x, 2.0 * SHORE - q.y);
        float sh = standShape(m, 0, 0.009, 0.018, 0.062, 11.0, -1.0, 9.0);
        ice = mix(ice, mix(ice, rgb(70, 64, 108), 0.35), sh * (1.0 - polish) * band(vnoise(vec2(q.x * 6.0, q.y * 110.0)), 0.3));
        // The tree's glow running down the ice toward us.
        float gx = abs(q.x - ISLE.x);
        float column = (1.0 - smoothstep(0.0, 0.07, gx - 0.0)) * smoothstep(0.02, ISLE.y, q.y) * step(q.y, ISLE.y);
        float dash = band(vnoise(vec2(q.x * 30.0, Z * 9.0)), 0.45);
        ice = mix(ice, mix(ice, rgb(255, 196, 132), 0.3), step(0.3, column) * dash);
        ice = mix(ice, mix(ice, rgb(255, 214, 150), 0.45), step(0.7, column) * dash);
        // Drifts of snow lying on the ice, swept long by the wind.
        float drift = fbm(vec2(X * 0.45, Z * 1.6) + vec2(3.0, 1.0)) + 0.18 * smoothstep(0.1, 0.0, depth) - 0.1;
        vec3 snowOn = mix(rgb(196, 182, 214), rgb(242, 220, 222), 1.0 - depth);
        ice = mix(ice, snowOn, band(drift, 0.58));
        ice = mix(ice, mix(snowOn, rgb(255, 232, 214), 0.5), band(drift, 0.66));
        // Skate trails: loops round the island and long curves out from the landing.
        vec2 g = vec2(X, Z);
        vec2 isleG = vec2((ISLE.x - ASPECT * 0.5) / (HZ - ISLE.y), 1.0 / (HZ - ISLE.y));
        float trail = 0.0;
        for (int i = 0; i < 5; i++) {
            float fi = float(i);
            vec2 c = isleG + vec2(0.25 * fi - 0.2, 0.3 - 0.25 * fi);
            vec2 r = vec2(1.6 + 0.35 * hash(vec2(fi, 3.0)), 1.3 + 0.4 * hash(vec2(fi, 4.0)));
            if (i == 4) { c = vec2(1.2, 3.6); r = vec2(1.1, 0.5); }
            vec2 dd = g - c;
            float a = 0.3 * (hash(vec2(fi, 5.0)) - 0.5);
            dd = rot(dd, a);
            float ff = length(dd / r) - 1.0;
            float gr = length(vec2(dFdx(ff), dFdy(ff))) * u.resolution.y;
            float dq = abs(ff) / max(gr, 1e-4);
            float ang = atan(dd.y / r.y, dd.x / r.x);
            float broken = step(0.33, vnoise(vec2(ang * 3.0 + fi * 7.0, fi)));
            trail = max(trail, fill(dq - PX * mix(0.5, 1.0, depth)) * broken);
        }
        ice = mix(ice, rgb(246, 232, 236), trail * 0.65);
        col = mix(col, ice, fill(q.y - SHORE));
        // The island and its tree mirrored.
        vec2 mi = vec2(q.x, 2.0 * ISLE.y - q.y);
        col = mix(col, mix(col, rgb(206, 186, 214), 0.5), fill(mi.y - isleTop(q.x)) * step(q.y, ISLE.y));
        if (q.y < ISLE.y)
{
            WILD = 0.0;
            col = xmasTree(col, vec2(q.x, 2.0 * ISLE.y - q.y), true);
            WILD = 1.0;
        }
    }

    // ── The island: a mound of snow, a couple of wild firs, and the tree in its glow ──
    {
        vec2 tc = treeFoot() + vec2(0.0, TREE_H * 0.45);
        float gr = length((q - tc) * vec2(1.25, 0.8));
        col = mix(col, mix(col, rgb(255, 210, 156), 0.07), cover(0.2 - gr));
        float st = length(q - treeFoot() - vec2(0.0, TREE_H + 0.012));
        col = mix(col, mix(col, rgb(255, 226, 160), 0.14), cover(0.052 - st));
        col = mix(col, mix(col, rgb(255, 232, 176), 0.2), cover(0.034 - st));
        float top = isleTop(q.x);
        float isle = fill(q.y - top) * step(ISLE.y - 0.004, q.y);
        vec3 ic = mix(rgb(176, 166, 206), rgb(238, 222, 228), smoothstep(ISLE.y, top, q.y) > 0.4 ? 1.0 : 0.0);
        ic = mix(ic, rgb(255, 222, 180), fill(length((q - treeFoot()) * vec2(1.0, 3.0)) - 0.05));
        col = mix(col, ic, isle);
        Fir w1 = fir(q, vec2(ISLE.x - 0.075, isleTop(ISLE.x - 0.075) - 0.003), 0.055, 0.016, 21.0, 0.7);
        col = mix(col, firColor(w1, rgb(28, 50, 56), rgb(52, 76, 76), rgb(160, 156, 196), rgb(240, 214, 214), rgb(255, 210, 166)), w1.cov);
        Fir w2 = fir(q, vec2(ISLE.x + 0.085, isleTop(ISLE.x + 0.085) - 0.003), 0.038, 0.012, 22.0, 0.7);
        col = mix(col, firColor(w2, rgb(28, 50, 56), rgb(52, 76, 76), rgb(160, 156, 196), rgb(240, 214, 214), rgb(255, 210, 166)), w2.cov);
        WILD = 0.0;
        col = xmasTree(col, q, false);
        WILD = 1.0;
    }

    // ── The left shore: a bank of snow under a stand of firs ──
    if (q.x < 0.75) {
        float lb = leftBank(q.x);
        float land = below(lb, q.y) * fill(leftShore(q.x) - q.y);
        col = mix(col, rgb(150, 146, 190), land);
        col = mix(col, rgb(236, 206, 210), land * (1.0 - below(lb - 0.005, q.y)));
        col = stand(col, q, 1, 0.012, 0.07, 0.15, 31.0, -1.0, 0.6,
                    rgb(30, 46, 58), rgb(54, 70, 78), rgb(150, 148, 192), rgb(240, 212, 214), rgb(255, 206, 164), rgb(50, 40, 56));
    }

    // ── The knoll: firs behind the cabin, the cabin, its smoke ──
    if (q.x > 1.35) {
        for (int i = 0; i < 5; i++) {
            float fi = float(i);
            float x = i == 0 ? 1.49 : i == 1 ? 1.63 : i == 2 ? 1.71 : i == 3 ? 1.77 : 1.42;
            float h = i == 0 ? 0.13 : i == 1 ? 0.21 : i == 2 ? 0.17 : i == 3 ? 0.27 : 0.08;
            Fir f = fir(q, vec2(x, nearBank(x) + 0.004), h, h * 0.3, 41.0 + fi, 0.7);
            col = mix(col, rgb(46, 34, 44), f.trunk);
            col = mix(col, firColor(f, rgb(24, 40, 50), rgb(46, 64, 70), rgb(144, 142, 188), rgb(236, 210, 214), rgb(255, 204, 160)), f.cov);
        }
    }

    // ── The near bank, rising on the right into the knoll ──
    float nb = nearBank(q.x);
    float bankIn = below(nb, q.y);
    vec3 bc = rgb(176, 170, 214);
    float lump = nb - 0.03 - 0.03 * billows(q.x + 2.0, 6.0, 17.0);
    bc = mix(bc, rgb(140, 138, 192), below(lump, q.y));
    bc = mix(bc, rgb(118, 118, 176), below(lump - 0.05 - 0.02 * billows(q.x, 4.0, 19.0), q.y));
    bc = mix(bc, rgb(242, 220, 222), 1.0 - below(nb - 0.007, q.y));
    col = mix(col, bc, bankIn);

    // The path from the door down along the shore to the ice, and its lanterns.
    {
        float pw = mix(0.006, 0.011, smoothstep(1.6, 1.05, q.x));
        float py = nearBank(q.x) - mix(0.006, 0.02, smoothstep(1.6, 1.05, q.x));
        float path = fill(abs(q.y - py) - pw) * step(1.06, q.x) * step(q.x, 1.6);
        col = mix(col, rgb(196, 180, 214), path);
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float x = 1.46 - 0.115 * fi;
            float s = mix(0.034, 0.052, fi / 3.0);
            vec2 foot = vec2(x, nearBank(x) - mix(0.006, 0.02, smoothstep(1.6, 1.05, x)) + mix(0.006, 0.011, smoothstep(1.6, 1.05, x)) * 0.9);
            float pool = length((q - foot) * vec2(1.0, 3.2));
            col = mix(col, mix(col, rgb(255, 210, 160), 0.3), fill(pool - s * 0.9) * bankIn);
            col = mix(col, mix(col, rgb(255, 222, 176), 0.4), fill(pool - s * 0.5) * bankIn);
            col = lantern(col, q, foot, s);
        }
    }

    // The cabin, its smoke curling up and away to the left, thinning as it goes.
    {
        vec2 ch = CABIN + vec2(0.088, 0.115);
        float sm = 1e3, smLit = 1e3;
        float alpha = 0.0;
        for (int i = 0; i < 26; i++) {
            float fi = float(i);
            float k = fi / 25.0;
            vec2 c = ch + vec2(-0.15 * k * k - 0.008 * sin(fi * 0.9), 0.2 * k + 0.004 * sin(fi * 1.3));
            float r = 0.005 + 0.014 * k + 0.004 * k * hash(vec2(fi, 9.0));
            // The top of the plume breaks into separate wisps.
            if (k > 0.75 && hash(vec2(fi, 10.0)) < 0.5)
                continue;
            float d = length(q - c) - r;
            if (d < sm) { sm = d; alpha = k; }
            smLit = min(smLit, length(q - c - vec2(-0.35, 0.2) * r) - r * 0.85);
        }
        alpha = alpha < 0.35 ? 0.8 : alpha < 0.65 ? 0.55 : 0.32;
        vec3 smc = mix(rgb(170, 146, 184), rgb(238, 200, 202), fill(smLit));
        col = mix(col, smc, fill(sm) * alpha);
    }
    col = cabin(col, q);
    // Warm light from the windows and the door on the snow in front.
    {
        vec2 p = q - CABIN;
        float glow = 0.0;
        glow = max(glow, fill(length((p - vec2(0.027, -0.012)) * vec2(1.0, 3.4)) - 0.022));
        glow = max(glow, fill(length((p - vec2(0.098, -0.012)) * vec2(1.0, 3.4)) - 0.022));
        glow = max(glow, fill(length((p - vec2(0.062, -0.008)) * vec2(1.0, 3.4)) - 0.024));
        col = mix(col, mix(col, rgb(255, 204, 150), 0.22), glow * step(p.y, -0.001) * bankIn);
    }

    // ── Firs close by on the left, in the shadow of the evening ──
    for (int i = 0; i < 2; i++) {
        float x = i == 0 ? 0.06 : 0.25;
        float h = i == 0 ? 0.66 : 0.42;
        Fir f = fir(q, vec2(x, nearBank(x) - 0.02), h, h * 0.3, 51.0 + float(i), 0.7);
        col = mix(col, rgb(30, 24, 34), f.trunk);
        col = mix(col, firColor(f, rgb(16, 30, 36), rgb(30, 50, 54), rgb(110, 114, 164), rgb(206, 194, 220), rgb(246, 190, 160)), f.cov);
    }

    // ── Light snow falling: the nearer flakes larger and fainter ──
    for (int i = 0; i < 110; i++) {
        float fi = float(i);
        vec2 h = hash2(vec2(fi, 13.0));
        float near = pow(hash(vec2(fi, 14.0)), 3.0);
        vec2 c = vec2(h.x * ASPECT, mix(0.02, 0.98, h.y));
        float r = mix(0.0011, 0.0045, near);
        col = mix(col, rgb(244, 238, 240), fill(length(q - c) - r) * mix(0.85, 0.5, near));
    }

    fragColor = vec4(col, 1.0);
}
