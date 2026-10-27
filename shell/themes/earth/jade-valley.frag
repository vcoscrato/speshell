#version 440
#extension GL_GOOGLE_include_directive : enable
// Jade valley: ragged karst towers crowned with pines rise out of the haze in a golden
// evening, fading to jade with distance. Out on the plain a great walled city
// shows its gold-roofed halls, a river winds toward the viewer catching the sky,
// terraced fields step down the near hills, and a pine leans from a cliff in the
// foreground while cranes cross the light.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
} u;
#include "../../effects/common/common.glsl"
#include "../landscape.glsl"

// Four-stop sky ramp, horizon to zenith.
vec3 sky(float t) {
    vec3 a = rgb(252, 224, 146), b = rgb(244, 200, 118), c = rgb(214, 210, 158), d = rgb(108, 166, 158);
    if (t < 0.33) return mix(a, b, t / 0.33);
    if (t < 0.66) return mix(b, c, (t - 0.33) / 0.33);
    return mix(c, d, (t - 0.66) / 0.34);
}

// A karst tower: steep-walled and round-shouldered, lopsided, leaning a little,
// and ragged with crags. Most are slender pinnacles, now and then a broad massif;
// part 1 is the lower shoulder peak some of them carry on their broader side.
struct Tower { float cx; float wl; float wr; float ht; float k; float m; float lean; };

Tower karstTower(float c, float cell, float tall, float seed, int part) {
    Tower t;
    float h0 = hash(vec2(c, seed)), h1 = hash(vec2(c, seed + 1.0)), h2 = hash(vec2(c, seed + 2.0));
    float h3 = hash(vec2(c, seed + 3.0)), h4 = hash(vec2(c, seed + 4.0)), h5 = hash(vec2(c, seed + 5.0));
    float w = cell * mix(0.2, 0.62, h1 * h1 * h1);
    t.cx = (c + 0.2 + 0.6 * h0) * cell;
    t.ht = tall * mix(0.42, 1.0, h2) * mix(1.0, 0.68, smoothstep(0.3, 0.6, w / cell));
    t.wl = w * mix(0.65, 1.35, h3);
    t.wr = w * mix(0.65, 1.35, h4);
    t.k = mix(1.7, 3.6, h5);
    t.m = mix(0.3, 0.7, hash(vec2(c, seed + 6.0)));
    t.lean = (hash(vec2(c, seed + 7.0)) - 0.5) * 0.7 * w / t.ht;
    if (part == 1) {
        t.cx += (h3 > h4 ? -1.0 : 1.0) * w * mix(0.6, 1.0, h5);
        t.ht *= mix(0.35, 0.7, h0);
        t.wl *= 0.65;
        t.wr *= 0.65;
        t.k = mix(1.6, 2.4, h2);
        t.m = 0.5;
        // Not every tower has one.
        if (hash(vec2(c, seed + 9.0)) < 0.4)
            t.ht = -1.0;
    }
    return t;
}

// How far the tower's outline rises above its base at x, for a point yb above
// the base (the tower leans); below 0 outside it.
float towerTop(Tower t, float x, float yb) {
    float d = x - t.cx - t.lean * yb;
    float r = d < 0.0 ? -d / t.wl : d / t.wr;
    if (r >= 1.0 || t.ht < 0.0)
        return -1.0;
    float top = t.ht * pow(1.0 - pow(r, t.k), t.m);
    // Crags: knobs and notches along the outline.
    return top + (vnoise(vec2(d * 160.0, t.cx * 31.0)) - 0.5) * 0.008
               + (vnoise(vec2(d * 45.0, t.cx * 17.0)) - 0.5) * 0.09 * t.ht;
}

// Where q sits across the tower at its height: -1 at the left wall, 1 at the right.
float towerAcross(Tower t, float x, float yb) {
    float d = x - t.cx - t.lean * yb;
    float ry = pow(max(1.0 - pow(clamp(yb / t.ht, 0.0, 1.0), 1.0 / t.m), 0.0), 1.0 / t.k);
    return clamp(d / ((d < 0.0 ? t.wl : t.wr) * max(ry, 0.08)), -1.0, 1.0);
}

// Pines along the top of a skyline: little stacked triangles.
float pines(vec2 q, float h, float scale, float seed) {
    float cell = 0.012 * scale;
    float g = floor(q.x / cell);
    if (hash(vec2(g, seed)) < 0.45)
        return 0.0;
    float cx = (g + 0.5) * cell;
    float th = (0.018 + 0.012 * hash(vec2(g, seed + 1.0))) * scale;
    float y = q.y - h + 0.003 * scale;
    float tri = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float yb = th * fi * 0.28;
        float tw = cell * 0.45 * (1.0 - fi * 0.22);
        float rel = (y - yb) / (th * 0.55);
        tri = max(tri, cover(tw * (1.0 - rel) - abs(q.x - cx)) * cover(rel) * cover(1.0 - rel));
    }
    return tri;
}

// A crane of span s at c, wings raised by `lift`.
float crane(vec2 q, vec2 c, float s, float lift) {
    vec2 p = (q - c) / s;
    float ax = abs(p.x);
    float wing = ax < 1.0 ? cover(0.09 * (1.0 - ax) + 0.02 - abs(p.y - lift * ax + 0.25 * ax * ax)) : 0.0;
    float body = cover(0.07 - length((p - vec2(0.0, -0.02)) * vec2(0.45, 1.0)));
    float neck = cover(0.03 - abs(p.y + 0.03)) * cover(p.x + 0.9) * cover(-p.x - 0.1);
    return max(max(wing, body), neck);
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    float aspect = u.resolution.x / u.resolution.y;
    vec2 sun = vec2(aspect * 0.6, 0.47);
    float ds = length(q - sun);

    // Sky in flat bands, and the sun in its glow.
    float t = clamp((q.y - 0.36) / 0.64, 0.0, 1.0);
    t = pow(t, 0.8) - 0.1 * exp(-ds * 3.0) + (fbm(vec2(q.x * 1.3, q.y * 4.0)) - 0.5) * 0.04;
    vec3 col = sky(steps(clamp(t, 0.0, 1.0), 10.0));
    col = mix(col, mix(col, rgb(255, 238, 180), 0.2), cover(0.2 - ds));
    col = mix(col, mix(col, rgb(255, 240, 190), 0.35), cover(0.12 - ds));
    col = mix(col, rgb(255, 246, 210), cover(0.07 - ds));

    // Long clouds with sunlit undersides.
    float env = smoothstep(0.6, 0.7, q.y) * (1.0 - smoothstep(0.9, 1.0, q.y));
    float n = fbm(vec2(q.x * 1.6, q.y * 12.0) + vec2(2.0, 7.0));
    float nb = fbm(vec2(q.x * 1.6, (q.y + 0.01) * 12.0) + vec2(2.0, 7.0));
    float cloud = band(n * env, 0.5);
    col = mix(col, rgb(206, 196, 150), cloud);
    col = mix(col, mix(rgb(244, 214, 150), rgb(255, 236, 186), exp(-abs(q.x - sun.x) * 2.0)), cloud * (1.0 - band(nb * env, 0.5)));

    // Cranes crossing the light.
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        vec2 c = sun + vec2(-0.24 + 0.07 * fi + 0.02 * hash(vec2(fi, 1.0)), 0.12 + 0.03 * sin(fi * 2.1));
        col = mix(col, rgb(70, 76, 58), crane(q, c, mix(0.012, 0.018, hash(vec2(fi, 4.0))), 0.4 + 0.5 * hash(vec2(fi, 6.0))));
    }

    // Karst ranges, far to near, losing their haze as they come closer. Each tower
    // is lit across its width from the sun's side, streaked with cliffs, tufted
    // with growth on its ledges, and the nearer ones are crowned with pines. The
    // ranges part around the sun. Within a range, shoulders sit behind their
    // towers and the towers overlap in a scattered order.
    for (int layer = 0; layer < 4; layer++) {
        float fl = float(layer);
        float cell = 0.1 + 0.065 * fl;
        float base = 0.37 - 0.02 * fl;
        float tall = 0.15 + 0.1 * fl;
        float seed = 11.0 + fl * 7.0;
        float lx = q.x + fl * 3.7;
        vec3 lit = layer == 0 ? rgb(212, 210, 162) : layer == 1 ? rgb(186, 192, 140) : layer == 2 ? rgb(146, 166, 110) : rgb(116, 146, 88);
        vec3 mid = layer == 0 ? rgb(196, 200, 156) : layer == 1 ? rgb(164, 178, 130) : layer == 2 ? rgb(114, 142, 98) : rgb(80, 112, 74);
        vec3 shade = layer == 0 ? rgb(178, 190, 152) : layer == 1 ? rgb(142, 162, 122) : layer == 2 ? rgb(88, 118, 86) : rgb(54, 84, 62);
        vec3 growth = layer == 1 ? rgb(130, 158, 112) : layer == 2 ? rgb(78, 116, 72) : rgb(46, 88, 54);
        vec3 rim = layer < 2 ? lit : (layer == 2 ? rgb(196, 194, 128) : rgb(204, 192, 112));
        vec3 pine = layer == 1 ? rgb(108, 136, 100) : layer == 2 ? rgb(66, 100, 68) : rgb(36, 66, 48);
        float g = floor(lx / cell);
        float yb = q.y - base;
        for (int pass = 0; pass < 3; pass++) {
            for (int k = -2; k <= 2; k++) {
                float c = g + float(k);
                if (pass > 0 && int(mod(c, 2.0)) != pass - 1)
                    continue;
                Tower t = karstTower(c, cell, tall, seed, pass == 0 ? 1 : 0);
                // Lower toward the sun, so it shows through a gap.
                if (layer > 0)
                    t.ht *= mix(0.4, 1.0, smoothstep(0.08, 0.4, abs(t.cx - fl * 3.7 - sun.x)));
                float f = towerTop(t, lx, yb) - yb;
                // Pines on the summits and shoulders, standing on the outline.
                if (layer > 0 && f > -0.04) {
                    float crown = towerTop(t, lx, max(f + yb, 0.0));
                    float onTop = smoothstep(0.35, 0.6, crown / t.ht);
                    col = mix(col, pine, pines(vec2(lx, q.y), base + crown, 0.45 + 0.25 * fl, seed + c) * onTop
                                         * step(0.45, hash(vec2(floor(lx / (0.03 + 0.01 * fl)), seed + c)))
                                         * below(base + crown + 0.03, q.y));
                }
                if (f < -0.01)
                    continue;
                float u = towerAcross(t, lx, yb);
                float side = sign(sun.x + fl * 3.7 - t.cx);
                float l = u * side + (vnoise(vec2(lx * 70.0, q.y * 16.0)) - 0.5) * 0.45;
                vec3 tc = mix(shade, mid, band(l, -0.3));
                tc = mix(tc, lit, band(l, 0.4));
                if (layer > 0) {
                    // Cliffs: dark streaks running down the walls, most on the shaded side.
                    float streak = vnoise(vec2((lx - t.cx - t.lean * yb) * 150.0, yb * 3.0 + c * 5.0));
                    tc = mix(tc, shade * 0.86, band(streak, 0.74 - 0.08 * step(l, 0.0)) * 0.7);
                    // Shrubs along the ledges, in thin broken strips, and a shaggy summit.
                    float tuft = vnoise(vec2((lx - t.lean * yb) * 30.0 + c * 3.0, yb * 170.0)) - 0.25 * vnoise(vec2(lx * 160.0, yb * 60.0));
                    tc = mix(tc, growth, band(tuft, 0.6) * smoothstep(0.1, 0.5, yb / t.ht) * 0.8);
                    tc = mix(tc, growth, cover(0.007 - f) * step(0.002, f));
                    // Sunlit rim on the wall that faces the light.
                    tc = mix(tc, rim, cover(0.0035 - f) * step(0.55, u * side));
                }
                col = mix(col, tc, cover(f));
            }
        }
        // Haze settles between the ranges.
        if (layer < 3)
            col = mix(col, rgb(236, 226, 172), below(base + 0.012 + 0.02 * billows(q.x + fl * 2.3, 6.0, 40.0 + fl), q.y) * 0.4);
    }

    // Evening mist pooled at the towers' feet, in two flat layers.
    float mist0 = 0.33 + 0.025 * billows(q.x + 2.0, 5.0, 31.0);
    float mist1 = 0.31 + 0.02 * billows(q.x + 5.0, 8.0, 32.0);
    col = mix(col, rgb(240, 228, 176), below(mist0, q.y) * 0.45);
    col = mix(col, rgb(246, 236, 190), below(mist1, q.y) * 0.55);

    // The plain, misty at its far edge.
    float plain = 0.3 + 0.006 * vnoise(vec2(q.x * 20.0, 3.0));
    col = mix(col, rgb(196, 196, 140), below(plain, q.y));
    col = mix(col, rgb(170, 180, 122), below(plain - 0.012, q.y));

    // The walled city on the plain: an outer wall with towers, an inner wall, and
    // gold-roofed halls rising to a palace at the center.
    float cx = aspect * 0.3;
    float cw = 0.34;
    if (abs(q.x - cx) < cw + 0.01 && q.y > plain - 0.006) {
        float rel = (q.x - cx) / cw;
        // Halls behind the walls, taller toward the palace.
        float g = floor(q.x / 0.018);
        float hallH = 0.012 + 0.03 * pow(1.0 - abs(rel), 2.0) * (0.6 + 0.4 * hash(vec2(g, 3.0)));
        float hallTop = plain + 0.028 + hallH;
        float hall = below(hallTop, q.y) * cover(1.0 - abs(rel) - 0.04);
        col = mix(col, rgb(196, 176, 138), hall);
        float roofBand = cover(q.y - hallTop + 0.007) * hall;
        col = mix(col, rgb(214, 160, 60), roofBand);
        col = mix(col, rgb(110, 82, 44), roofBand * cover(0.002 - abs(fract(q.x / 0.018) * 0.018 - 0.009)));
        // The palace: three tiers of gold roofs.
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float py = plain + 0.06 + 0.026 * fi;
            float pw = 0.05 - 0.013 * fi;
            float ry = q.y - py;
            float eave = 0.006 * pow(clamp(abs(q.x - cx) / pw, 0.0, 1.0), 5.0);
            float roof = cover(pw - ry * 1.5 - abs(q.x - cx)) * cover(ry - eave) * cover(0.012 - ry);
            float wallP = cover(pw * 0.7 - abs(q.x - cx)) * cover(q.y - py + 0.016) * cover(py - q.y);
            col = mix(col, rgb(170, 64, 44), wallP);
            col = mix(col, q.x < cx ? rgb(244, 196, 84) : rgb(196, 140, 52), roof);
        }
        // Inner wall, then the outer wall with square towers.
        float inner = below(plain + 0.034, q.y) * cover(0.7 - abs(rel)) * cover(q.y - plain - 0.02);
        col = mix(col, rgb(176, 160, 124), inner);
        float tower = step(0.62, fract(q.x / 0.04)) * 0.008;
        float outer = below(plain + 0.02 + tower, q.y) * cover(1.0 - abs(rel));
        col = mix(col, rgb(206, 190, 150), outer);
        col = mix(col, rgb(150, 136, 104), outer * cover(plain + 0.01 - q.y));
        col = mix(col, rgb(120, 104, 80), outer * cover(0.0012 - abs(fract(q.x / 0.008) * 0.008 - 0.004)) * cover(q.y - plain - 0.016 - tower));
    }

    // Near hills, with terraced fields stepping down them.
    float hl = 0.2 + 0.09 * ridge(q.x * 0.8 + 6.0, 1.6, 7.0);
    float hlInside = below(hl, q.y);
    float terr = (hl - q.y) / 0.019;
    float rowIdx = floor(terr + 0.4 * vnoise(vec2(q.x * 6.0, 1.0)));
    vec3 field = mix(rgb(96, 140, 70), rgb(132, 168, 84), hash(vec2(rowIdx, 2.0)));
    field = mix(field, rgb(200, 186, 96), step(0.82, hash(vec2(rowIdx, 5.0))));
    float edge = band(fract(terr + 0.4 * vnoise(vec2(q.x * 6.0, 1.0))), 0.86);
    field = mix(field, rgb(60, 94, 54), edge);
    col = mix(col, field, hlInside);

    // The river: winding from the plain toward the viewer, widening, catching the sky.
    float rt = clamp((plain - q.y) / plain, 0.0, 1.0);
    float rx = aspect * 0.52 + 0.18 * sin(rt * 4.5 + 0.6) * rt + 0.05 * sin(rt * 11.0) * rt;
    float rw = 0.004 + 0.07 * rt * rt;
    float river = cover(rw - abs(q.x - rx)) * cover(plain - q.y);
    vec3 water = mix(rgb(250, 226, 150), rgb(180, 196, 150), steps(rt, 4.0));
    water = mix(water, rgb(255, 244, 200), band(vnoise(vec2(q.x * 30.0, q.y * 200.0)), 0.76) * 0.8);
    col = mix(col, water, river);
    col = mix(col, rgb(70, 104, 62), cover(rw + 0.004 - abs(q.x - rx)) * (1.0 - river) * cover(plain - q.y) * step(0.05, rt));

    // Foreground cliff on the left, with a leaning pine.
    float cliff = 0.34 - pow(max(q.x - 0.02, 0.0) / 0.5, 1.2) * 0.34 + 0.02 * ridge(q.x + 9.0, 6.0, 9.0);
    float cliffIn = below(cliff, q.y) * cover(0.56 - q.x);
    // Rock in slanting strata, a sunlit lip, and a cap of grass.
    float strata = vnoise(vec2((q.x * 0.6 + q.y) * 34.0, q.x * 3.0));
    vec3 rock = mix(rgb(96, 84, 62), rgb(66, 58, 46), band(strata, 0.55));
    rock = mix(rock, rgb(52, 46, 38), band(strata, 0.82));
    rock = mix(rock, rgb(84, 120, 62), cover(q.y - cliff + 0.016));
    rock = mix(rock, rgb(150, 176, 90), 1.0 - below(cliff - 0.004, q.y));
    col = mix(col, rock, cliffIn);
    // The pine: a trunk leaning out over the valley, with flat tiers of needles.
    float ty = (q.y - 0.28) / 0.34;
    if (ty > 0.0 && ty < 1.0) {
        float tx = 0.12 + 0.2 * ty * ty;
        col = mix(col, rgb(54, 40, 32), cover(mix(0.011, 0.003, ty) - abs(q.x - tx)));
    }
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float at = 0.32 + 0.16 * fi;
        vec2 base = vec2(0.12 + 0.2 * at * at, 0.28 + 0.34 * at);
        float reach = 0.085 - 0.012 * fi;
        float bt = clamp((q.x - base.x) / reach, 0.0, 1.0);
        col = mix(col, rgb(54, 40, 32), cover(0.0025 * (1.0 - 0.6 * bt) - abs(q.y - base.y - 0.01 * bt)) * step(base.x, q.x) * step(q.x, base.x + reach));
        float clump = 1e3;
        for (int k = 0; k < 3; k++) {
            float fk = float(k);
            vec2 c = base + vec2((0.22 + 0.33 * fk) * reach, 0.012 + 0.003 * fk);
            vec2 p = (q - c) / vec2(reach * (0.42 - 0.06 * fk), 0.016 - 0.002 * fk);
            clump = min(clump, length(p) - 1.0 + 0.45 * (vnoise(vec2(q.x * 70.0, q.y * 30.0 + fi * 5.0 + fk)) - 0.5));
        }
        col = mix(col, rgb(36, 68, 48), cover(-clump));
        col = mix(col, rgb(88, 128, 74), cover(-clump - 0.25) * cover(q.y - base.y - 0.015));
    }

    // Pollen drifting in the warm air.
    for (int i = 0; i < 40; i++) {
        vec2 h = hash2(vec2(float(i), 8.3));
        vec2 f = vec2(h.x * aspect, 0.08 + 0.6 * h.y);
        col = mix(col, rgb(255, 236, 170), cover(mix(0.0014, 0.003, hash(vec2(float(i), 1.0))) - length(q - f)) * 0.8);
    }
    fragColor = vec4(col, 1.0);
}
