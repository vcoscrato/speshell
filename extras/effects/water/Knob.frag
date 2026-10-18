#version 440
#extension GL_GOOGLE_include_directive : enable
// Water's knob: a drop of water, cel-shaded, with a highlight; it stretches along its
// motion and wobbles back, and while held or hovered a ripple rings it. The item is
// larger than the knob, to fit the ripple.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    float size;         // the knob's diameter, px
    float stretch;      // -1..1 motion, signed by its direction
    float glow;         // 0..1 held or hovered
    float dim;          // 0..1 switched off
    float time;
    vec4 cWater;
    vec4 cLight;
    vec4 cFoam;
    vec4 cDeep;
} u;
#include "../../lib/common.glsl"

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area;
    float R = u.size * 0.5 - 1.0;
    vec4 o = vec4(0.0);

    // The ripple around it.
    float rr = R * (1.35 + 0.12 * sin(u.time * 6.0));
    o = over(o, u.cLight.rgb, cover(0.8 - abs(length(p * vec2(1.0, 1.15)) - rr)) * 0.6 * u.glow * (1.0 - u.dim));

    // Stretched along its motion, trailing behind.
    float s = abs(u.stretch) * 0.35;
    vec2 q = p / vec2(1.0 + s, 1.0 - s * 0.5);
    q.x += sign(u.stretch) * s * R * 0.5 * smoothstep(-R, R, -p.x * sign(u.stretch));
    float d = length(q) - R;
    vec3 water = mix(u.cWater.rgb, u.cDeep.rgb, 0.35 * u.dim);
    vec3 col = mix(water, mix(water, u.cDeep.rgb, 0.45), band(q.y + q.x * 0.3, R * 0.35));
    col = mix(col, mix(water, u.cLight.rgb, 0.5), band(-q.y - q.x * 0.4, R * 0.45));
    col = mix(col, u.cFoam.rgb, cover(R * 0.22 - length(q + vec2(R * 0.38, R * 0.4))));
    o = over(o, u.cDeep.rgb, cover(-d));
    o = over(o, col, cover(-d - 1.2));
    fragColor = o * u.qt_Opacity;
}
