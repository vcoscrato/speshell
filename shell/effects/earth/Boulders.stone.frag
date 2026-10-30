#version 440
#extension GL_GOOGLE_include_directive : enable
// One of the far stones: a small dark chip circling slowly well behind the boulders,
// tumbling and lit from the top left.
layout(location = 0) in vec2 p;
layout(location = 0) out vec4 fragColor;
#include "Boulders.glsl"

void main() {
    float fi = u.piece;
    vec3 r;
    vec3 s = farStone(fi, r);
    vec2 pos = s.xy;
    float size = s.z;
    vec2 light = normalize(vec2(-0.45, -1.0));
    vec3 lit = mix(u.cMid.rgb, u.cDark.rgb, 0.35);
    vec3 shade = mix(u.cDark.rgb, u.cEdge.rgb, 0.3);

    // A five-sided chip: signed distance, < 0 inside.
    vec2 o = p - pos;
    vec2 lp = rot(u.time * mix(-1.2, 1.2, r.x) + fi) * o;
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
    float k = cover(-d + 0.6) * mix(0.55, 0.85, r.z);
    fragColor = vec4(c, 1.0) * k * shown(p) * u.qt_Opacity;
}
