#version 440
#extension GL_GOOGLE_include_directive : enable
// Earth's knob: a lopsided, faceted stone that rolls as it travels, the light staying
// put while its faces turn, with a vein of jade that glows while it is held.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float size;         // px across
    float turn;         // radians it has rolled
    float glow;         // 0..1 held or hovered
    float dim;          // 0..1 switched off
    vec4 cStone;
    vec4 cLight;
    vec4 cShade;
    vec4 cJade;
    vec4 cGlint;
} u;
#include "../../lib/common.glsl"

const vec2 LIGHT = vec2(-0.55, -0.83);

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.size;
    float R = u.size * 0.5 - 1.0;
    // Into the stone's own frame, which rolls clockwise as it travels right: its top
    // leads, as a rolling stone's does.
    float c = cos(u.turn), s = sin(u.turn);
    vec2 q = mat2(c, -s, s, c) * p;

    float d = -1e9;
    vec2 face = vec2(0.0);
    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float a = 6.2831853 * (fi + 0.5 * (hash(vec2(fi, 4.0)) - 0.5)) / 7.0;
        vec2 n = vec2(cos(a), sin(a));
        float h = R * (0.84 + 0.16 * hash(vec2(fi, 9.0)));
        float e = dot(q, n) - h;
        if (e > d) { d = e; face = n; }
    }
    // Faces are shaded on screen, so the light stays put as the stone turns.
    vec2 n = mat2(c, s, -s, c) * face;
    float lit = dot(n, LIGHT);
    vec3 stone = mix(u.cStone.rgb, u.cShade.rgb, 0.25 * u.dim);
    vec3 side = lit > 0.3 ? mix(stone, u.cLight.rgb, 0.55) : lit > -0.35 ? stone : mix(stone, u.cShade.rgb, 0.5);
    float top = band(-d, R * 0.42);
    vec3 col = mix(side, mix(stone, u.cLight.rgb, 0.3), top);

    // A jade vein across the stone.
    float vein = abs(q.y - 0.35 * q.x + R * 0.15 + 1.5 * sin(q.x * 0.9)) - 0.6 - 0.5 * u.glow;
    col = mix(col, mix(u.cJade.rgb, u.cGlint.rgb, 0.25 * u.glow), cover(-vein) * (0.55 + 0.45 * u.glow) * (1.0 - u.dim));

    vec4 o = vec4(u.cShade.rgb, 1.0) * cover(-d);
    o = vec4(col, 1.0) * cover(-d - 1.3) + o * (1.0 - cover(-d - 1.3));
    fragColor = o * u.qt_Opacity;
}
