#version 440
#extension GL_GOOGLE_include_directive : enable
// Meringue peaks at dusk: a great peak of meringue, piped in a spiral and curling over
// at its tip, rises out of banks of whipped cream with a smaller one at its shoulder,
// and a far range of them stands pale along the horizon. Toward the setting sun,
// mesas of layered cake stand in the haze, glazed on top, and nearer peaks rise out of
// the cream. A river of caramel winds out of the light between drifts of frosting
// toward the viewer, and on a ledge of dark chocolate in the foreground a cluster of
// rock-sugar crystals catches the last sun, grains of sugar glinting in the air.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
} u;
#include "../../effects/common/common.glsl"
#include "../landscape.glsl"

// Five-stop sky ramp, horizon to zenith.
vec3 sky(float t) {
    vec3 a = rgb(255, 210, 164), b = rgb(246, 164, 150), c = rgb(208, 114, 138);
    vec3 d = rgb(126, 70, 114), e = rgb(52, 32, 66);
    if (t < 0.22) return mix(a, b, t / 0.22);
    if (t < 0.48) return mix(b, c, (t - 0.22) / 0.26);
    if (t < 0.74) return mix(c, d, (t - 0.48) / 0.26);
    return mix(d, e, (t - 0.74) / 0.26);
}

// A peak of meringue on `base` at x = c, rising to `top`, `w` half wide at its foot:
// rolls of meringue piped round and round, each a rounded tier wrapping up at a
// slant, so its outline is scalloped, stepping in at alternate heights either side;
// its tip curls over toward `lean`. Each roll is lit on top and shaded beneath, the
// whole lit on the sun's side (+x), with a rim of light on the lit edge.
float rollHalf(float y, float w, float turns, float phase) {
    float ph = fract(y * turns + phase);
    return w * pow(max(0.0, 1.0 - y), 0.7) * (0.8 + 0.2 * sqrt(sin(3.1416 * ph)));
}

vec3 meringue(vec3 col, vec2 q, float c, float base, float top, float w, float lean, float turns,
              vec3 lit, vec3 shade, vec3 groove, vec3 rim) {
    float y = (q.y - base) / (top - base);
    if (y < 0.0 || y > 1.02)
        return col;
    float cx = c + lean * w * 0.7 * pow(y, 3.0);
    float dx = q.x - cx;
    float hl = rollHalf(y, w, turns, 0.25), hr = rollHalf(y, w, turns, -0.25);
    float inside = cover(dx + hl) * cover(hr - dx) * cover(1.0 - y);
    if (inside <= 0.0)
        return col;
    float side = dx > 0.0 ? dx / max(hr, 1e-4) : dx / max(hl, 1e-4);
    // Across a roll: 0 at the groove below it, 1 at the one above, slanting as it wraps.
    float ph = fract(y * turns - side * 0.25);
    bool sunny = side > -0.2 + 0.1 * sin(y * 7.0);
    vec3 m = sunny ? lit : shade;
    m = mix(m, sunny ? mix(lit, shade, 0.45) : mix(shade, groove, 0.5), 1.0 - band(ph, 0.32));
    m = mix(m, groove, 1.0 - band(ph, 0.07));
    m = mix(m, rim, cover(0.0026 - (hr - dx)) * step(0.0, dx) * band(ph, 0.3));
    return mix(col, m, inside);
}

// A mesa of layered cake at x = c, from `base` to `top`, `w` half wide: steep sides,
// its strata of sponge, cream, and jam, lit toward the sun, and a glaze on top that
// runs down its edge in short drips.
vec3 mesa(vec3 col, vec2 q, float c, float base, float top, float w, float seed, vec3 hz, float haze) {
    float y = (q.y - base) / (top - base);
    float dx = q.x - c;
    float hw = w * (1.0 + 0.12 * (1.0 - y)) + (vnoise(vec2(q.y * 60.0, seed)) - 0.5) * w * 0.05;
    float inside = cover(hw - abs(dx)) * cover(top - q.y) * cover(q.y - base);
    if (inside <= 0.0)
        return col;
    float k = floor(y * 7.0 + 0.15 * sin(q.x * 40.0 + seed));
    float m3 = mod(k, 3.0);
    vec3 layer = m3 < 0.5 ? rgb(226, 170, 124) : m3 < 1.5 ? rgb(244, 220, 200) : rgb(190, 96, 114);
    float split = (vnoise(vec2(q.y * 12.0, seed + 2.0)) - 0.5) * w * 0.4 - w * 0.15;
    vec3 m = dx > split ? layer : layer * vec3(0.7, 0.62, 0.72);
    // The glaze, its drips of uneven length.
    float cell = w * 0.16;
    float f = fract(q.x / cell) * 2.0 - 1.0;
    float drip = (top - q.y) - (top - base) * (0.07 + 0.16 * pow(hash(vec2(floor(q.x / cell), seed)), 2.0) * sqrt(max(0.0, 1.0 - f * f)));
    vec3 glaze = dx > split ? rgb(242, 152, 180) : rgb(190, 102, 140);
    m = mix(m, glaze, cover(-drip));
    m = mix(m, rgb(255, 214, 196), cover(0.0025 - (top - q.y)) * step(split, dx));
    return mix(col, mix(m, hz, haze), inside);
}

// A crystal of rock sugar from `b` to `t`, `w` half wide: a prism with a pointed end,
// one face lit, one shaded, and a glint along its edge.
vec3 crystal(vec3 col, vec2 q, vec2 b, vec2 t, float w, vec3 lit, vec3 shade, vec3 glint) {
    vec2 ax = t - b;
    float len = length(ax);
    vec2 dir = ax / len;
    vec2 p = vec2(dot(q - b, dir), dot(q - b, vec2(-dir.y, dir.x)));
    float hw = w * clamp((len - p.x) / (w * 1.6), 0.0, 1.0);
    float inside = cover(hw - abs(p.y)) * cover(p.x) * cover(len - p.x);
    if (inside <= 0.0)
        return col;
    vec3 c = p.y > 0.0 ? lit : shade;
    c = mix(c, glint, cover(w * 0.12 - abs(p.y - hw * 0.15)) * step(0.0, p.y) * 0.8);
    return mix(col, c, inside);
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    float aspect = u.resolution.x / u.resolution.y;
    vec2 sun = vec2(aspect * 0.66, 0.41);
    float ds = length(q - sun);
    float horizon = 0.36;

    // Sky in flat bands, warmest round the sun.
    float t = clamp((q.y - horizon) / (1.0 - horizon), 0.0, 1.0);
    t = pow(t, 0.8) - 0.14 * exp(-ds * 2.8) + (fbm(vec2(q.x * 1.2, q.y * 4.0)) - 0.5) * 0.04;
    vec3 col = sky(steps(clamp(t, 0.0, 1.0), 11.0));

    // Long wisps of spun sugar, plum with sunlit undersides.
    float env = smoothstep(0.52, 0.62, q.y) * (1.0 - smoothstep(0.86, 0.96, q.y));
    float n = fbm(vec2(q.x * 1.1, q.y * 12.0) + vec2(2.0, 7.0)) + 0.2 * vnoise(vec2(q.x * 5.0, q.y * 36.0));
    float nLow = fbm(vec2(q.x * 1.1, (q.y + 0.008) * 12.0) + vec2(2.0, 7.0)) + 0.2 * vnoise(vec2(q.x * 5.0, (q.y + 0.008) * 36.0));
    float streak = band(n * env, 0.57);
    float warm = exp(-abs(q.x - sun.x) * 1.3);
    col = mix(col, mix(rgb(150, 86, 126), rgb(214, 120, 136), warm), streak);
    col = mix(col, mix(rgb(236, 148, 146), rgb(255, 206, 166), warm), streak * (1.0 - band(nLow * env, 0.57)));

    // The sun, in rings of light.
    col = mix(col, mix(col, rgb(255, 222, 184), 0.12), cover(0.21 - ds));
    col = mix(col, mix(col, rgb(255, 230, 196), 0.24), cover(0.125 - ds));
    col = mix(col, rgb(255, 240, 214), cover(0.06 - ds));

    // The far range of meringue, pale with distance.
    vec3 hz = mix(rgb(250, 196, 176), rgb(255, 222, 190), exp(-abs(q.x - sun.x) * 2.0));
    for (int i = 0; i < 9; i++) {
        float fi = float(i);
        float h = hash(vec2(fi, 3.0));
        float c = aspect * (0.02 + fi / 8.0 * 0.96) + (hash(vec2(fi, 4.0)) - 0.5) * 0.12;
        float top = horizon + mix(0.05, 0.13, h);
        col = meringue(col, q, c, horizon - 0.02, top, (top - horizon) * mix(0.5, 0.75, hash(vec2(fi, 5.0))),
                       hash(vec2(fi, 6.0)) < 0.5 ? -0.5 : 0.5, 3.0 + floor(h * 2.0),
                       mix(rgb(250, 214, 204), hz, 0.45), mix(rgb(222, 160, 172), hz, 0.45),
                       mix(rgb(208, 146, 162), hz, 0.45), rgb(255, 230, 204));
    }
    // Far banks of cream, bright with the sun.
    float h0 = horizon + 0.012 * billows(q.x, 12.0, 1.0);
    col = mix(col, hz, below(h0, q.y));

    // Mesas of cake toward the sun, in the haze.
    col = mesa(col, q, aspect * 0.86, horizon - 0.02, horizon + 0.11, 0.07, 1.0, hz, 0.42);
    col = mesa(col, q, aspect * 0.97, horizon - 0.02, horizon + 0.075, 0.05, 2.0, hz, 0.5);
    col = mesa(col, q, aspect * 0.53, horizon - 0.02, horizon + 0.06, 0.045, 3.0, hz, 0.52);

    float rimSun = exp(-abs(q.x - sun.x) * 1.6);
    float h1 = horizon - 0.02 + 0.03 * billows(q.x + 0.4, 4.5, 2.0);
    col = mix(col, rgb(242, 186, 182), below(h1, q.y));
    col = mix(col, mix(rgb(250, 208, 194), rgb(255, 232, 206), rimSun), below(h1, q.y) * (1.0 - below(h1 - 0.006, q.y)));

    // The great meringue and its shoulder peak.
    vec3 mLit = rgb(254, 238, 230), mShade = rgb(214, 158, 176), mGroove = rgb(186, 128, 154), mRim = rgb(255, 222, 186);
    col = meringue(col, q, aspect * 0.37, 0.27, 0.55, 0.1, 0.7, 4.0, mLit, mShade, mGroove, mRim);
    col = meringue(col, q, aspect * 0.24, 0.27, 0.84, 0.18, -0.6, 6.0, mLit, mShade, mGroove, mRim);

    // Banks of whipped cream swallow their feet, darker toward the viewer.
    float h2 = 0.31 + 0.045 * billows(q.x + 0.9, 3.0, 3.0);
    col = mix(col, rgb(232, 172, 176), below(h2, q.y));
    col = mix(col, mix(rgb(250, 206, 196), rgb(255, 228, 204), rimSun), below(h2, q.y) * (1.0 - below(h2 - 0.007, q.y)));
    float u2 = h2 - 0.045 + 0.03 * billows(q.x + 4.1, 6.5, 12.0);
    col = mix(col, rgb(212, 150, 162), below(u2, q.y) * below(h2, q.y));

    // Smaller peaks rising out of the cream toward the sun, nearer, their feet in it.
    col = meringue(col, q, aspect * 0.71, 0.22, 0.35, 0.05, 0.6, 3.0, mLit, mShade, mGroove, mRim);
    col = meringue(col, q, aspect * 0.53, 0.2, 0.31, 0.045, -0.5, 3.0, mLit, mShade, mGroove, mRim);
    col = meringue(col, q, aspect * 0.94, 0.22, 0.42, 0.07, -0.6, 4.0, mLit, mShade, mGroove, mRim);
    float h2b = 0.24 + 0.03 * billows(q.x + 6.3, 5.0, 9.0);
    col = mix(col, rgb(222, 160, 170), below(h2b, q.y));
    col = mix(col, mix(rgb(246, 196, 190), rgb(255, 222, 200), rimSun), below(h2b, q.y) * (1.0 - below(h2b - 0.006, q.y)));

    // Drifts of frosting, rolling down toward the viewer.
    float h3 = 0.2 + 0.05 * billows(q.x + 1.7, 2.6, 4.0);
    col = mix(col, rgb(186, 112, 138), below(h3, q.y));
    col = mix(col, mix(rgb(220, 148, 158), rgb(246, 186, 170), rimSun), below(h3, q.y) * (1.0 - below(h3 - 0.009, q.y)));
    float u3 = h3 - 0.055 + 0.035 * billows(q.x + 2.9, 4.0, 13.0);
    col = mix(col, rgb(160, 94, 126), below(u3, q.y));

    // The caramel river, winding out of the light toward the viewer.
    float rt = clamp((h2 - 0.01 - q.y) / (h2 - 0.01), 0.0, 1.0);
    float rx = sun.x - 0.06 - 0.42 * rt + 0.13 * sin(rt * 7.0 + 0.4) * rt;
    float rw = 0.004 + 0.085 * pow(rt, 1.8);
    float river = cover(rw - abs(q.x - rx)) * cover(h2 - 0.012 - q.y);
    vec3 caramel = mix(rgb(232, 158, 80), rgb(196, 112, 62), steps(rt, 3.0));
    float shine = exp(-abs(q.x - rx + 0.25 * rw) / (rw * 0.25 + 0.002)) * (0.5 + 0.5 * band(fract(q.y * 60.0 + rt * 3.0), 0.5));
    caramel = mix(caramel, rgb(255, 220, 160), shine * 0.55);
    col = mix(col, caramel, river);
    col = mix(col, rgb(250, 214, 196), cover(rw + 0.003 - abs(q.x - rx)) * (1.0 - river) * cover(h2 - 0.012 - q.y) * step(0.04, rt));

    // The nearest drift, on the right.
    float h4 = 0.07 + 0.08 * billows(q.x + 2.3, 1.8, 5.0) - 0.12 * smoothstep(aspect * 0.75, aspect * 0.45, q.x);
    col = mix(col, rgb(120, 72, 104), below(h4, q.y));
    col = mix(col, rgb(170, 108, 128), below(h4, q.y) * (1.0 - below(h4 - 0.01, q.y)));

    // A ledge of dark chocolate in the lower left, crystals of rock sugar on it.
    float ledge = 0.17 - pow(max(q.x - 0.04, 0.0) / 0.5, 1.7) * 0.17 + (vnoise(vec2(q.x * 30.0, 6.0)) - 0.5) * 0.01;
    float onLedge = below(ledge, q.y) * cover(0.56 - q.x);
    col = mix(col, rgb(56, 34, 38), onLedge);
    col = mix(col, rgb(116, 70, 66), onLedge * (1.0 - below(ledge - 0.006, q.y)));
    vec3 cLit = rgb(255, 238, 220), cShade = rgb(222, 176, 166), cGlint = rgb(255, 250, 240);
    vec2 cb = vec2(0.17, 0.12);
    col = crystal(col, q, cb, cb + vec2(-0.05, 0.13), 0.022, cLit, cShade, cGlint);
    col = crystal(col, q, cb + vec2(0.02, 0.0), cb + vec2(0.05, 0.19), 0.028, cLit, cShade, cGlint);
    col = crystal(col, q, cb + vec2(0.05, -0.01), cb + vec2(0.13, 0.09), 0.02, cLit, cShade, cGlint);
    col = crystal(col, q, cb + vec2(-0.02, -0.01), cb + vec2(-0.1, 0.06), 0.016, cLit, cShade, cGlint);
    col = crystal(col, q, cb + vec2(0.08, -0.02), cb + vec2(0.11, 0.04), 0.012, cLit, cShade, cGlint);

    // Grains of sugar glinting in the air.
    for (int i = 0; i < 14; i++) {
        float fi = float(i);
        vec2 h = hash2(vec2(fi, 21.0));
        vec2 c = vec2(mix(0.05, 0.75, h.x), mix(0.2, 0.55, h.y));
        vec2 d = abs(q - c) / mix(0.003, 0.007, hash(vec2(fi, 22.0)));
        col = mix(col, rgb(255, 238, 222), cover(1.0 - sqrt(d.x) - sqrt(d.y)) * 0.85);
    }

    fragColor = vec4(col, 1.0);
}
