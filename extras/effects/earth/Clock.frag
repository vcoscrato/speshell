#version 440
#extension GL_GOOGLE_include_directive : enable
// Earth's clock face: a disc cut from layered rock, its strata bending across it and a
// few cracks through them, under a bevelled rim lit from the top left. Jade is set at
// the hours, hexagonal and larger at the quarters, each stone faceted. The hands are
// obelisks, a lit and a shaded face either side of their ridge, outlined and casting a
// shadow, around a jade boss: a broad one of pale stone for the hour and a long, slim
// one of jade for the minute. A pebble of gold rolls round a carved groove with the
// seconds.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    float hourTurn;     // each hand's turns from twelve, clockwise
    float minuteTurn;
    float secondTurn;
    float seconds;      // 1 shows the pebble
    vec4 cStone;
    vec4 cStoneLight;
    vec4 cRock;
    vec4 cLight;
    vec4 cShade;
    vec4 cWarm;
    vec4 cJade;
    vec4 cGlint;
    vec4 cGold;
} u;
#include "../../lib/common.glsl"

const float TAU = 6.2831853;
// Toward the light, at the top left.
const vec2 LIGHT = vec2(-0.6, -0.8);

vec2 at(float turn, float r) {
    float a = turn * TAU;
    return vec2(sin(a), -cos(a)) * r;
}

float turnOf(vec2 p) {
    return fract(atan(p.x, -p.y) / TAU + 1.0);
}

vec2 handFrame(vec2 p, float turn) {
    return rot(p, -turn * TAU) * vec2(1.0, -1.0);
}

float sdHexagon(vec2 p, float r) {
    const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
    p = abs(p);
    p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
    p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
    return length(p) * sign(p.y);
}

// A faceted gem's color at q (its own frame): three tones of jade by which facet q is
// on, the facets meeting at its middle, with a glint on the lit one.
vec3 gem(vec2 q, float r) {
    float a = atan(q.y, q.x);
    float facet = floor((a + 3.1415927) / (TAU / 6.0));
    vec2 n = vec2(cos((facet + 0.5) * TAU / 6.0 - 3.1415927), sin((facet + 0.5) * TAU / 6.0 - 3.1415927));
    float lit = dot(n, LIGHT);
    vec3 col = mix(mix(u.cJade.rgb, u.cShade.rgb, 0.45), u.cJade.rgb, band(lit, -0.4));
    col = mix(col, mix(u.cJade.rgb, u.cGlint.rgb, 0.45), band(lit, 0.5));
    // The table: a flat top in the middle.
    col = mix(col, mix(u.cJade.rgb, u.cGlint.rgb, 0.2), 1.0 - band(length(q), r * 0.42));
    return col;
}

// An obelisk from the center out to `len`, `w` wide: a ridge down its middle with a lit
// face and a shaded one. Returns (distance, which side: -1 or 1).
vec2 obelisk(vec2 q, float len, float w) {
    float y = clamp(q.y, -w, len);
    float halfWidth = q.y < 0.0 ? w : w * (1.0 - 0.75 * y / len);
    float tip = q.y - len - halfWidth * 0.0;
    float d = max(abs(q.x) - halfWidth, max(-q.y - w, tip));
    // A pointed tip: cut by two slopes.
    d = max(d, (abs(q.x) * 1.6 + q.y) - len);
    return vec2(d, sign(q.x));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area;
    float R = min(u.area.x, u.area.y) * 0.5 - 1.5;
    float r = length(p);
    float turn = turnOf(p);
    vec4 o = vec4(0.0);

    // ── The stone: strata bending across the disc, a few cracks through them ──
    vec2 sq = rot(p / R, -0.35);
    // Layers of uneven thickness: the strata coordinate bent by a slow wave and noise,
    // then stretched unevenly so some layers run thin and others thick.
    float strata = sq.y * 6.5 + 0.7 * sin(sq.x * 2.2 + 1.0) + 0.5 * fbm(p / R * 2.6);
    strata += 0.35 * sin(strata * 1.7);
    float layer = fract(strata);
    float which = floor(strata);
    vec3 stone = mix(u.cStone.rgb, u.cStoneLight.rgb, 0.2 + 0.55 * hash(vec2(which, 3.0)));
    stone = mix(stone, u.cWarm.rgb, 0.08 * step(0.6, hash(vec2(which, 7.0))));
    // Each layer's top edge catches the light.
    stone = mix(stone, mix(stone, u.cLight.rgb, 0.16), 1.0 - band(layer, 0.07));
    float crack = voronoiEdge(p + vec2(31.0, -12.0), R * 0.45, 1.0);
    float seam = (1.0 - smoothstep(0.0, 0.9, crack)) * smoothstep(0.55, 0.65, fbm(p / R * 2.0 + 9.0));
    stone = mix(stone, u.cShade.rgb, seam * 0.8);
    o = over(o, stone, cover(R - r));

    // ── The rim: a bevel, lit on the side toward the light ──
    float rimW = R * 0.07;
    float lit = dot(normalize(p + 1e-4), LIGHT);
    vec3 rim = mix(u.cRock.rgb, u.cLight.rgb, band(lit, 0.35) * 0.5);
    rim = mix(rim, mix(u.cRock.rgb, u.cShade.rgb, 0.55), band(-lit, 0.35));
    o = over(o, rim, cover(R - r) * cover(r - (R - rimW)));
    o = over(o, u.cShade.rgb, cover(1.2 - abs(r - (R - rimW))));
    o = over(o, u.cShade.rgb, cover(1.2 - abs(r - R + 0.6)));

    // ── The groove and its pebble ──
    float rS = R * 0.72;
    float gw = R * 0.03;
    float inGroove = cover(gw - abs(r - rS));
    // Carved in: shaded on the side toward the light, lit on the far side.
    float side = (r - rS) / gw * lit;
    vec3 groove = mix(mix(u.cStone.rgb, u.cShade.rgb, 0.35), mix(u.cStone.rgb, u.cLight.rgb, 0.18), band(side, 0.1));
    o = over(o, groove, inGroove * 0.85);
    if (u.seconds > 0.5) {
        vec2 c = at(u.secondTurn, rS);
        float pr = max(gw * 1.7, 2.6);
        float d = length(p - c) - pr;
        o = over(o, u.cShade.rgb, 0.5 * cover(-(length(p - c - vec2(1.0, 1.5)) - pr)));
        o = over(o, u.cShade.rgb, cover(1.2 - d));
        float shade = dot(normalize(p - c + 1e-4), LIGHT);
        vec3 pebble = u.cGold.rgb;
        pebble = mix(pebble, mix(u.cGold.rgb, u.cGlint.rgb, 0.55), band(shade, 0.45));
        pebble = mix(pebble, mix(u.cGold.rgb, u.cShade.rgb, 0.45), band(-shade, 0.2));
        o = over(o, pebble, cover(-d));
    }

    // ── Jade at the hours ──
    float k = floor(turn * 12.0 + 0.5);
    float quarter = step(mod(k, 3.0), 0.5);
    vec2 g = rot(p - at(k / 12.0, R * 0.85), 0.0);
    float gr = mix(R * 0.03, R * 0.052, quarter);
    float hex = sdHexagon(rot(g, k / 12.0 * TAU), gr);
    float diamond = (abs(g.x) + abs(g.y)) * 0.75 - gr * 0.72;
    float gd = mix(diamond, hex, quarter);
    o = over(o, u.cShade.rgb, cover(1.6 - gd));
    o = over(o, gem(g, gr), cover(-gd));

    // ── Hands: stone obelisks, their shadows first ──
    vec2 hq = handFrame(p, u.hourTurn);
    float hourLen = R * 0.5, hourW = R * 0.1;
    float minuteLen = R * 0.8, minuteW = R * 0.058;
    vec2 h = obelisk(hq, hourLen, hourW);
    vec2 mq = handFrame(p, u.minuteTurn);
    vec2 m = obelisk(mq, minuteLen, minuteW);
    vec2 sh = p - vec2(1.0, 1.5) * max(1.5, R * 0.03);
    float shadow = min(obelisk(handFrame(sh, u.hourTurn), hourLen, hourW).x,
                       obelisk(handFrame(sh, u.minuteTurn), minuteLen, minuteW).x);
    o = over(o, u.cShade.rgb, 0.65 * cover(-shadow + 1.0));
    // Which face is lit depends on where the hand points.
    float hLit = h.y * dot(at(u.hourTurn + 0.25, 1.0), LIGHT);
    float mLit = m.y * dot(at(u.minuteTurn + 0.25, 1.0), LIGHT);
    vec3 hourCol = mix(mix(u.cLight.rgb, u.cRock.rgb, 0.45), mix(u.cLight.rgb, u.cGlint.rgb, 0.4), step(0.0, hLit));
    vec3 minuteCol = mix(mix(u.cJade.rgb, u.cShade.rgb, 0.22), mix(u.cJade.rgb, u.cGlint.rgb, 0.4), step(0.0, mLit));
    o = over(o, u.cShade.rgb, cover(1.5 - h.x));
    o = over(o, hourCol, cover(-h.x));
    o = over(o, u.cShade.rgb, cover(1.5 - m.x));
    o = over(o, minuteCol, cover(-m.x));

    // ── The jade boss ──
    float boss = r - R * 0.08;
    o = over(o, u.cShade.rgb, cover(1.4 - boss));
    o = over(o, gem(p, R * 0.08), cover(-boss));

    fragColor = o * u.qt_Opacity;
}
