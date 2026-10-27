#version 440
#extension GL_GOOGLE_include_directive : enable
// Air's clock face: a dusky sky in a ring of pale rim, cloud banks drifting slowly across
// it and streaks of wind circling its middle, tighter toward it. Leaves mark the hours,
// laid along the wind, larger and in the accent at the quarters. A compass rose lies
// under the hands, a broad leaf for the hour and a long feather for the minute, around a
// curl of wind; a leaf rides the wind round the rim with the seconds, tumbling.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    float hourTurn;     // each hand's turns from twelve, clockwise
    float minuteTurn;
    float secondTurn;
    float seconds;      // 1 shows the riding leaf
    float time;         // s, for the clouds and the wind
    vec4 cSky;
    vec4 cDeep;
    vec4 cCloud;
    vec4 cCloudLight;
    vec4 cRim;
    vec4 cWind;
    vec4 cDim;
    vec4 cAccent;
    vec4 cLeaf;
    vec4 cSkyBlue;
} u;
#include "../common/common.glsl"

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

// A leaf `len` long along y from 0, `w` wide: the lens of two arcs, with its midrib.
// Returns (distance, across: -1..1 from one edge to the other).
vec2 leaf(vec2 q, float len, float w) {
    float half_ = len * 0.5;
    float r = (half_ * half_ + w * w) / (2.0 * w);
    vec2 c = vec2(q.x, q.y - half_);
    float d = sdLeaf(c, r, r - w);
    return vec2(d, q.x / max(w, 1e-3));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area;
    float R = min(u.area.x, u.area.y) * 0.5 - 1.5;
    float r = length(p);
    float turn = turnOf(p);
    float a = atan(p.y, p.x);
    vec4 o = vec4(0.0);

    // ── The sky, its cloud banks drifting ──
    vec3 sky = mix(u.cSky.rgb, u.cDeep.rgb, band(r, R * 0.75) * 0.5);
    float clouds = fbm(p / R * vec2(1.6, 3.2) + vec2(u.time * 0.04, 0.0));
    sky = mix(sky, u.cCloud.rgb, band(clouds, 0.5));
    sky = mix(sky, u.cCloudLight.rgb, band(clouds, 0.66) * 0.7);
    o = over(o, sky, cover(R - r));

    // ── Wind circling the middle: dashes along spiral streamlines, flowing round ──
    float lane = log(max(r, 1.0) / R) * 4.0 + a * 0.35;
    float laneIndex = floor(lane * 3.0);
    float across = abs(fract(lane * 3.0) - 0.5) * 2.0;
    float flow = fract(a / TAU * (3.0 + mod(laneIndex, 3.0)) - u.time * (0.05 + 0.03 * hash(vec2(laneIndex, 1.0)))
        + hash(vec2(laneIndex, 2.0)));
    float dash = smoothstep(0.0, 0.08, flow) * (1.0 - smoothstep(0.32, 0.5, flow));
    float streak = (1.0 - smoothstep(0.0, 0.16, across)) * dash * step(0.35, hash(vec2(laneIndex, 4.0)));
    float inWind = smoothstep(R * 0.2, R * 0.35, r) * (1.0 - smoothstep(R * 0.72, R * 0.8, r));
    o = over(o, u.cWind.rgb, 0.3 * streak * inWind);

    // ── The rim ──
    o = over(o, u.cRim.rgb, cover(R * 0.03 - abs(r - R + R * 0.03)));
    o = over(o, u.cDeep.rgb, cover(1.0 - abs(r - R + R * 0.06)));

    // ── Leaves at the hours, laid along the wind ──
    float k = floor(turn * 12.0 + 0.5);
    float quarter = step(mod(k, 3.0), 0.5);
    vec2 mq = handFrame(p - at(k / 12.0, R * 0.84), k / 12.0 + 0.25);
    float len = mix(R * 0.075, R * 0.12, quarter);
    vec2 lf = leaf(mq + vec2(0.0, len * 0.5), len, len * 0.26);
    vec3 leafCol = mix(u.cDim.rgb, u.cAccent.rgb, quarter);
    leafCol = mix(leafCol, mix(leafCol, u.cDeep.rgb, 0.35), band(lf.y, 0.0));
    o = over(o, u.cDeep.rgb, cover(1.2 - lf.x));
    o = over(o, leafCol, cover(-lf.x));

    // ── The compass rose: four long points and four short, each lit on one side ──
    vec2 rq = p;
    float quadrant = floor((atan(rq.x, -rq.y) / TAU + 1.0 / 16.0) * 8.0);
    float pointTurn = quadrant / 8.0;
    vec2 pq = handFrame(rq, pointTurn);
    float long_ = mod(quadrant, 2.0) < 0.5 ? 1.0 : 0.0;
    float reach = mix(R * 0.2, R * 0.34, long_);
    float width = mix(R * 0.035, R * 0.05, long_);
    float star = abs(pq.x) * reach / width + pq.y - reach;
    star = max(star, -pq.y);
    vec3 roseCol = mix(mix(u.cCloudLight.rgb, u.cWind.rgb, 0.25), u.cCloud.rgb, step(0.0, pq.x));
    roseCol = mix(roseCol, mix(u.cAccent.rgb, u.cLeaf.rgb, step(0.0, pq.x) * 0.6), long_ * step(0.5, 1.0 - abs(quadrant / 8.0 - 0.0)) * 0.0);
    o = over(o, u.cDeep.rgb, 0.8 * cover(1.2 - star));
    o = over(o, roseCol, 0.75 * cover(-star));

    // ── The riding leaf ──
    float rS = R * 0.68;
    if (u.seconds > 0.5) {
        float behind = fract(u.secondTurn - turn + 1.0);
        float tail = 1.0 - behind / 0.07;
        o = over(o, u.cWind.rgb, 0.45 * step(0.0, tail) * tail * cover(0.9 - abs(r - rS)));
        vec2 c = at(u.secondTurn, rS);
        vec2 sq = rot(p - c, -(u.secondTurn * TAU + u.time * 2.5));
        vec2 sl = leaf(sq + vec2(0.0, R * 0.04), R * 0.08, R * 0.025);
        o = over(o, u.cDeep.rgb, cover(1.0 - sl.x));
        o = over(o, mix(u.cLeaf.rgb, mix(u.cLeaf.rgb, u.cDeep.rgb, 0.35), band(sl.y, 0.0)), cover(-sl.x));
    }

    // ── Hands: a broad leaf for the hour, a long feather for the minute ──
    vec2 hq = handFrame(p, u.hourTurn);
    vec2 h = leaf(hq + vec2(0.0, R * 0.06), R * 0.56, R * 0.07);
    vec2 mq2 = handFrame(p, u.minuteTurn);
    vec2 m = leaf(mq2 + vec2(0.0, R * 0.06), R * 0.86, R * 0.045);
    vec2 sh = handFrame(p - vec2(2.0, 3.0), u.hourTurn);
    vec2 sm = handFrame(p - vec2(2.0, 3.0), u.minuteTurn);
    float shadow = min(leaf(sh + vec2(0.0, R * 0.06), R * 0.56, R * 0.07).x,
                       leaf(sm + vec2(0.0, R * 0.06), R * 0.86, R * 0.045).x);
    o = over(o, u.cDeep.rgb, 0.55 * cover(-shadow));
    // The hour's leaf: a lit and a shaded half about its midrib, with the rib itself.
    vec3 hourCol = mix(u.cLeaf.rgb, mix(u.cLeaf.rgb, u.cDeep.rgb, 0.3), band(h.y, 0.0));
    hourCol = mix(hourCol, mix(u.cLeaf.rgb, u.cWind.rgb, 0.5), 1.0 - band(abs(hq.x), 0.9));
    o = over(o, u.cDeep.rgb, cover(1.2 - h.x));
    o = over(o, hourCol, cover(-h.x));
    // The minute's feather: barbs slanting back from its shaft.
    float barbs = fract((mq2.y - abs(mq2.x) * 1.4) / (R * 0.05));
    vec3 featherCol = mix(u.cWind.rgb, mix(u.cWind.rgb, u.cDim.rgb, 0.55), band(barbs, 0.75));
    featherCol = mix(featherCol, mix(u.cWind.rgb, u.cDeep.rgb, 0.2), band(m.y, 0.0) * 0.6);
    featherCol = mix(featherCol, u.cWind.rgb, 1.0 - band(abs(mq2.x), 0.8));
    o = over(o, u.cDeep.rgb, cover(1.2 - m.x));
    o = over(o, featherCol, cover(-m.x));

    // ── A curl of wind at the center ──
    float hubR = R * 0.07;
    float curl = sin(a * 1.0 + log(max(r, 1.0)) * 6.0 - u.time * 1.2);
    vec3 hub = mix(u.cAccent.rgb, mix(u.cAccent.rgb, u.cWind.rgb, 0.5), band(curl, 0.2));
    o = over(o, u.cDeep.rgb, cover(hubR + 1.4 - r));
    o = over(o, hub, cover(hubR - r));

    fragColor = o * u.qt_Opacity;
}
