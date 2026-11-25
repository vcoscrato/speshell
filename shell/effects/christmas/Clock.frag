#version 440
#extension GL_GOOGLE_include_directive : enable
// Christmas's clock face: an evergreen wreath seen from above. Fir sprigs in three layers,
// each casting shade on the one under it, each sprig a spray of needles swept toward its
// tip and lit on the side toward the light; holly leaves and red berries at the hours,
// more at twelve, three, and nine, and a red bow at six. Inside, a night with a few
// snowflakes falling while the clock runs; gilt hands, a short broad hour hand and a long
// slender minute hand with a star at its tip; and a bead of light that runs round inside
// the wreath with the seconds, flaring at each tick, the last few seconds glowing behind.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    float hourTurn;     // each hand's turns from twelve, clockwise
    float minuteTurn;
    float secondTurn;
    float ticking;      // 1 shows the bead of light
    float sinceTick;    // s since the second last ticked
    float time;         // s, for the falling snow
    vec4 cNight;
    vec4 cShadow;
    vec4 cPineDeep;
    vec4 cPine;
    vec4 cPineLight;
    vec4 cHolly;
    vec4 cHollyLight;
    vec4 cBerry;
    vec4 cBerryDeep;
    vec4 cBerryLight;
    vec4 cGold;
    vec4 cGoldDeep;
    vec4 cGlint;
    vec4 cGlow;
    vec4 cSnow;
} u;
#include "../common/common.glsl"

const vec2 LIGHT = vec2(-0.6, -0.8);    // toward the light, up and to the left

// A fir sprig in its own frame (x across, y along from its base to its tip at L): a
// spray of needles, widest a third of the way out, its edge serrated by needle tips swept
// toward the tip. Returns (signed distance, > 0 inside; the phase between needles).
vec2 sprig(vec2 q, float L, float W, float R) {
    float s = clamp(q.y / L, 0.0, 1.0);
    float w = W * sin(PI * pow(s, 0.75)) * (1.0 - s * 0.3);
    float teeth = fract((q.y - abs(q.x) * 1.2) / (R * 0.028));
    float edge = w * (1.0 - 0.4 * teeth);
    return vec2(min(edge - abs(q.x), min(q.y, L - q.y)), teeth);
}

// One layer of n sprigs round the wreath, laid over o, each at its own radius, tilt, and
// size, all sweeping clockwise; the layer's shade falls on what is under it.
vec4 sprigs(vec4 o, vec2 p, float R, float turn, float n, float layer, vec3 shade, vec3 lit, vec3 deep) {
    float k = floor(turn * n);
    vec2 sh = vec2(R * 0.025, R * 0.035);
    float cov = 0.0, shadow = 0.0;
    vec3 col = vec3(0.0);
    for (int j = -4; j <= 1; j++) {
        float i = mod(k + float(j), n);
        float h1 = hash(vec2(i, layer + 1.0));
        float h2 = hash(vec2(i, layer + 7.0));
        float h3 = hash(vec2(i, layer + 13.0));
        float a = (k + float(j) + 0.2 + 0.6 * h1) / n;
        float rb = R * mix(0.69, 0.87, h2);
        vec2 base = at(a, rb);
        vec2 tang = normalize(vec2(-base.y, base.x));
        vec2 dir = rot(tang, (h3 - 0.5) * 0.6 - (rb / R - 0.78) * 1.6);
        vec2 acr = vec2(-dir.y, dir.x);
        float L = R * mix(0.26, 0.36, hash(vec2(i, layer + 19.0)));
        float W = L * mix(0.17, 0.21, h1);
        vec2 rel = p - base;
        vec2 q = vec2(dot(rel, acr), dot(rel, dir));
        vec2 sd = sprig(q, L, W, R);
        vec2 rs = rel - sh;
        shadow = max(shadow, cover(sprig(vec2(dot(rs, acr), dot(rs, dir)), L, W, R).x));
        float c = cover(sd.x);
        // Lit on the side facing the light, darker between the needles and at the twig.
        vec3 sc = mix(shade, lit, step(0.0, dot(acr * sign(q.x), LIGHT)));
        sc = mix(sc, deep, 0.55 * (1.0 - band(sd.y, 0.16)) * step(R * 0.008, abs(q.x)));
        sc = mix(sc, deep, 0.6 * (1.0 - band(abs(q.x), R * 0.007)));
        col = mix(col, sc, c);
        cov = max(cov, c);
    }
    o = over(o, u.cShadow.rgb, 0.45 * shadow * (1.0 - cov));
    return over(o, col, cov);
}

// A holly leaf along y from its stem at 0 to its tip at len: a lens whose edges bite in
// between spines. Signed distance, > 0 inside.
float holly(vec2 q, float len, float w) {
    float t = clamp(q.y / len, 0.0, 1.0);
    float bite = abs(sin(t * PI * 3.5)) * w * 0.38 * smoothstep(0.05, 0.25, t) * (1.0 - smoothstep(0.8, 0.98, t));
    return min(w * sin(PI * t) - bite - abs(q.x), min(q.y, len - q.y));
}

// A berry of radius r at c: a red sphere lit from the upper left, with a glint and the
// dark eye at its crown.
vec4 berry(vec4 o, vec2 p, vec2 c, float r) {
    vec2 q = (p - c) / r;
    float l = length(q);
    o = over(o, u.cShadow.rgb, 0.5 * cover((1.1 - length(q - vec2(0.25, 0.35))) * r));
    vec3 col = mix(u.cBerryDeep.rgb, u.cBerry.rgb, band(dot(q, LIGHT) + 0.55 - 0.5 * l, 0.0));
    col = mix(col, u.cBerryLight.rgb, band(dot(q, LIGHT) - 0.35, 0.0) * step(l, 0.85));
    col = mix(col, u.cGlint.rgb, cover((0.2 - length(q - LIGHT * 0.45)) * r));
    col = mix(col, u.cBerryDeep.rgb, 0.8 * cover((0.12 - length(q + LIGHT * 0.1)) * r));
    return over(o, col, cover((1.0 - l) * r));
}

// A holly leaf at c pointing along turn a, lit and shaded about its midrib.
vec4 hollyLeaf(vec4 o, vec2 p, vec2 c, float a, float len, float w) {
    vec2 q = handFrame(p - c, a);
    float d = holly(q, len, w);
    float ds = holly(handFrame(p - c - vec2(len, len * 1.4) * 0.06, a), len, w);
    o = over(o, u.cShadow.rgb, 0.45 * cover(ds) * (1.0 - cover(d)));
    vec2 across = rot(vec2(1.0, 0.0), a * TAU);
    vec3 col = mix(u.cHolly.rgb, mix(u.cHolly.rgb, u.cHollyLight.rgb, 0.55), step(0.0, dot(across * sign(q.x), LIGHT)));
    col = mix(col, u.cHollyLight.rgb, 0.6 * (1.0 - band(abs(q.x), len * 0.025)) * step(q.y, len * 0.85));
    return over(o, col, cover(d));
}

// The bow at six, centered at c and s px across: two loops of ribbon from a knot, and
// two tails with notched ends; lit on its upper faces, folded into shade below.
vec4 bow(vec4 o, vec2 p, vec2 c, float s) {
    vec2 q = (p - c) / s;
    float tails = 1e3;
    for (int i = 0; i < 2; i++) {
        float side = i == 0 ? -1.0 : 1.0;
        vec2 tq = vec2(q.x * side, q.y) - vec2(0.03, 0.02);
        vec2 dir = normalize(vec2(0.42, 0.9));
        vec2 lq = vec2(dot(tq, vec2(dir.y, -dir.x)), dot(tq, dir));
        float len = 0.72 + 0.08 * float(i);
        float hw = mix(0.1, 0.14, lq.y / len);
        float notch = len - 0.12 * (1.0 - abs(lq.x) / hw);
        tails = min(tails, -min(hw - abs(lq.x), min(lq.y, notch - lq.y)));
    }
    o = over(o, u.cShadow.rgb, 0.45 * cover(-(tails - 0.05) * s));
    o = over(o, mix(u.cBerryDeep.rgb, u.cBerry.rgb, 0.3 + 0.5 * step(q.x, 0.0)), cover(-tails * s));
    // Loops: lopsided ovals out to each side, each with the shaded hollow inside it.
    float loops = 1e3, hollow = 1e3;
    for (int i = 0; i < 2; i++) {
        float side = i == 0 ? -1.0 : 1.0;
        vec2 lq = rot(vec2(q.x * side, q.y) - vec2(0.4, -0.12), -0.3 + 0.1 * float(i));
        float e = (length(lq / vec2(0.4, 0.26)) - 1.0) * 0.26;
        loops = min(loops, e);
        hollow = min(hollow, (length((lq - vec2(-0.03, 0.05)) / vec2(0.22, 0.09)) - 1.0) * 0.09);
    }
    o = over(o, u.cShadow.rgb, 0.45 * cover(-(loops - 0.04) * s));
    vec3 ribbon = mix(u.cBerryDeep.rgb, u.cBerry.rgb, band(-q.y + 0.02, 0.0));
    ribbon = mix(ribbon, u.cBerryLight.rgb, 0.8 * band(-q.y - 0.24, 0.0));
    o = over(o, ribbon, cover(-loops * s));
    o = over(o, mix(u.cBerryDeep.rgb, u.cShadow.rgb, 0.4), cover(-hollow * s));
    float knot = sdRoundRect(q - vec2(0.0, -0.05), vec2(0.12, 0.13), 0.07);
    o = over(o, u.cBerryDeep.rgb, cover(-(knot - 0.03) * s));
    o = over(o, mix(u.cBerry.rgb, u.cBerryLight.rgb, band(-q.x - q.y * 0.5 - 0.05, 0.0)), cover(-knot * s));
    return o;
}

// A hand len long and w in half width along y from the pivot, widest at `waist` and
// tapering to a point, with a short tail. Signed distance, > 0 inside.
float hand(vec2 q, float len, float w, float waist, float tail) {
    float t = q.y / len;
    float hw = w * (t < waist ? mix(0.55, 1.0, sin(t / waist * PI * 0.5)) : pow(max(1.0 - t, 0.0) / (1.0 - waist), 0.8));
    return q.y < 0.0 ? min(w * 0.55 - abs(q.x), q.y + tail) : min(hw - abs(q.x), len - q.y);
}

// A five-pointed star of radius r, points along y. Signed distance, > 0 inside.
float star(vec2 q, float r) {
    float a = abs(mod(atan(q.x, q.y) + PI / 5.0, TAU / 5.0) - PI / 5.0);
    vec2 f = length(q) * vec2(sin(a), cos(a));
    vec2 tip = vec2(0.0, r);
    vec2 notch = 0.45 * r * vec2(sin(PI / 5.0), cos(PI / 5.0));
    vec2 e = notch - tip;
    return -sdSeg(f, tip, notch) * sign(e.x * (f.y - tip.y) - e.y * (f.x - tip.x));
}

// Gilt, lit on the side of a hand's axis toward the light.
vec3 gilt(vec2 q, float turn) {
    vec2 across = rot(vec2(1.0, 0.0), turn * TAU);
    return mix(u.cGoldDeep.rgb, u.cGold.rgb, 0.2 + 0.8 * step(0.0, dot(across * sign(q.x), LIGHT)));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area;
    float R = min(u.area.x, u.area.y) * 0.5 - 1.5;
    float r = length(p);
    float turn = turnOf(p);
    vec4 o = vec4(0.0);

    // ── The wreath's shadow on the panel, and the night inside it ──
    o = over(o, u.cShadow.rgb, 0.4 * cover(R * 0.97 - length(p - vec2(R * 0.025, R * 0.04))));
    vec3 night = mix(u.cNight.rgb, u.cShadow.rgb, 0.3 * band(length(p - vec2(R * 0.04, R * 0.06)), R * 0.5));
    o = over(o, night, cover(R * 0.7 - r));

    // Snowflakes falling through it while the clock runs, six-armed, each its own size,
    // passing behind the wreath at the bottom and coming back in at the top.
    if (r < R * 0.68) {
        for (int i = 0; i < 6; i++) {
            float fi = float(i);
            float span = R * 1.7;
            float x = R * (fi / 5.0 - 0.5) * 0.95 + R * 0.08 * (hash(vec2(fi, 1.0)) - 0.5);
            float y = mod(hash(vec2(fi, 2.0)) * span + u.time * R * mix(0.02, 0.035, hash(vec2(fi, 3.0))), span) - span * 0.5;
            vec2 q = p - vec2(x + R * 0.03 * sin(u.time * 0.4 + fi * 2.0), y);
            float L = R * mix(0.025, 0.045, hash(vec2(fi, 4.0)));
            float ang = atan(q.y, q.x) + fi + u.time * 0.2;
            float arm = abs(fract(ang / TAU * 6.0 + 0.5) - 0.5) / 6.0 * TAU;
            float d = max(length(q) * sin(arm) - max(0.45, R * 0.005), length(q) - L);
            o = over(o, u.cSnow.rgb, 0.7 * cover(-d));
        }
    }

    // ── The wreath: a dark bed, then three layers of sprigs ──
    o = over(o, mix(u.cPineDeep.rgb, u.cShadow.rgb, 0.3), cover(R * 0.15 - abs(r - R * 0.8)));
    vec3 pineMid = mix(u.cPine.rgb, u.cPineLight.rgb, 0.45);
    o = sprigs(o, p, R, turn, 34.0, 0.0, u.cPineDeep.rgb, u.cPine.rgb, u.cShadow.rgb);
    o = sprigs(o, p, R, turn, 38.0, 1.0, u.cPine.rgb, pineMid, u.cPineDeep.rgb);
    o = sprigs(o, p, R, turn, 41.0, 2.0, mix(u.cPine.rgb, pineMid, 0.5), u.cPineLight.rgb, u.cPine.rgb);

    // ── Holly and berries at the hours, more at the quarters; a bow at six ──
    float hr = floor(turn * 12.0 + 0.5);
    for (int k = -1; k <= 1; k++) {
        float h = mod(hr + float(k), 12.0);
        if (h == 6.0)
            continue;
        float a = h / 12.0;
        vec2 c = at(a, R * 0.8);
        float lean = (hash(vec2(h, 31.0)) - 0.5) * 0.08;
        if (mod(h, 3.0) < 0.5) {
            o = hollyLeaf(o, p, c, a + 0.2 + lean, R * 0.22, R * 0.075);
            o = hollyLeaf(o, p, c, a - 0.2 + lean, R * 0.2, R * 0.07);
            o = berry(o, p, c + at(a + 0.25, R * 0.045), R * 0.058);
            o = berry(o, p, c + at(a - 0.25, R * 0.045), R * 0.052);
            o = berry(o, p, c + at(a + 0.5, R * 0.045), R * 0.055);
        } else {
            o = hollyLeaf(o, p, c, a + (hash(vec2(h, 37.0)) < 0.5 ? 0.22 : -0.22) + lean, R * 0.15, R * 0.052);
            o = berry(o, p, c + at(a + 0.3, R * 0.022), R * 0.048);
            o = berry(o, p, c + at(a - 0.2, R * 0.03), R * 0.042);
        }
    }
    if (turn > 0.36 && turn < 0.64)
        o = bow(o, p, at(0.5, R * 0.82), R * 0.36);

    // ── The bead of light with the seconds, inside the wreath ──
    float rB = R * 0.6;
    if (u.ticking > 0.5) {
        float S = floor(u.secondTurn * 60.0 + 0.5);
        for (int j = 1; j <= 3; j++) {
            float b = max(0.0, 1.0 - (float(j) - 1.0 + clamp(u.sinceTick, 0.0, 1.0)) / 3.0);
            o = over(o, u.cGlow.rgb, 0.8 * b * cover(R * 0.016 - length(p - at((S - float(j)) / 60.0, rB))));
        }
        float d = length(p - at(u.secondTurn, rB));
        float flare = 1.0 - smoothstep(0.0, 0.35, u.sinceTick);
        o = over(o, u.cGold.rgb, (0.14 + 0.18 * flare) * cover(R * (0.06 + 0.03 * flare) - d));
        o = over(o, u.cGlow.rgb, (0.25 + 0.3 * flare) * cover(R * 0.042 - d));
        o = over(o, mix(u.cGlow.rgb, u.cGlint.rgb, 0.5 + 0.5 * flare), cover(R * 0.026 - d));
    }

    // ── Gilt hands, their shadows first: a short broad hour hand, and a long slender
    // minute hand with a star at its tip ──
    vec2 sh = vec2(R * 0.025, R * 0.035);
    vec2 hq = handFrame(p, u.hourTurn);
    vec2 mq = handFrame(p, u.minuteTurn);
    vec2 sq = mq - vec2(0.0, R * 0.7);
    float hd = hand(hq, R * 0.46, R * 0.075, 0.32, R * 0.1);
    float md = hand(mq, R * 0.66, R * 0.028, 0.15, R * 0.14);
    float sd = star(sq, R * 0.085);
    vec2 hqs = handFrame(p - sh, u.hourTurn);
    vec2 mqs = handFrame(p - sh, u.minuteTurn);
    float shd = max(max(hand(hqs, R * 0.46, R * 0.075, 0.32, R * 0.1), hand(mqs, R * 0.66, R * 0.028, 0.15, R * 0.14)),
                    star(mqs - vec2(0.0, R * 0.7), R * 0.085));
    o = over(o, u.cShadow.rgb, 0.5 * cover(shd));
    o = over(o, gilt(mq, u.minuteTurn), cover(md));
    o = over(o, gilt(sq, u.minuteTurn), cover(sd));
    o = over(o, gilt(hq, u.hourTurn), cover(hd));
    // The hub: a gilt boss with a glint.
    o = over(o, u.cGoldDeep.rgb, cover(R * 0.065 - r));
    o = over(o, u.cGold.rgb, cover(R * 0.05 - r));
    o = over(o, u.cGlint.rgb, 0.8 * cover(R * 0.018 - length(p - vec2(-R * 0.015, -R * 0.02))));

    fragColor = o * u.qt_Opacity;
}
