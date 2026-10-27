#version 440
#extension GL_GOOGLE_include_directive : enable
// Sugar's clock face: an entremet seen from above, under a mirror glaze. The glaze is
// rose, marbled with paler and deeper veins, flecked with gold leaf, and holds a long
// soft reflection. A collar of royal-icing lace runs round its edge in scallops with a
// pearl in each. Sugar pearls mark the hours, gold dragées the quarters. The hands
// are slender plaques of dark chocolate edged in gold, each with a lozenge, and they
// turn under a rose of pulled sugar; a gold dragée glides round inside the lace with
// the seconds.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    float hourTurn;     // each hand's turns from twelve, clockwise
    float minuteTurn;
    float secondTurn;
    float seconds;      // 1 shows the gliding dragée
    vec4 cGlaze;
    vec4 cGlazeDeep;
    vec4 cGlazeLight;
    vec4 cSheen;
    vec4 cLace;
    vec4 cPearlShade;
    vec4 cGold;
    vec4 cGoldShade;
    vec4 cChocolate;
    vec4 cRose;
    vec4 cRoseLight;
    vec4 cRoseShade;
} u;
#include "../common/common.glsl"

const float TAU = 6.2831853;
const vec2 LIGHT = vec2(-0.6, -0.8);    // toward the light, up and to the left

vec2 at(float turn, float r) {
    float a = turn * TAU;
    return vec2(sin(a), -cos(a)) * r;
}

float turnOf(vec2 p) {
    return fract(atan(p.x, -p.y) / TAU + 1.0);
}

// p in a hand's frame: x across it, y out along it.
vec2 handFrame(vec2 p, float turn) {
    return rot(p, -turn * TAU) * vec2(1.0, -1.0);
}

// A pearl or dragée of radius r at c: round, shaded away from the light, with a glint.
vec4 pearl(vec4 o, vec2 p, vec2 c, float r, vec3 col, vec3 shade, vec3 glint) {
    vec2 d = (p - c) / r;
    o = over(o, u.cGlazeDeep.rgb, 0.45 * cover((1.0 - length(d - vec2(0.25, 0.35))) * r));
    vec3 pc = mix(col, shade, smoothstep(-0.3, 0.9, dot(d, -LIGHT)));
    pc = mix(pc, glint, cover((0.28 - length(d - LIGHT * 0.42)) * r));
    return over(o, pc, cover((1.0 - length(d)) * r));
}

// A chocolate hand `len` long: a slender shaft tapering to a point, a lozenge at `at`
// `lw` wide and `lh` long, a round counterweight behind the pivot. Signed distance.
float hand(vec2 q, float len, float w, float at_, float lw, float lh, float tail) {
    float t = clamp(q.y / len, 0.0, 1.0);
    float shaft = sdSeg(q, vec2(0.0, -tail), vec2(0.0, len)) - w * mix(1.0, 0.25, t * t);
    vec2 l = abs(q - vec2(0.0, at_));
    float loz = (l.x / lw + l.y / lh - 1.0) * min(lw, lh) * 0.8;
    return min(shaft, loz);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area;
    float R = min(u.area.x, u.area.y) * 0.5 - 1.5;
    float r = length(p);
    float turn = turnOf(p);
    vec4 o = vec4(0.0);

    // ── The edge of the cake, falling away below the lace ──
    vec3 edge = mix(u.cGlazeDeep.rgb, u.cGlaze.rgb, 0.35 * smoothstep(0.3, 0.9, dot(p / R, LIGHT)));
    o = over(o, edge, cover(R - r));

    // ── The mirror glaze, marbled ──
    float top = R * 0.955;
    vec2 m = p / R;
    float f = fbm(m * 2.3 + vec2(fbm(m * 1.6 + 3.0), fbm(m * 1.6 + 7.0)) * 1.4);
    vec3 g = mix(u.cGlaze.rgb, u.cGlazeDeep.rgb, 0.35 * smoothstep(0.45, 0.75, f));
    g = mix(g, u.cGlazeLight.rgb, 0.3 * (1.0 - smoothstep(0.0, 0.03, abs(f - 0.5))));
    g = mix(g, u.cGlazeDeep.rgb, 0.25 * (1.0 - smoothstep(0.0, 0.02, abs(f - 0.62))));
    // The window's reflection, a soft crescent along the upper left of the glaze.
    float cres = smoothstep(0.62, 0.86, length(m)) * (1.0 - smoothstep(0.86, 0.93, length(m)));
    g = mix(g, u.cSheen.rgb, 0.22 * cres * smoothstep(0.2, 0.9, dot(normalize(m + 1e-4), LIGHT)));
    o = over(o, g, cover(top - r));

    // ── Gold leaf, a few crumpled flecks ──
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        vec2 c = at(hash(vec2(fi, 1.0)), R * mix(0.3, 0.62, hash(vec2(fi, 2.0))));
        vec2 q = rot(p - c, hash(vec2(fi, 3.0)) * TAU);
        float a = atan(q.y, q.x);
        float fr = R * mix(0.025, 0.045, hash(vec2(fi, 4.0))) * (1.0 + 0.35 * sin(a * 3.0 + fi) + 0.2 * sin(a * 7.0 + fi * 2.0));
        float d = length(q * vec2(1.0, 1.4)) - fr;
        float crumple = vnoise(q / (R * 0.012) + fi * 7.0);
        vec3 leaf = mix(u.cGoldShade.rgb, u.cGold.rgb, smoothstep(0.25, 0.65, crumple));
        leaf = mix(leaf, u.cSheen.rgb, 0.5 * smoothstep(0.78, 0.9, crumple));
        o = over(o, leaf, cover(-d) * 0.9);
    }

    // ── A collar of royal-icing lace round the edge ──
    float n = 30.0;
    float ph = fract(turn * n);
    float scallop = R * (0.975 - 0.05 * (1.0 - sin(3.1416 * ph)));
    float lw = max(0.6, R * 0.011);
    float lace = cover(lw - abs(r - scallop));
    lace = max(lace, cover(lw * 0.8 - abs(r - R * 0.905)));
    vec2 dot_ = at((floor(turn * n) + 0.5) / n, R * 0.945);
    lace = max(lace, cover(R * 0.013 - length(p - dot_)));
    // Tiny loops between the scallops.
    vec2 loop = at(floor(turn * n + 0.5) / n, R * 0.912);
    lace = max(lace, cover(lw * 0.8 - abs(length(p - loop) - R * 0.018)));
    o = over(o, u.cGlazeDeep.rgb, 0.4 * lace * cover(top + R * 0.02 - r));
    o = over(o, u.cLace.rgb, lace * cover(R - r));

    // ── Sugar pearls at the hours, gold dragées at the quarters ──
    float hour = floor(turn * 12.0 + 0.5);
    vec2 hc = at(hour / 12.0, R * 0.78);
    if (mod(hour, 3.0) < 0.5)
        o = pearl(o, p, hc, R * 0.046, u.cGold.rgb, u.cGoldShade.rgb, u.cSheen.rgb);
    else
        o = pearl(o, p, hc, R * 0.03, u.cLace.rgb, u.cPearlShade.rgb, u.cSheen.rgb);

    // ── The gold dragée, gliding round with the seconds ──
    if (u.seconds > 0.5)
        o = pearl(o, p, at(u.secondTurn, R * 0.86), R * 0.026, u.cGold.rgb, u.cGoldShade.rgb, u.cSheen.rgb);

    // ── The hands, their shadows first: chocolate plaques edged in gold ──
    vec2 sh = vec2(R * 0.025, R * 0.035);
    float hourD = hand(handFrame(p, u.hourTurn), R * 0.5, R * 0.036, R * 0.3, R * 0.075, R * 0.13, R * 0.1);
    float minD = hand(handFrame(p, u.minuteTurn), R * 0.76, R * 0.026, R * 0.52, R * 0.05, R * 0.11, R * 0.13);
    float shadow = min(hand(handFrame(p - sh, u.hourTurn), R * 0.5, R * 0.036, R * 0.3, R * 0.075, R * 0.13, R * 0.1),
                       hand(handFrame(p - sh, u.minuteTurn), R * 0.76, R * 0.026, R * 0.52, R * 0.05, R * 0.11, R * 0.13));
    o = over(o, u.cGlazeDeep.rgb * 0.6, 0.45 * cover(-shadow));
    float gw = max(0.6, R * 0.008);
    vec2 mq = handFrame(p, u.minuteTurn);
    o = over(o, u.cGold.rgb, cover(-minD));
    o = over(o, mix(u.cChocolate.rgb, u.cGold.rgb, 0.15 * step(0.0, mq.x)), cover(-minD - gw));
    vec2 hq = handFrame(p, u.hourTurn);
    o = over(o, u.cGold.rgb, cover(-hourD));
    o = over(o, mix(u.cChocolate.rgb, u.cGold.rgb, 0.15 * step(0.0, hq.x)), cover(-hourD - gw));
    // A fine gold line inside the hour hand's lozenge.
    vec2 hl = abs(hq - vec2(0.0, R * 0.3));
    o = over(o, u.cGold.rgb, cover(gw * 0.7 - abs((hl.x / (R * 0.045) + hl.y / (R * 0.085) - 1.0) * R * 0.04)));

    // ── A rose of pulled sugar at the middle: rings of scalloped petals, each lit
    // toward its rim and shaded where the next ring rises over it ──
    float rr = R * 0.12;
    if (r < rr * 1.4) {
        float a = atan(p.y, p.x);
        o = over(o, u.cGlazeDeep.rgb, 0.45 * cover(rr * 1.05 - length(p - sh * 0.4)));
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float np = 5.0 - fi;
            float pr = rr * (1.0 - fi * 0.22) * (0.9 + 0.1 * abs(sin(a * np * 0.5 + fi * 1.3)));
            float x = r / pr;
            vec3 rc = mix(u.cRoseShade.rgb, u.cRose.rgb, smoothstep(0.55, 0.9, x));
            rc = mix(rc, u.cRoseLight.rgb, 0.7 * smoothstep(0.8, 1.0, x) * smoothstep(-0.3, 0.8, dot(p / max(r, 1e-3), LIGHT)));
            o = over(o, rc, cover(pr - r));
        }
    }

    fragColor = o * u.qt_Opacity;
}
