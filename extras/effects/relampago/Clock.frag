#version 440
#extension GL_GOOGLE_include_directive : enable
// Relâmpago's clock face: a racing tachometer. A dark bezel rings a dial of asphalt with
// a scale of minute ticks round its edge, bold at the hours and longest at the quarters,
// and a redline painted in from fifty to sixty. The hands are needles, the minute's in
// racing paint and longer, pinned under a checkered cap; each second a bolt of lightning
// strikes from the cap out to that second's tick and crackles there till the next.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    float hourTurn;     // each hand's turns from twelve, clockwise
    float minuteTurn;
    float secondTurn;
    float seconds;      // 1 shows the bolt
    float secondIndex;  // the whole second, 0..59, so each bolt takes its own shape
    float time;         // s, for the crackle
    vec4 cAsphalt;
    vec4 cRubber;
    vec4 cBezel;
    vec4 cTick;
    vec4 cDim;
    vec4 cPaint;
    vec4 cCore;
    vec4 cGlow;
    vec4 cEdge;
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

// A needle from a little behind the center out to `len`, `w` wide at its base,
// tapering to a narrow tip. Negative inside.
float needle(vec2 q, float len, float w) {
    float tail = w * 3.0;
    float t = clamp((q.y + tail) / (len + tail), 0.0, 1.0);
    float halfWidth = mix(w, w * 0.22, t);
    return max(abs(q.x) - halfWidth, max(-q.y - tail, q.y - len));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area;
    float R = min(u.area.x, u.area.y) * 0.5 - 1.5;
    float r = length(p);
    float turn = turnOf(p);
    vec4 o = vec4(0.0);

    // ── The bezel and the asphalt dial ──
    float dialR = R * 0.9;
    vec3 bezel = mix(u.cBezel.rgb, u.cRubber.rgb, band(dot(normalize(p + 1e-4), vec2(0.6, 0.8)), 0.0) * 0.5);
    o = over(o, bezel, cover(R - r));
    o = over(o, u.cRubber.rgb, cover(1.2 - abs(r - dialR)));
    float grain = hash(floor(p / 1.5));
    vec3 asphalt = mix(u.cAsphalt.rgb, u.cRubber.rgb, 0.35 * band(r, dialR * 0.6));
    asphalt = mix(asphalt, mix(asphalt, u.cDim.rgb, 0.22), step(0.965, grain));
    o = over(o, asphalt, cover(dialR - 0.6 - r));

    // ── The redline, fifty to sixty ──
    float red = step(50.0 / 60.0, turn) * cover(R * 0.07 - abs(r - dialR * 0.93));
    o = over(o, u.cPaint.rgb, 0.85 * red);

    // ── Ticks: a minute each, bold at the hours, longest at the quarters ──
    float minute = floor(turn * 60.0 + 0.5);
    float isHour = step(mod(minute, 5.0), 0.5);
    float isQuarter = step(mod(minute, 15.0), 0.5);
    vec2 tq = handFrame(p, minute / 60.0);
    float tickLen = mix(mix(R * 0.05, R * 0.11, isHour), R * 0.16, isQuarter);
    float tickW = mix(R * 0.007, mix(R * 0.018, R * 0.026, isQuarter), isHour);
    float outer = dialR * 0.97;
    float tick = max(abs(tq.x) - tickW, abs(tq.y - (outer - tickLen * 0.5)) - tickLen * 0.5);
    vec3 tickCol = mix(u.cDim.rgb, u.cTick.rgb, isHour);
    tickCol = mix(tickCol, u.cTick.rgb, step(50.0 / 60.0, turn) * 0.0);
    o = over(o, tickCol, cover(-tick));

    // ── The bolt: struck from the cap to the second's tick, crackling till the next ──
    if (u.seconds > 0.5) {
        vec2 bq = handFrame(p, u.secondTurn);
        // Along the bolt in x, across it in y.
        vec2 q = vec2(bq.y, bq.x);
        float flicker = floor(u.time * 18.0);
        float seed = u.secondIndex * 7.0 + flicker * 0.37;
        float len = dialR * 0.83;
        float d = boltDist(q - vec2(R * 0.08, 0.0), R * 0.075, R * 0.03, seed);
        d = max(d, max(R * 0.08 - q.x, q.x - len));
        float strength = 0.75 + 0.25 * hash(vec2(flicker, 3.0));
        o = over(o, u.cEdge.rgb, 0.35 * strength * cover(R * 0.03 - d));
        o = over(o, u.cGlow.rgb, strength * cover(R * 0.016 - d));
        o = over(o, u.cCore.rgb, cover(R * 0.006 - d));
        // A spark where it lands.
        float spark = length(p - at(u.secondTurn, len));
        o = over(o, u.cGlow.rgb, 0.5 * cover(R * 0.04 - spark));
        o = over(o, u.cCore.rgb, cover(R * 0.018 - spark));
    }

    // ── Needles, their shadows first ──
    vec2 hq = handFrame(p, u.hourTurn);
    float h = needle(hq, dialR * 0.52, R * 0.045);
    vec2 mq = handFrame(p, u.minuteTurn);
    float m = needle(mq, dialR * 0.84, R * 0.035);
    float shadow = min(needle(handFrame(p - vec2(2.0, 3.0), u.hourTurn), dialR * 0.52, R * 0.045),
                       needle(handFrame(p - vec2(2.0, 3.0), u.minuteTurn), dialR * 0.84, R * 0.035));
    o = over(o, u.cRubber.rgb, 0.6 * cover(-shadow));
    vec3 hourCol = mix(u.cTick.rgb, mix(u.cTick.rgb, u.cDim.rgb, 0.45), step(0.0, hq.x));
    o = over(o, u.cRubber.rgb, cover(1.2 - h));
    o = over(o, hourCol, cover(-h));
    vec3 minuteCol = mix(u.cPaint.rgb, mix(u.cPaint.rgb, u.cRubber.rgb, 0.35), step(0.0, mq.x));
    o = over(o, u.cRubber.rgb, cover(1.2 - m));
    o = over(o, minuteCol, cover(-m));

    // ── The checkered cap ──
    float capR = R * 0.1;
    vec2 cq = rot(p, 0.785) / (capR * 0.42);
    float checker = mod(floor(cq.x) + floor(cq.y), 2.0);
    vec3 cap = mix(u.cRubber.rgb, u.cTick.rgb, checker);
    o = over(o, u.cRubber.rgb, cover(capR + 1.6 - r));
    o = over(o, u.cBezel.rgb, cover(capR + 0.4 - r));
    o = over(o, cap, cover(capR - 1.2 - r));

    fragColor = o * u.qt_Opacity;
}
