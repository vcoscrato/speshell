#version 440
#extension GL_GOOGLE_include_directive : enable
// Christmas backdrop, drawn once over a surface's base color: a winter pine night. The top
// is plain night; lower down the sky steps a little lighter toward a far snowfield, where
// small firs stand in stands and gaps. Below where a panel's controls sit, larger firs,
// each its own, carry snow on every tier, lit on the moon's side, and a snow bank with a
// lit rim runs along the bottom; a few still snowflakes hang in the air.
// It stays a few percent off the base so text reads.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 cBase;
    vec4 cDeep;
    vec4 cIce;
    vec4 cSnow;
    vec4 cSnowShade;
    vec4 cGold;
    vec4 cGlow;
    vec4 cBerry;
} u;
#include "../common/common.glsl"

// A fir standing at base, h px tall, laid over o: tiers of drooping boughs, ragged
// with tufts of needles underneath, each carrying a lumpy cap of snow, lit on the left.
// Its slenderness, tiers, widths, lean, and tufts all come from its seed, so no two
// are alike.
vec4 fir(vec4 o, vec2 p, vec2 base, float h, float wide, float seed, vec3 body, vec3 lit, vec3 shade) {
    float v = base.y - p.y;
    float lean = (hash(vec2(seed, 1.0)) - 0.5) * 0.16;
    float x = p.x - base.x - lean * v;
    if (v < -1.0 || v > h + 2.0 || abs(x) > h * 0.45)
        return o;
    float trunk = h * (0.05 + 0.05 * hash(vec2(seed, 2.0)));
    // Broad firs carry fewer, heavier tiers than slender ones.
    float n = floor(mix(9.0, 5.5, wide) + 2.0 * hash(vec2(seed, 3.0)));
    float crown = h - trunk;
    float maxHW = h * mix(0.16, 0.31, wide);
    float tw = mix(2.4, 4.0, hash(vec2(seed, 5.0)));
    float snowy = mix(0.6, 1.2, hash(vec2(seed, 6.0)));

    o = over(o, body, cover(h * 0.022 + 0.4 - abs(x)) * cover(trunk + 2.0 - v) * cover(v + 1.0));
    float f0 = 0.0;
    for (int i = 0; i < 10; i++) {
        float fi = float(i);
        if (fi >= n)
            break;
        float hi = hash(vec2(seed, 10.0 + fi));
        // Tiers closer together toward the top, unevenly.
        float f1 = 1.0 - pow(1.0 - (fi + 1.0) / n, 1.25);
        float vb = trunk + crown * f0;
        float th = crown * (f1 - f0) * mix(1.6, 2.2, hash(vec2(seed, 20.0 + fi)));
        float vt = fi == n - 1.0 ? h : min(vb + th, h);
        float hw = maxHW * pow(1.0 - f0, 0.95) * mix(0.75, 1.2, hash(vec2(seed, 30.0 + fi)));
        hw *= x < 0.0 ? mix(0.62, 1.22, hash(vec2(seed, 40.0 + fi))) : mix(0.62, 1.22, hash(vec2(seed, 50.0 + fi)));
        hw = max(hw, 2.5 + h * 0.012);
        f0 = mix(f0, f1, mix(0.85, 1.15, hi));
        float t = abs(x) / hw;
        if (t >= 1.0)
            continue;
        float drop = (vt - vb) * mix(0.1, 0.28, hi);
        float upper = vt - (vt - vb + drop) * pow(t, 0.8);
        float lower = mix(vb + (vt - vb) * 0.25, vb - drop, pow(t, 1.5));
        // Tufts of needles hanging off the bough's underside, of uneven width.
        float tuft = abs(fract(x / tw + seed * 3.7 + 0.35 * zig(x / (tw * 2.3), seed + fi)) - 0.5) * 2.0;
        lower -= (1.0 + 0.8 * hi) * (1.0 - tuft) * (0.3 + 0.7 * t);
        float inside = min(v - lower, upper - v);
        o = over(o, body, cover(inside));
        // The snow cap: heaped a little above the bough, hanging in lumps below its top,
        // thinning toward the tip, where it has slid off.
        float lump = abs(sin(x / mix(2.2, 3.4, hi) + seed * 5.0 + fi));
        float depth = (vt - vb) * snowy * (0.16 + 0.16 * lump) * (1.0 - 0.6 * t);
        float cap = min(upper + 0.8 - v, v - (upper - depth));
        cap = min(cap, (mix(0.85, 1.0, hash(vec2(seed, 60.0 + fi))) - t) * hw);
        o = over(o, mix(shade, lit, cover(-x - hw * 0.1)), cover(cap));
    }
    return o;
}

// A string of warm lights wound round a fir standing at base, h px tall: swags across
// its front, sloping down to the right, each from near one side's tips to the other's,
// sagging between; bulbs along them, each a bead in rings of its own glow.
vec4 lights(vec4 o, vec2 p, vec2 base, float h, float maxHW) {
    float v = base.y - p.y;
    float x = p.x - base.x;
    if (v < h * 0.12 || v > h * 0.92 || abs(x) > maxHW + 6.0)
        return o;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float va = h * (0.84 - 0.18 * fi);
        float vbt = va - h * 0.09;
        float wa = maxHW * pow(1.0 - va / h, 0.95) * 0.66;
        float wb = maxHW * pow(1.0 - vbt / h, 0.95) * 0.66;
        float t = (x + wa) / (wa + wb);
        if (t < -0.05 || t > 1.05)
            continue;
        float count = floor((wa + wb) / 7.5);
        float k = floor(t * count);
        for (int j = 0; j <= 1; j++) {
            float kj = clamp(k + float(j) - 0.0, 0.0, count - 1.0);
            float tk = (kj + 0.5) / count;
            vec2 c = vec2(mix(-wa, wb, tk), mix(va, vbt, tk) - h * 0.05 * 4.0 * tk * (1.0 - tk));
            float d = length(vec2(x, v) - c);
            float which = mod(kj + fi * 2.0, 3.0);
            vec3 bulb = which < 1.0 ? u.cGlow.rgb : (which < 2.0 ? u.cBerry.rgb : u.cGold.rgb);
            o = over(o, bulb, 0.1 * cover(4.5 - d));
            o = over(o, bulb, 0.18 * cover(2.6 - d));
            o = over(o, mix(bulb, u.cGlow.rgb, 0.5), 0.85 * cover(1.3 - d));
        }
    }
    return o;
}

// A five-pointed star of radius r at c, points up: the signed distance to its edge,
// > 0 outside, from the straight run between a point and the notch beside it.
float starDist(vec2 q, float r) {
    float a = abs(mod(atan(q.x, -q.y) + PI / 5.0, TAU / 5.0) - PI / 5.0);
    vec2 f = length(q) * vec2(sin(a), cos(a));
    vec2 tip = vec2(0.0, r);
    vec2 notch = 0.42 * r * vec2(sin(PI / 5.0), cos(PI / 5.0));
    vec2 e = notch - tip;
    float side = e.x * (f.y - tip.y) - e.y * (f.x - tip.x);
    return sdSeg(f, tip, notch) * sign(side);
}

// A snow bank: > 0 inside, px below its crest. The crest sits near y = top px and
// swells into long, low drifts about `scale` px across, each its own height and lean.
float bank(vec2 p, float top, float scale, float seed) {
    float x = p.x / scale + seed;
    float rise = 0.0;
    for (int i = -1; i <= 1; i++) {
        float c = floor(x) + float(i);
        float hgt = mix(0.25, 1.0, hash(vec2(c, seed)));
        float dx = (x - c - 0.5 - 0.3 * (hash(vec2(seed, c)) - 0.5)) / mix(0.6, 1.0, hash(vec2(c, seed + 2.0)));
        // A drift leans away from the wind, steeper on its right.
        dx *= dx > 0.0 ? 1.25 : 0.85;
        // Joined smoothly, so the hollows between drifts are rounded.
        float r = hgt * max(1.0 - dx * dx, 0.0);
        float k = clamp(0.5 + 0.5 * (r - rise) / 0.25, 0.0, 1.0);
        rise = mix(rise, r, k) + 0.25 * k * (1.0 - k);
    }
    return p.y - (top - scale * 0.32 * rise);
}

void main() {
    vec2 p = qt_TexCoord0 * u.size;
    float W = u.size.x, H = u.size.y;
    float yb = H - p.y;
    vec3 col = u.cBase.rgb;

    // The sky, a little lighter in steps toward the far snowfield.
    float sky = 0.0;
    sky += 0.012 * cover(560.0 - yb + 18.0 * sin(p.x / 230.0 + 1.0) + 9.0 * sin(p.x / 97.0));
    sky += 0.014 * cover(420.0 - yb + 14.0 * sin(p.x / 180.0 + 4.0) + 7.0 * sin(p.x / 71.0 + 2.0));
    sky += 0.016 * cover(300.0 - yb + 10.0 * sin(p.x / 150.0 + 2.0) + 5.0 * sin(p.x / 53.0 + 1.0));
    col = mix(col, u.cIce.rgb, sky);

    if (yb < 340.0) {
        // The far snowfield, in low rolls, with a faint lit edge.
        float ridge = 150.0 + 16.0 * sin(p.x / 210.0 + 0.6) + 8.0 * sin(p.x / 83.0 + 2.0);
        float field = ridge - yb;
        col = mix(col, u.cSnowShade.rgb, 0.07 * cover(field));
        col = mix(col, u.cSnow.rgb, 0.06 * cover(field) * (1.0 - cover(field - 1.5)));

        // Far firs on it, in stands with gaps between, hazy with the distance.
        vec3 farBody = mix(mix(u.cBase.rgb, u.cDeep.rgb, 0.45), u.cIce.rgb, 0.02);
        vec3 farLit = mix(u.cBase.rgb, u.cSnow.rgb, 0.1);
        vec3 farShade = mix(u.cBase.rgb, u.cSnowShade.rgb, 0.06);
        vec4 o = vec4(0.0);
        float S = 34.0;
        float k = floor(p.x / S);
        for (int j = -2; j <= 2; j++) {
            float c = k + float(j);
            if (vnoise(vec2(c * 0.21, 3.0)) < 0.36 || hash(vec2(c, 6.0)) < 0.12)
                continue;
            float x0 = (c + 0.5 + 0.8 * (hash(vec2(c, 7.0)) - 0.5)) * S;
            float g = 150.0 + 16.0 * sin(x0 / 210.0 + 0.6) + 8.0 * sin(x0 / 83.0 + 2.0);
            float h = 34.0 + 50.0 * pow(hash(vec2(c, 8.0)), 1.5);
            o = fir(o, p, vec2(x0, H - g + 3.0), h, hash(vec2(c, 9.0)), c + 100.0, farBody, farLit, farShade);
        }
        col = col * (1.0 - o.a) + o.rgb;

        // Near firs, larger, their bases in the bank, around a gap where the tallest
        // stands hung with lights and a star.
        vec3 nearBody = u.cDeep.rgb;
        vec3 nearLit = mix(u.cBase.rgb, u.cSnow.rgb, 0.2);
        vec3 nearShade = mix(u.cBase.rgb, u.cSnowShade.rgb, 0.1);
        float lx = W * 0.64;
        float lh = 250.0;
        vec2 lBase = vec2(lx, H - 36.0);
        o = fir(vec4(0.0), p, lBase, lh, 0.9, 33.0, nearBody, nearLit, nearShade);
        o = lights(o, p, lBase, lh, lh * mix(0.16, 0.31, 0.9));
        o = over(o, mix(u.cGold.rgb, u.cGlow.rgb, 0.4), 0.08 * cover(13.0 - length(p - lBase + vec2(0.0, lh + 2.0))));
        o = over(o, mix(u.cGold.rgb, u.cGlow.rgb, 0.4), 0.1 * cover(8.0 - length(p - lBase + vec2(0.0, lh + 2.0))));
        float sd = starDist(p - lBase + vec2(0.0, lh + 2.0), 5.5);
        o = over(o, mix(u.cGold.rgb, u.cGlow.rgb, cover(lx - p.x)), cover(-sd));
        S = 100.0;
        k = floor(p.x / S);
        for (int j = -2; j <= 2; j++) {
            float c = k + float(j);
            float x0 = (c + 0.5 + 0.7 * (hash(vec2(c, 12.0)) - 0.5)) * S;
            float grove = vnoise(vec2(c * 0.45, 8.0));
            if (grove < 0.3 || abs(x0 - lx) < 75.0)
                continue;
            float h = mix(80.0, 270.0, pow(hash(vec2(c, 13.0)), 1.2)) * mix(0.6, 1.0, smoothstep(0.3, 0.55, grove));
            o = fir(o, p, vec2(x0, H - 28.0 - 14.0 * hash(vec2(c, 14.0))), h, hash(vec2(c, 15.0)), c + 300.0, nearBody, nearLit, nearShade);
        }
        col = col * (1.0 - o.a) + o.rgb;

        // The snow bank along the bottom: a back bank in shade, and a front one with a
        // lit rim.
        float back = bank(p, H - 64.0, 80.0, 4.0);
        col = mix(col, mix(u.cBase.rgb, u.cSnowShade.rgb, 0.12), cover(back));
        col = mix(col, mix(u.cBase.rgb, u.cSnow.rgb, 0.18), cover(back) * (1.0 - cover(back - 1.5)));
        float front = bank(p, H - 24.0, 110.0, 9.0);
        col = mix(col, mix(u.cBase.rgb, u.cSnow.rgb, 0.17), cover(front));
        col = mix(col, mix(u.cBase.rgb, u.cSnow.rgb, 0.28), cover(front) * (1.0 - cover(front - 2.0)));
    }

    // A few still snowflakes, fewer higher up, none where the bar sits: specks, and
    // here and there a crystal of six arms.
    float cs = 34.0;
    vec2 cell = floor(p / cs);
    float cy = H - (cell.y + 0.5) * cs;
    float chance = mix(0.015, 0.11, smoothstep(760.0, 150.0, cy)) * step(70.0, (cell.y + 0.5) * cs);
    if (hash(cell + 0.5) < chance) {
        vec2 c = (cell + 0.2 + 0.6 * hash2(cell + 3.0)) * cs;
        vec2 q = p - c;
        float r = hash(cell + 9.0);
        float a = mix(0.06, 0.2, r) * mix(0.6, 1.0, smoothstep(760.0, 200.0, cy));
        if (r > 0.8 && cy < 430.0) {
            float L = mix(3.5, 5.0, hash(cell + 11.0));
            float ang = atan(q.y, q.x) + hash(cell + 13.0);
            float arm = abs(fract(ang / TAU * 6.0 + 0.5) - 0.5) / 6.0 * TAU;
            float d = max(length(q) * sin(arm) - 0.45, length(q) - L);
            col = mix(col, u.cSnow.rgb, 0.3 * cover(-d));
        } else {
            col = mix(col, u.cSnow.rgb, a * cover(mix(0.7, 1.4, r) - length(q)));
        }
    }

    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
