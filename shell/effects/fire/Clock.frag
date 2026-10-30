#version 440
#extension GL_GOOGLE_include_directive : enable
// Fire's clock face: a disc of charcoal, its cracks glowing hotter toward the rim, inside
// a ring of low flames that lick outward and flicker. Flames stand at the quarter hours
// and embers at the other hours. The hands are forged blades, dark iron with an edge
// heated toward the tip, the hour's broad and the minute's long, over a glowing coal at
// the center; an ember runs an inner track with the seconds, dropping sparks behind.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    float hourTurn;     // each hand's turns from twelve, clockwise
    float minuteTurn;
    float secondTurn;
    float seconds;      // 1 shows the running ember
    float time;         // s, for the flames
    vec4 cCoal;
    vec4 cAsh;
    vec4 cIron;
    vec4 cRim;
    vec4 cText;
    vec4 cCore;
    vec4 cMid;
    vec4 cOuter;
    vec4 cEdge;
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

// p in a hand's frame: x across it, y out along it from the center.
vec2 handFrame(vec2 p, float turn) {
    return rot(p, -turn * TAU) * vec2(1.0, -1.0);
}

// A blade from the center out to `len`, `w` wide at its base, a short tang behind the
// center, tapering to a point. Negative inside.
float blade(vec2 q, float len, float w) {
    float y = clamp(q.y, -w * 1.6, len);
    float halfWidth = q.y < 0.0 ? w * 0.55 : w * pow(max(0.0, 1.0 - y / len), 0.75);
    return max(abs(q.x) - halfWidth, max(-q.y - w * 1.6, q.y - len));
}

// Fire's four cel bands, from the edge in to the core, by heat 0..1.
vec3 flame(float heat) {
    vec3 col = u.cEdge.rgb;
    col = mix(col, u.cOuter.rgb, band(heat, 0.25));
    col = mix(col, u.cMid.rgb, band(heat, 0.55));
    return mix(col, u.cCore.rgb, band(heat, 0.82));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area;
    float S = min(u.area.x, u.area.y) * 0.5;
    float R = S * 0.86;
    float r = length(p);
    float turn = turnOf(p);
    vec4 o = vec4(0.0);

    // ── The ring of flames, licking outward from the rim ──
    // Sampled round the circle, so the ring has no seam where `turn` wraps.
    vec2 dir = p / max(r, 1e-3);
    float lick = fbm(dir * 3.5 + vec2(0.0, u.time * 1.6)) * 0.75 + fbm(dir * 7.5 + vec2(3.0, -u.time * 2.7)) * 0.4;
    float height = S * (0.05 + 0.1 * lick * lick);
    // Branch-free, so cover()'s derivatives hold everywhere.
    float out1 = (r - R) / height;
    o = over(o, flame(clamp(1.0 - out1, 0.0, 1.0)), cover((1.0 - out1) * height) * step(-0.3, out1));

    // ── The charcoal dial, its cracks glowing hotter toward the rim ──
    vec3 coal = mix(u.cAsh.rgb, u.cCoal.rgb, band(r, R * 0.55) * 0.6);
    // Cracks: the edges of uneven cells, open only where a slow noise lets them, so
    // they run in broken seams that are hottest at the rim.
    float crack = voronoiEdge(p + vec2(17.0, 5.0), R * 0.3, 1.0);
    float open = smoothstep(0.42, 0.62, fbm(p / R * 2.4 + 3.0));
    float heatOut = smoothstep(R * 0.45, R, r);
    float seam = (1.0 - smoothstep(0.0, 1.4, crack)) * open;
    float pulse = 0.8 + 0.2 * sin(u.time * 1.3 + fbm(p / 30.0) * 9.0);
    coal = mix(coal, u.cEdge.rgb, seam * (0.35 + 0.5 * heatOut));
    coal = mix(coal, u.cOuter.rgb, band(seam * heatOut * pulse, 0.5));
    o = over(o, coal, cover(R - r));
    // The rim's iron band.
    o = over(o, u.cRim.rgb, cover(1.6 - abs(r - R + 1.0)));

    // ── Hour marks: flames at the quarters, embers between ──
    float k = floor(turn * 12.0 + 0.5);
    vec2 mark = at(k / 12.0, R * 0.84);
    vec2 mq = handFrame(p - mark, k / 12.0);
    // Both shapes everywhere, one shown, so cover()'s derivatives hold at the sectors' seams.
    float quarter = step(mod(k, 3.0), 0.5);
    // A flame: a teardrop, round at its foot and swaying to a point.
    float sway = 0.18 * sin(u.time * 3.0 + k);
    vec2 fq = vec2(mq.x - sway * max(0.0, mq.y), mq.y);
    float foot = S * 0.035;
    float rise = clamp(fq.y / (S * 0.1), 0.0, 1.0);
    float tongue = mix(length(fq) - foot, abs(fq.x) / (1.0 - 0.9 * rise) - foot, step(0.0, fq.y));
    tongue = max(tongue, fq.y - S * 0.1);
    vec3 tongueCol = flame(clamp(1.0 - rise * 0.9 - abs(fq.x) / (S * 0.06), 0.0, 1.0));
    // An ember: a small glowing diamond.
    float ember = abs(mq.x) + abs(mq.y) * 0.7 - S * 0.026;
    vec3 emberCol = mix(u.cOuter.rgb, u.cMid.rgb, 0.5 + 0.5 * sin(u.time * 2.0 + k * 1.7));
    float markD = mix(ember, tongue, quarter);
    o = over(o, u.cCoal.rgb, cover(1.2 - markD));
    o = over(o, mix(emberCol, tongueCol, quarter), cover(-markD));

    // ── The running ember and its sparks ──
    float rS = R * 0.68;
    if (u.seconds > 0.5) {
        o = over(o, u.cEdge.rgb, 0.35 * cover(0.8 - abs(r - rS)));
        float behind = fract(u.secondTurn - turn + 1.0);
        float trail = 1.0 - behind / 0.06;
        float sparks = step(0.0, trail) * trail * step(0.75, hash(floor(vec2(turn * 900.0, r / 2.5))));
        o = over(o, u.cMid.rgb, sparks * cover(3.0 - abs(r - rS)));
        float e = length(p - at(u.secondTurn, rS));
        o = over(o, u.cOuter.rgb, 0.5 * cover(S * 0.055 - e));
        o = over(o, u.cMid.rgb, cover(S * 0.035 - e));
        o = over(o, u.cCore.rgb, cover(S * 0.018 - e));
    }

    // ── Hands: dark iron blades with a hot edge, heated toward the tip ──
    vec2 hq = handFrame(p, u.hourTurn);
    float hourBlade = blade(hq, R * 0.5, S * 0.07);
    vec2 mq2 = handFrame(p, u.minuteTurn);
    float minuteBlade = blade(mq2, R * 0.78, S * 0.045);
    // Shadow, then each blade: iron inside a band of heat along its edge.
    float shadow = min(blade(handFrame(p - vec2(2.0, 3.0), u.hourTurn), R * 0.5, S * 0.07),
                       blade(handFrame(p - vec2(2.0, 3.0), u.minuteTurn), R * 0.78, S * 0.045));
    o = over(o, u.cCoal.rgb, 0.6 * cover(-shadow));
    vec3 hourCol = mix(u.cIron.rgb, flame(clamp(hq.y / (R * 0.5), 0.0, 1.0)), 1.0 - band(-hourBlade, S * 0.018));
    o = over(o, u.cCoal.rgb, cover(1.2 - hourBlade));
    o = over(o, hourCol, cover(-hourBlade));
    vec3 minuteCol = mix(u.cIron.rgb, flame(clamp(mq2.y / (R * 0.78), 0.0, 1.0)), 1.0 - band(-minuteBlade, S * 0.014));
    o = over(o, u.cCoal.rgb, cover(1.2 - minuteBlade));
    o = over(o, minuteCol, cover(-minuteBlade));

    // ── The coal at the center ──
    float hub = r - S * 0.075;
    o = over(o, u.cCoal.rgb, cover(1.2 - hub));
    float hubCrack = voronoiEdge(p * 3.0 + 40.0, S * 0.12, 0.8);
    vec3 hubCol = mix(u.cIron.rgb, u.cOuter.rgb, 1.0 - smoothstep(0.0, 2.5, hubCrack));
    hubCol = mix(hubCol, u.cMid.rgb, 1.0 - band(r, S * 0.03));
    o = over(o, hubCol, cover(-hub));

    fragColor = o * u.qt_Opacity;
}
