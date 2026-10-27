#version 440
#extension GL_GOOGLE_include_directive : enable
// The ignition ember: a flickering, banded ember that flares over `ignite` s inside a
// flat glow, throwing a few sparks, then collapses as the burning edge takes over.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;   // this item's size in px; the ember sits at its middle
    float age;         // s since the launcher opened
    float ignite;      // s the ember flares before the front sets out
    vec4 cCore;
    vec4 cMid;
    vec4 cOuter;
    vec4 cEdge;
    vec4 cGlow;
} u;
#include "../common/common.glsl"

float disc(float r, float radius) {
    float aa = fwidth(r) * 0.75 + 0.3;
    return 1.0 - smoothstep(radius - aa, radius + aa, r);
}

void main() {
    vec2 q = qt_TexCoord0 * u.resolution - u.resolution * 0.5;
    float k = clamp(u.age / u.ignite, 0.0, 1.0);
    float out_ = clamp((u.age - u.ignite) / 0.12, 0.0, 1.0);
    float grow = 1.0 - (1.0 - k) * (1.0 - k);
    // Collapsing, it stays opaque and flat: the bands shrink rather than fade.
    float R = mix(3.0, 12.0, grow) * sqrt(1.0 - out_) * (1.0 + 0.07 * sin(u.age * 41.0));

    // Taller above than below, with a ragged, flickering rim.
    vec2 e = vec2(q.x, q.y * (q.y < 0.0 ? 0.72 : 1.0));
    float ang = atan(e.y, e.x);
    float r = length(e) * (1.0 + 0.32 * (vnoise(vec2(ang * 2.2 + 7.0, u.age * 9.0)) - 0.5));

    vec4 col = vec4(0.0);
    float glowR = mix(3.0, 12.0, grow) * mix(1.6, 2.4, grow);
    // The glow lightens what is behind it, mostly added rather than laid over.
    float glow = (disc(length(q), glowR) * 0.7 + disc(length(q), glowR * 0.7) * 0.3) * (1.0 - out_) * (1.0 - out_);
    col = vec4(u.cGlow.rgb * 0.3, 0.08) * glow;
    col = over(col, u.cEdge.rgb, disc(r, R * 1.18));
    col = over(col, u.cOuter.rgb, disc(r, R));
    col = over(col, u.cMid.rgb, disc(r, R * 0.74));
    col = over(col, u.cCore.rgb, disc(r, R * mix(0.3, 0.46, k + out_)));

    // Sparks thrown upward in a fan, each born at its own moment, cooling as it flies.
    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float born = u.ignite * (0.15 + 0.8 * hash(vec2(fi, 3.1)));
        float life = 0.18 + 0.12 * hash(vec2(fi, 8.7));
        float t = u.age - born;
        if (t < 0.0 || t > life)
            continue;
        float a = -1.5708 + (hash(vec2(fi, 1.3)) - 0.5) * 2.6;
        float speed = 260.0 + 220.0 * hash(vec2(fi, 5.9));
        float s = t / life;
        vec2 at = vec2(cos(a), sin(a)) * speed * t * (1.0 - 0.45 * s) - vec2(0.0, 40.0 * t * t);
        float size = mix(2.4, 0.8, s);
        float d = length(q - at);
        vec3 c = s < 0.4 ? u.cCore.rgb : (s < 0.75 ? u.cMid.rgb : u.cOuter.rgb);
        col = over(col, c, disc(d, size));
    }

    fragColor = col * u.qt_Opacity;
}
