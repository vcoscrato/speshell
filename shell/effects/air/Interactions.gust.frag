#version 440
#extension GL_GOOGLE_include_directive : enable
// A gust blowing a slider's knob along: a puff of breath from behind and above it,
// frayed into wisps where it starts and arcing down to cup the knob's back, in two
// flat bands of air that reach further back the more it blows. Its billowing upper
// edge, and the streaks and curls in it, stream with the flow. Drawn in the
// gust's own frame: x along the way it blows, the knob at the middle.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    float dir;          // 1 blowing right, -1 left
    float strength;     // 0..1, by how fast the knob moves
    float build;        // 0..1, by how long it has blown
    float phase;        // px the air has streamed
    float knob;         // the knob's radius, px
    float lead;         // px of its last step, which it may already have taken
    float seed;
    vec4 cWind;
} u;
#include "../common/common.glsl"

// Scalloped edge, 0.78..1 of the half-width: lobes of cloud streaming with the flow,
// uneven in length.
float lobes(float flow, float k) {
    float f = flow / 9.0 + 0.8 * vnoise(vec2(flow * 0.045, k)) + k;
    float x = 2.0 * fract(f) - 1.0;
    return 0.78 + 0.22 * sqrt(max(0.0, 1.0 - x * x));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area;
    p.x *= u.dir;
    float s = u.strength;
    float R = u.knob;
    // The plume starts L behind the knob and a little above it, and arcs down into
    // its back, fanning out.
    float L = mix(26.0, 105.0, s) * mix(0.7, 1.0, u.build);
    float t = (p.x + L) / L;                             // 0 at its start, 1 at the knob
    if (t < 0.0)
        discard;
    float bend = 0.28 + 0.08 * sin(u.phase * 0.02 + u.seed * 6.0);
    float xc = min(p.x, 0.0);
    float cy = -bend * xc * xc / L;
    float slope = 2.0 * bend * xc / L;
    vec2 q = vec2(p.x, (p.y - cy) * inversesqrt(1.0 + slope * slope));
    float side = q.y < 0.0 ? -1.0 : 1.0;
    float flow = p.x - u.phase;
    float hk = R * mix(1.25, 1.9, s) * mix(0.85, 1.0, u.build);
    // Its start frays into wisps that stream in.
    float fray = vnoise(vec2(flow * 0.09, side * 4.0 + u.seed * 13.0));
    float h = hk * pow(clamp(t, 0.0, 1.0), 0.6) * clamp((t - 0.45 * fray) / 0.3, 0.0, 1.0);
    // Its front cups the knob's back, rounding off just past its middle, so a knob a
    // step ahead of where it was reported (as the wheel reports it) still sits in the cup.
    if (p.x > 0.0)
        h = hk * sqrt(max(1.0 - p.x * p.x / (0.25 * R * R), 0.0));
    // Billowing on its upper side, smoother underneath.
    float y = abs(q.y);
    float he = h * (side < 0.0 ? lobes(flow, 3.0 + u.seed * 7.0) : mix(0.9, 1.0, vnoise(vec2(flow * 0.06, 9.0))));

    // Two flat bands, the inner one reaching back less far.
    float outer = cover(he - y);
    float hm = h * 0.6 * smoothstep(0.2, 0.65, t + 0.15 * u.build);
    float mid = cover(hm * lobes(flow * 1.3, side * 5.0 + 2.0) - abs(q.y + 0.15 * h));
    // Streaks in it, on uneven lanes, fanning out from its start and tapered at both ends.
    float streak = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float at = (fi - 1.0) * 0.55 + 0.12 * (hash(vec2(fi, u.seed)) - 0.5);
        float run = fract(flow / mix(40.0, 30.0, s) / (0.8 + 0.4 * hash(vec2(u.seed, fi))) + fi * 0.37 + u.seed);
        float w = 0.9 * sin(3.1415927 * clamp(run / 0.45, 0.0, 1.0)) * step(run, 0.45) * smoothstep(0.15, 0.45, t);
        streak = max(streak, cover(w - abs(q.y - at * h)));
    }
    streak *= step(p.x, -R * 0.6) * step(1.5, h);
    // A curl of wind on each edge, riding the flow toward the knob and winding up.
    for (int i = 0; i < 2; i++) {
        float sd = float(i) * 2.0 - 1.0;
        float run = fract(u.phase / 70.0 + float(i) * 0.5 + u.seed);
        float cx = mix(-L * 0.7, -R * 0.6, run);
        float ch = hk * pow(clamp((cx + L) / L, 0.0, 1.0), 0.6);
        float rc = mix(2.0, 4.5, s) * (0.6 + 0.4 * run);
        vec2 d = q - vec2(cx, sd * (ch * 0.95 + rc * 0.3));
        float th = mod(atan(d.y * sd, -d.x) + run * 3.0, 6.2831853);
        float len = 4.2 * sin(3.1415927 * run);
        float rs = rc * (1.0 - 0.11 * th);
        float w = 0.8 * (1.0 - th / max(len, 0.01));
        streak = max(streak, cover(w - abs(length(d) - rs)) * step(th, len));
    }

    vec4 c = vec4(0.0);
    c = over(c, u.cWind.rgb, outer * 0.1);
    c = over(c, u.cWind.rgb, mid * 0.12);
    c = over(c, u.cWind.rgb, streak * 0.75);
    // Clear of the knob, wherever along its last step it is: the wheel reports a
    // step before the knob takes it.
    float clear = sdSeg(p, vec2(0.0), vec2(u.lead, 0.0)) - R;
    c *= smoothstep(1.0, 2.0, clear) * smoothstep(0.0, 0.12, s);
    fragColor = c * u.qt_Opacity;
}
