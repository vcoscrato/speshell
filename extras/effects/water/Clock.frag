#version 440
#extension GL_GOOGLE_include_directive : enable
// Water's clock face: a round pool seen from above, deep at its middle, with caustics
// drifting over its floor and a ring of light where its rim meets the water. Drops mark
// the hours, larger at the quarters. The hands are glassy currents, rounded and lit
// along one side, turning out of a whirlpool at the center. Each second a drop lands on
// the second's mark and rings spread from it.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    float hourTurn;     // each hand's turns from twelve, clockwise
    float minuteTurn;
    float secondTurn;
    float seconds;      // 1 shows the drops and their rings
    float sinceTick;    // s since the second hand ticked
    float time;         // s, for the caustics and the whirlpool
    vec4 cDeep;
    vec4 cMid;
    vec4 cLight;
    vec4 cFoam;
    vec4 cAbyss;
    vec4 cRim;
    vec4 cTeal;
} u;
#include "../../lib/common.glsl"

const float TAU = 6.2831853;

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

// A drop pointing out along y: round at its base, drawn to a point. Negative inside.
float drop(vec2 q, float r) {
    float tip = r * 1.9;
    float rise = clamp(q.y / tip, 0.0, 1.0);
    float body = mix(length(q) - r, abs(q.x) / (1.0 - rise) - r, step(0.0, q.y));
    return max(body, q.y - tip);
}

// A current from the center out to `len`, `w` wide, rounded at both ends and slimming
// toward its tip. Returns (distance, across: -1..1).
vec2 current(vec2 q, float len, float w) {
    float y = clamp(q.y, 0.0, len);
    float halfWidth = w * mix(1.0, 0.55, y / len);
    float d = length(vec2(q.x, q.y - y)) - halfWidth;
    return vec2(d, q.x / halfWidth);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area;
    float R = min(u.area.x, u.area.y) * 0.5 - 1.5;
    float r = length(p);
    float turn = turnOf(p);
    vec4 o = vec4(0.0);

    // ── The pool: shallows at the rim, deep at the middle ──
    vec3 water = mix(u.cAbyss.rgb, u.cDeep.rgb, 0.3);
    water = mix(water, mix(u.cAbyss.rgb, u.cDeep.rgb, 0.45), band(r, R * 0.42));
    water = mix(water, mix(u.cAbyss.rgb, u.cDeep.rgb, 0.62), band(r, R * 0.68));
    water = mix(water, mix(u.cAbyss.rgb, u.cMid.rgb, 0.7), band(r, R * 0.9));
    // Caustics: two drifting layers of warped cell edges, bright where they cross,
    // brighter in the shallows.
    vec2 cq = p + R * 0.05 * vec2(sin(p.y / (R * 0.17) + u.time * 0.7), cos(p.x / (R * 0.15) - u.time * 0.6));
    float c1 = voronoiEdge(cq + vec2(u.time * 3.0, -u.time * 2.0), R * 0.16, 1.0);
    float c2 = voronoiEdge(rot(cq, 1.1) - vec2(u.time * 2.0, u.time * 2.6) + 50.0, R * 0.23, 1.0);
    float shallows = 0.3 + 0.7 * smoothstep(R * 0.15, R * 0.9, r);
    float lines = (1.0 - smoothstep(0.0, 1.1, c1)) * 0.6 + (1.0 - smoothstep(0.0, 1.3, c2)) * 0.45;
    water = mix(water, u.cLight.rgb, clamp(lines, 0.0, 1.0) * 0.32 * shallows);
    o = over(o, water, cover(R - r));
    // Light where the rim meets the water, and the rim.
    o = over(o, u.cLight.rgb, 0.35 * cover(R * 0.035 - abs(r - R + R * 0.035)));
    o = over(o, u.cRim.rgb, cover(1.4 - abs(r - R + 0.7)));

    // ── Drops at the hours ──
    float k = floor(turn * 12.0 + 0.5);
    float quarter = step(mod(k, 3.0), 0.5);
    vec2 mq = handFrame(p - at(k / 12.0, R * 0.85), k / 12.0);
    float dr = drop(vec2(mq.x, -mq.y), mix(R * 0.028, R * 0.042, quarter));
    o = over(o, u.cAbyss.rgb, 0.6 * cover(1.4 - dr));
    vec3 dropCol = mix(u.cLight.rgb, u.cFoam.rgb, 0.6 * band(-mq.x - mq.y * 0.4, R * 0.012));
    o = over(o, mix(u.cTeal.rgb, dropCol, 0.4 + 0.6 * quarter), cover(-dr));

    // ── The second's drop and the rings it leaves ──
    float rS = R * 0.71;
    if (u.seconds > 0.5) {
        // A ring of faint marks the drops land on.
        float dot60 = length(p - at(floor(turn * 60.0 + 0.5) / 60.0, rS));
        o = over(o, u.cLight.rgb, 0.3 * cover(1.0 - dot60));
        vec2 landed = at(u.secondTurn, rS);
        float d = length(p - landed);
        for (int i = 0; i < 3; i++) {
            float age = u.sinceTick + float(i);
            float radius = age * R * 0.2 + float(i) * 0.0;
            float fade = clamp(1.0 - age / 2.6, 0.0, 1.0);
            vec2 from = at(u.secondTurn - float(i) / 60.0, rS);
            float ring = abs(length(p - from) - radius);
            o = over(o, u.cFoam.rgb, fade * fade * 0.55 * cover(1.1 - ring) * cover(R - r));
        }
        float splash = clamp(1.0 - u.sinceTick / 0.3, 0.0, 1.0);
        o = over(o, u.cLight.rgb, cover(R * (0.03 + 0.03 * splash) - d) * 0.5);
        o = over(o, u.cFoam.rgb, cover(R * 0.022 - d));
    }

    // ── Hands: glassy currents, lit along one side ──
    vec2 hq = handFrame(p, u.hourTurn);
    vec2 h = current(hq, R * 0.48, R * 0.055);
    vec2 mq2 = handFrame(p, u.minuteTurn);
    vec2 m = current(mq2, R * 0.78, R * 0.035);
    float shadow = min(current(handFrame(p - vec2(1.5, 3.0), u.hourTurn), R * 0.48, R * 0.055).x,
                       current(handFrame(p - vec2(1.5, 3.0), u.minuteTurn), R * 0.78, R * 0.035).x);
    o = over(o, u.cAbyss.rgb, 0.45 * cover(-shadow));
    vec3 hourCol = mix(u.cTeal.rgb, u.cFoam.rgb, band(-h.y, 0.25) * 0.8);
    hourCol = mix(hourCol, u.cDeep.rgb, band(h.y, 0.55) * 0.5);
    o = over(o, u.cAbyss.rgb, cover(1.0 - h.x));
    o = over(o, hourCol, cover(-h.x));
    vec3 minuteCol = mix(u.cLight.rgb, u.cFoam.rgb, band(-m.y, 0.25) * 0.85);
    minuteCol = mix(minuteCol, u.cMid.rgb, band(m.y, 0.55) * 0.5);
    o = over(o, u.cAbyss.rgb, cover(1.0 - m.x));
    o = over(o, minuteCol, cover(-m.x));

    // ── The whirlpool at the center ──
    float hubR = R * 0.085;
    float swirl = sin(atan(p.y, p.x) * 3.0 + log(max(r, 1.0)) * 7.0 - u.time * 1.6);
    vec3 hub = mix(u.cDeep.rgb, u.cLight.rgb, band(swirl, 0.35));
    hub = mix(hub, u.cAbyss.rgb, 1.0 - band(r, hubR * 0.35));
    o = over(o, u.cFoam.rgb, cover(hubR + 1.6 - r));
    o = over(o, hub, cover(hubR - r));

    fragColor = o * u.qt_Opacity;
}
