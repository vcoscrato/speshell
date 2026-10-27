#version 440
#extension GL_GOOGLE_include_directive : enable
// Cosmos's clock face: an orrery seen from above. The sun burns at the center under a
// slowly turning corona. The hour's banded planet circles close in and the minute's
// ringed giant farther out, both lit from the sun and held to it by faint lines, so
// they read as hands; a comet runs the outer orbit with the seconds, its tail along it.
// Four-point stars mark the hours, larger at the quarters, over a nebula lane and
// twinkling star dust.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    float hourTurn;     // each hand's turns from twelve, clockwise
    float minuteTurn;
    float secondTurn;
    float seconds;      // 1 shows the comet
    float time;         // s, for the corona and the star dust
    vec4 cSpace;
    vec4 cDeep;
    vec4 cRim;
    vec4 cText;
    vec4 cDim;
    vec4 cSun;
    vec4 cSunEdge;
    vec4 cHour;
    vec4 cHourBand;
    vec4 cMinute;
    vec4 cMinuteBand;
    vec4 cNebula;
} u;
#include "../common/common.glsl"

const float TAU = 6.2831853;

// The point at radius r, `turn` turns clockwise from twelve.
vec2 at(float turn, float r) {
    float a = turn * TAU;
    return vec2(sin(a), -cos(a)) * r;
}

// Turns clockwise from twelve to p.
float turnOf(vec2 p) {
    return fract(atan(p.x, -p.y) / TAU + 1.0);
}

// A four-point star of radius r: an astroid, sharp along its axes.
float sparkle(vec2 q, float r) {
    vec2 a = pow(abs(q) / r + 1e-4, vec2(2.0 / 3.0));
    return (1.0 - (a.x + a.y)) * r * 0.6;
}

// A planet of radius r at c, banded and turned by `spin`, lit from the sun at the
// center: a lit crescent toward it and a night side away.
vec4 planet(vec4 o, vec2 p, vec2 c, float r, vec3 body, vec3 bands, float spin) {
    vec2 q = p - c;
    float d = length(q) - r;
    vec2 b = rot(q, spin);
    float stripes = sin(b.y / r * 4.5 + 1.4 * sin(b.x / r * 2.2 + spin));
    vec3 col = mix(body, bands, band(stripes, 0.3));
    vec2 toSun = -normalize(c);
    float lit = dot(q / r, toSun);
    col = mix(col, u.cText.rgb, 0.32 * band(lit, 0.55));
    col = mix(col, u.cDeep.rgb, 0.62 * band(-lit, 0.1));
    o = over(o, u.cDeep.rgb, cover(-d + 1.0));
    return over(o, col, cover(-d - 0.6));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area;
    float R = min(u.area.x, u.area.y) * 0.5 - 1.5;
    float r = length(p);
    vec4 o = vec4(0.0);

    // ── The dial: space, darker to the rim, warmed by the sun's light at the middle ──
    vec3 sky = mix(u.cSpace.rgb, u.cDeep.rgb, band(r, R * 0.62) * 0.55);
    sky = mix(sky, mix(u.cSpace.rgb, u.cSunEdge.rgb, 0.08), 1.0 - band(r, R * 0.27));
    // A nebula lane across the dial, top right to bottom left.
    vec2 n = rot(p / R, 0.65);
    float lane = exp(-pow((n.y + 0.18 * sin(n.x * 2.3)) / 0.24, 2.0));
    float cloud = fbm(p / R * 3.1 + 7.0) * lane;
    sky = mix(sky, u.cNebula.rgb, 0.13 * band(cloud, 0.3));
    sky = mix(sky, u.cNebula.rgb, 0.12 * band(cloud, 0.46));
    o = over(o, sky, cover(R - r));

    // Star dust, twinkling.
    vec2 cell = floor(p / 11.0);
    float h = hash(cell);
    vec2 star = (cell + 0.2 + 0.6 * vec2(h, hash(cell + 3.1))) * 11.0;
    float twinkle = 0.55 + 0.45 * sin(u.time * (1.0 + 2.0 * h) + h * 40.0);
    float dust = step(0.72, h) * cover(0.9 - length(p - star)) * twinkle * (1.0 - band(r, R - 3.0));
    o = over(o, u.cText.rgb, dust * 0.55);

    // ── Orbits: the hour's, the minute's, and the comet's, a minute dot each on the last ──
    float rH = R * 0.36, rM = R * 0.62, rS = R * 0.83;
    float orbits = min(min(abs(r - rH), abs(r - rM)), abs(r - rS));
    o = over(o, u.cDim.rgb, 0.22 * cover(0.6 - orbits));
    float minuteDot = length(p - at(floor(turnOf(p) * 60.0 + 0.5) / 60.0, rS));
    o = over(o, u.cDim.rgb, 0.45 * cover(1.1 - minuteDot));

    // ── Hour stars ──
    float k = floor(turnOf(p) * 12.0 + 0.5);
    bool quarter = mod(k, 3.0) < 0.5;
    vec2 mark = at(k / 12.0, R * 0.92);
    float size = quarter ? R * 0.075 : R * 0.045;
    float s = sparkle(p - mark, size);
    o = over(o, u.cDeep.rgb, cover(s + 0.8));
    o = over(o, quarter ? u.cText.rgb : u.cDim.rgb, cover(s));

    // ── The comet: a head on the outer orbit and a tail back along it ──
    if (u.seconds > 0.5) {
        vec2 head = at(u.secondTurn, rS);
        float behind = fract(u.secondTurn - turnOf(p) + 1.0);
        float tail = 1.0 - behind / 0.09;
        float width = 1.0 + 3.2 * tail;
        float onTail = step(0.0, tail) * cover(width - abs(r - rS)) * tail * tail;
        o = over(o, u.cMinute.rgb, 0.7 * onTail);
        o = over(o, u.cText.rgb, 0.6 * onTail * band(tail, 0.75));
        float hd = length(p - head);
        o = over(o, u.cMinute.rgb, 0.35 * cover(R * 0.06 - hd));
        o = over(o, u.cText.rgb, cover(R * 0.032 - hd));
    }

    // ── Tethers, sun to planet ──
    vec2 hourAt = at(u.hourTurn, rH);
    vec2 minuteAt = at(u.minuteTurn, rM);
    float sunR = R * 0.13;
    float th = sdSeg(p, at(u.hourTurn, sunR + 2.0), at(u.hourTurn, rH - R * 0.1));
    float tm = sdSeg(p, at(u.minuteTurn, sunR + 2.0), at(u.minuteTurn, rM - R * 0.08));
    o = over(o, u.cHourBand.rgb, 0.85 * cover(1.6 - th));
    o = over(o, u.cMinute.rgb, 0.85 * cover(1.1 - tm));

    // ── The minute's giant, its ring tilted: the far half behind it, the near in front ──
    float rMp = R * 0.085;
    vec2 q = p - minuteAt;
    vec2 rq = rot(q, -0.45);
    float ringD = abs(length(rq * vec2(1.0, 3.0)) - rMp * 1.75) / 1.5;
    float ring = cover(1.3 - ringD);
    float front = step(0.0, rq.y);
    o = over(o, u.cDim.rgb, ring * (1.0 - front));
    o = planet(o, p, minuteAt, rMp, u.cMinute.rgb, u.cMinuteBand.rgb, u.minuteTurn * TAU * 2.0);
    o = over(o, u.cDeep.rgb, ring * front * cover(1.6 - ringD + 1.0) * 0.0);
    o = over(o, u.cDim.rgb, ring * front);

    // ── The hour's planet ──
    o = planet(o, p, hourAt, R * 0.075, u.cHour.rgb, u.cHourBand.rgb, u.hourTurn * TAU * 3.0);

    // ── The sun: cel-shaded bands under a slowly turning corona ──
    float a = atan(p.y, p.x);
    float wave = 0.035 * sin(a * 5.0 + u.time * 0.35) + 0.025 * sin(a * 8.0 - u.time * 0.5);
    o = over(o, u.cSunEdge.rgb, 0.12 * cover(sunR * (1.85 + wave) - r));
    o = over(o, u.cSunEdge.rgb, 0.22 * cover(sunR * (1.4 + wave) - r));
    float churn = fbm(p / sunR * 1.6 + vec2(u.time * 0.05, 0.0)) * sunR * 0.35;
    vec3 sun = mix(u.cSunEdge.rgb, u.cSun.rgb, 1.0 - band(r + churn * 0.5, sunR * 0.82));
    sun = mix(sun, mix(u.cSun.rgb, u.cText.rgb, 0.55), 1.0 - band(r + churn, sunR * 0.5));
    o = over(o, u.cDeep.rgb, cover(sunR + 1.0 - r));
    o = over(o, sun, cover(sunR - 0.4 - r));

    // ── The rim ──
    o = over(o, u.cRim.rgb, cover(1.4 - abs(r - R + 0.7)));
    fragColor = o * u.qt_Opacity;
}
