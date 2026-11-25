#version 440
#extension GL_GOOGLE_include_directive : enable
// The light pieces round the open launcher, each on a box or strip of its own that
// Boulders.vert fits to it: behind the boulders, broad faint bands of dust circling
// far out, ragged and soft at the edges, and small dark chips circling slowly well
// behind them, tumbling and lit from the top left; in front, dust motes rising past,
// small turning squares.
layout(location = 0) in vec2 p;
layout(location = 1) in vec4 a0;   // what it is (0 a band, 1 a far stone, 2 a mote), then its own
layout(location = 2) in vec4 a1;
layout(location = 0) out vec4 fragColor;
#include "Boulders.glsl"

// Band `fj` at p.
vec4 dustBand(float fj) {
    float rr, P, head;
    vec2 hh = bandRect(fj, rr, P, head);
    vec2 rel = p - panelCenter();
    float d = sdRoundRect(rel, hh, rr);
    float s = rrArc(rel, hh, rr);
    float behind = mod(head - s, P);
    float len = P * 0.42 * held();
    float tt = behind / max(len, 1.0);
    // Both fit the lap, so the ribbon meets itself where s wraps: whole waves, and
    // the noise cross-fading into its own start over the last stretch (the only
    // place that needs the second lookup).
    float laps = max(1.0, floor(P / 1070.0 + 0.5));
    float wave = 22.0 * sin(6.2831853 * laps * s / P - u.time * 0.4 + fj * 2.4);
    float wrap = smoothstep(P - 160.0, P, s);
    vec2 rq = vec2(s / 40.0 + u.time * 0.3, d / 18.0 + fj * 5.0);
    float rag = fbm(rq);
    if (wrap > 0.0)
        rag = mix(rag, fbm(rq - vec2(P / 40.0, 0.0)), wrap);
    rag = (rag - 0.5) * 22.0;
    float w = (16.0 + 8.0 * fj) * pow(sin(3.14159265 * clamp(tt, 0.0, 1.0)), 0.7);
    float f = w + rag - abs(d - wave);
    if (f <= 0.0 || tt > 1.0)
        return vec4(0.0);
    // Thinning out over its last few px, and thicker and thinner along it, as dust
    // is; the same cross-fade keeps that seamless where s wraps.
    vec2 dq = vec2(s / 90.0 - u.time * 0.15, d / 30.0 + fj * 3.0);
    float thick = fbm(dq);
    if (wrap > 0.0)
        thick = mix(thick, fbm(dq - vec2(P / 90.0, 0.0)), wrap);
    return vec4(u.cLight.rgb, 1.0) * smoothstep(0.0, 6.0, f) * smoothstep(0.2, 0.7, thick) * (0.15 - 0.04 * fj);
}

// A far stone: a five-sided chip, lit from the top left.
vec4 farChip() {
    float fi = floor(a0.y + 0.5);
    float size = a0.z;
    vec2 light = normalize(vec2(-0.45, -1.0));
    vec3 lit = mix(u.cMid.rgb, u.cDark.rgb, 0.35);
    vec3 shade = mix(u.cDark.rgb, u.cEdge.rgb, 0.3);
    vec2 o = p - a1.xy;
    vec2 lp = rot(a0.w) * o;
    float seed = fi + 40.0;
    float d = -1e3;
    for (int k = 0; k < 5; k++) {
        float fk = float(k);
        float th = (fk + 0.4 * hash(vec2(seed, fk))) * 1.2566371;
        d = max(d, dot(lp, vec2(cos(th), sin(th))) - size * (0.8 + 0.35 * hash(vec2(fk, seed))));
    }
    // Top-lit: the half facing the light is the light tone.
    vec3 c = mix(shade, lit, cover(dot(o, light) / max(size, 1.0) + 0.1));
    c = mix(u.cEdge.rgb, c, cover(-d - 1.0));
    return vec4(c, 1.0) * cover(-d + 0.6) * a1.z;
}

// A mote: a small turning square.
vec4 mote() {
    vec2 o = rot(a0.z) * (p - a1.xy);
    return vec4(u.cLight.rgb, 1.0) * cover(a0.y - max(abs(o.x), abs(o.y))) * a0.w;
}

void main() {
    vec4 c = a0.x < 0.5 ? dustBand(floor(a0.y + 0.5)) : (a0.x < 1.5 ? farChip() : mote());
    fragColor = c * shown(p) * u.qt_Opacity;
}
